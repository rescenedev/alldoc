import Foundation
import SQLite3

/// 문서 본문 전문검색(FTS5) 인덱스. SQLite(libsqlite3, 외부 의존성 없음) 사용.
/// - 3글자 이상: trigram FTS MATCH (빠른 부분일치)
/// - 1~2글자: body LIKE 폴백
/// 바인딩 파라미터를 쓰므로 argv→NFD 변환 문제 없이 NFC 로 통일한다.
final class DocIndex: @unchecked Sendable {
    static let shared = DocIndex()

    struct Hit { let path: String; let snippet: String }
    struct Stamp { let mtime: Double; let size: Int64 }
    struct FileRow { let path: String; let size: Int64; let mtime: Double }

    private var db: OpaquePointer?
    private let q = DispatchQueue(label: "AllDoc.docindex")
    private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    private init() {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("AllDoc", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        let dbURL = base.appendingPathComponent("index.sqlite")
        q.sync {
            sqlite3_open_v2(dbURL.path, &db,
                            SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil)
            exec("PRAGMA journal_mode=WAL;")
            exec("PRAGMA synchronous=NORMAL;")
            exec("""
            CREATE TABLE IF NOT EXISTS docs(
              id INTEGER PRIMARY KEY,
              path TEXT UNIQUE NOT NULL,
              mtime REAL NOT NULL,
              size INTEGER NOT NULL,
              body TEXT NOT NULL
            );
            """)
            exec("CREATE VIRTUAL TABLE IF NOT EXISTS docs_fts USING fts5(body, content='docs', content_rowid='id', tokenize='trigram');")
            exec("CREATE TRIGGER IF NOT EXISTS docs_ai AFTER INSERT ON docs BEGIN INSERT INTO docs_fts(rowid, body) VALUES (new.id, new.body); END;")
            exec("CREATE TRIGGER IF NOT EXISTS docs_ad AFTER DELETE ON docs BEGIN INSERT INTO docs_fts(docs_fts, rowid, body) VALUES('delete', old.id, old.body); END;")
            exec("CREATE TRIGGER IF NOT EXISTS docs_au AFTER UPDATE ON docs BEGIN INSERT INTO docs_fts(docs_fts, rowid, body) VALUES('delete', old.id, old.body); INSERT INTO docs_fts(rowid, body) VALUES (new.id, new.body); END;")
        }
    }

    private func exec(_ sql: String) {
        sqlite3_exec(db, sql, nil, nil, nil)
    }

    // MARK: - 색인

    /// 현재 인덱스에 있는 모든 (path → mtime/size). 사전색인 시 변경분만 추리는 용도.
    func allStamps() -> [String: Stamp] {
        q.sync {
            var out: [String: Stamp] = [:]
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, "SELECT path, mtime, size FROM docs;", -1, &stmt, nil) == SQLITE_OK else { return out }
            defer { sqlite3_finalize(stmt) }
            while sqlite3_step(stmt) == SQLITE_ROW {
                let path = String(cString: sqlite3_column_text(stmt, 0))
                out[path] = Stamp(mtime: sqlite3_column_double(stmt, 1), size: sqlite3_column_int64(stmt, 2))
            }
            return out
        }
    }

    /// 본문을 일괄 upsert (트랜잭션). body 는 NFC 로 정규화해 저장.
    func upsert(_ rows: [(path: String, mtime: Double, size: Int64, body: String)]) {
        guard !rows.isEmpty else { return }
        q.sync {
            exec("BEGIN;")
            var stmt: OpaquePointer?
            let sql = "INSERT INTO docs(path,mtime,size,body) VALUES(?,?,?,?) ON CONFLICT(path) DO UPDATE SET mtime=excluded.mtime, size=excluded.size, body=excluded.body;"
            sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            for r in rows {
                sqlite3_reset(stmt)
                sqlite3_bind_text(stmt, 1, r.path, -1, transient)
                sqlite3_bind_double(stmt, 2, r.mtime)
                sqlite3_bind_int64(stmt, 3, r.size)
                sqlite3_bind_text(stmt, 4, r.body.precomposedStringWithCanonicalMapping, -1, transient)
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
            exec("COMMIT;")
        }
    }

    // MARK: - 검색

    /// 루트(폴더) 하위에서 본문 검색.
    func search(query: String, rootPrefixes: [String], limit: Int) -> [Hit] {
        searchImpl(query: query, paths: rootPrefixes, exact: false, limit: limit)
    }

    /// 정확한 파일 경로 집합(즐겨찾기 등) 안에서 본문 검색.
    func search(query: String, exactPaths: [String], limit: Int) -> [Hit] {
        searchImpl(query: query, paths: exactPaths, exact: true, limit: limit)
    }

    private func searchImpl(query rawQuery: String, paths: [String], exact: Bool, limit: Int) -> [Hit] {
        let query = rawQuery.precomposedStringWithCanonicalMapping
        guard !query.isEmpty, !paths.isEmpty else { return [] }

        return q.sync {
            let pathClause: String
            if exact {
                pathClause = "d.path IN (" + paths.map { _ in "?" }.joined(separator: ",") + ")"
            } else {
                pathClause = "(" + paths.map { _ in "d.path LIKE ?" }.joined(separator: " OR ") + ")"
            }

            var stmt: OpaquePointer?
            var hits: [Hit] = []

            if query.count >= 3 {
                let sql = """
                SELECT d.path, snippet(docs_fts, 0, '', '', '…', 12)
                FROM docs_fts JOIN docs d ON d.id = docs_fts.rowid
                WHERE docs_fts MATCH ? AND \(pathClause)
                ORDER BY rank LIMIT ?;
                """
                guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
                defer { sqlite3_finalize(stmt) }
                // trigram: 부분일치 문자열을 그대로(따옴표로 감싸 특수문자 회피).
                let matchArg = "\"" + query.replacingOccurrences(of: "\"", with: "\"\"") + "\""
                var idx: Int32 = 1
                sqlite3_bind_text(stmt, idx, matchArg, -1, transient); idx += 1
                for p in paths {
                    sqlite3_bind_text(stmt, idx, exact ? p : p + "/%", -1, transient); idx += 1
                }
                sqlite3_bind_int(stmt, idx, Int32(limit))
                while sqlite3_step(stmt) == SQLITE_ROW {
                    hits.append(Hit(path: String(cString: sqlite3_column_text(stmt, 0)),
                                    snippet: String(cString: sqlite3_column_text(stmt, 1))))
                }
            } else {
                // 1~2글자: LIKE 폴백 (body 를 받아 Swift 에서 스니펫 추출)
                let sql = "SELECT d.path, d.body FROM docs d WHERE d.body LIKE ? AND \(pathClause) LIMIT ?;"
                guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
                defer { sqlite3_finalize(stmt) }
                var idx: Int32 = 1
                sqlite3_bind_text(stmt, idx, "%\(query)%", -1, transient); idx += 1
                for p in paths {
                    sqlite3_bind_text(stmt, idx, exact ? p : p + "/%", -1, transient); idx += 1
                }
                sqlite3_bind_int(stmt, idx, Int32(limit))
                while sqlite3_step(stmt) == SQLITE_ROW {
                    let path = String(cString: sqlite3_column_text(stmt, 0))
                    let body = String(cString: sqlite3_column_text(stmt, 1))
                    hits.append(Hit(path: path, snippet: Self.snippet(body, around: query)))
                }
            }
            return hits
        }
    }

    /// LIKE 폴백용: 본문에서 일치 부분이 포함된 줄을 짧게 잘라 스니펫으로.
    private static func snippet(_ body: String, around needle: String) -> String {
        guard let r = body.range(of: needle, options: .caseInsensitive) else {
            return String(body.prefix(80))
        }
        let lineStart = body[..<r.lowerBound].lastIndex(of: "\n").map { body.index(after: $0) } ?? body.startIndex
        let lineEnd = body[r.upperBound...].firstIndex(of: "\n") ?? body.endIndex
        return String(body[lineStart..<lineEnd]).trimmingCharacters(in: .whitespaces)
    }
}
