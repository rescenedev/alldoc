import XCTest
@testable import AllDoc

/// DocIndex 는 격리된 임시 DB 로 테스트(사용자 실제 인덱스 오염 방지).
final class DocIndexTests: XCTestCase {
    private var index: DocIndex!
    private var dbURL: URL!
    private let root = "/alldoc-test-root"   // 가상 루트(파일 시스템 접근 없음)

    override func setUp() {
        super.setUp()
        dbURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("alldoc-index-\(UUID().uuidString).sqlite")
        index = DocIndex(dbURL: dbURL)
    }

    override func tearDown() {
        index = nil
        // WAL 동반 파일까지 정리.
        for suffix in ["", "-wal", "-shm"] {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: dbURL.path + suffix))
        }
        super.tearDown()
    }

    private func path(_ name: String) -> String { "\(root)/\(name)" }

    // MARK: - 본문 색인/검색

    func testUpsertAndFTSSearch() {
        index.upsert([
            (path: path("a.md"), mtime: 1, size: 10, body: "hello enterprise document search"),
            (path: path("b.md"), mtime: 2, size: 20, body: "completely different content"),
        ])
        let hits = index.search(query: "enterprise", rootPrefixes: [root], limit: 10)
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits.first?.path, path("a.md"))
        XCTAssertFalse(hits.first?.snippet.isEmpty ?? true)
    }

    func testFTSSearchKorean() {
        index.upsert([
            (path: path("k.md"), mtime: 1, size: 10, body: "이것은 한글 전문검색 테스트입니다"),
        ])
        let hits = index.search(query: "전문검색", rootPrefixes: [root], limit: 10)
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits.first?.path, path("k.md"))
    }

    func testShortQueryLikeFallback() {
        // 1~2글자는 trigram FTS 불가 → LIKE 폴백 경로.
        index.upsert([
            (path: path("s.md"), mtime: 1, size: 10, body: "AB cd ef"),
        ])
        let hits = index.search(query: "AB", rootPrefixes: [root], limit: 10)
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits.first?.path, path("s.md"))
    }

    func testSearchRespectsRootPrefix() {
        index.upsert([
            (path: "/other-root/x.md", mtime: 1, size: 10, body: "enterprise here too"),
            (path: path("y.md"), mtime: 1, size: 10, body: "enterprise inside test root"),
        ])
        let hits = index.search(query: "enterprise", rootPrefixes: [root], limit: 10)
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits.first?.path, path("y.md"))
    }

    func testSearchExactPaths() {
        index.upsert([
            (path: path("p1.md"), mtime: 1, size: 10, body: "shared keyword alpha"),
            (path: path("p2.md"), mtime: 1, size: 10, body: "shared keyword beta"),
        ])
        let hits = index.search(query: "keyword", exactPaths: [path("p1.md")], limit: 10)
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits.first?.path, path("p1.md"))
    }

    func testUpsertUpdatesBody() {
        index.upsert([(path: path("u.md"), mtime: 1, size: 10, body: "version one apples")])
        index.upsert([(path: path("u.md"), mtime: 2, size: 11, body: "version two bananas")])
        XCTAssertEqual(index.search(query: "apples", rootPrefixes: [root], limit: 10).count, 0)
        XCTAssertEqual(index.search(query: "bananas", rootPrefixes: [root], limit: 10).count, 1)
    }

    func testBody() {
        index.upsert([(path: path("body.md"), mtime: 1, size: 10, body: "line1\nline2\nline3")])
        XCTAssertEqual(index.body(path: path("body.md")), "line1\nline2\nline3")
        XCTAssertNil(index.body(path: path("missing.md")))
    }

    func testMatchLinesMarksOccurrences() {
        index.upsert([(path: path("m.md"), mtime: 1, size: 10,
                       body: "intro\ncontains needle here\nanother needle line\nnothing")])
        let lines = index.matchLines(path: path("m.md"), query: "needle", limit: 10)
        XCTAssertEqual(lines.count, 2)
        for line in lines {
            XCTAssertTrue(line.contains("\u{1}"))
            XCTAssertTrue(line.contains("\u{2}"))
            XCTAssertTrue(Highlighter.plain(line).localizedCaseInsensitiveContains("needle"))
        }
    }

    func testMatchLinesRespectsLimit() {
        let body = (0..<10).map { "needle row \($0)" }.joined(separator: "\n")
        index.upsert([(path: path("lim.md"), mtime: 1, size: 10, body: body)])
        XCTAssertEqual(index.matchLines(path: path("lim.md"), query: "needle", limit: 3).count, 3)
    }

    func testMatchLinesEmptyQuery() {
        index.upsert([(path: path("e.md"), mtime: 1, size: 10, body: "anything")])
        XCTAssertTrue(index.matchLines(path: path("e.md"), query: "  ", limit: 10).isEmpty)
    }

    func testAllStamps() {
        index.upsert([
            (path: path("s1.md"), mtime: 100, size: 11, body: "x"),
            (path: path("s2.md"), mtime: 200, size: 22, body: "y"),
        ])
        let stamps = index.allStamps()
        XCTAssertEqual(stamps[path("s1.md")]?.size, 11)
        XCTAssertEqual(stamps[path("s2.md")]?.mtime, 200)
    }

    // MARK: - 브라우즈 파일 메타데이터

    func testUpsertFilesBrowseAndCount() {
        index.upsertFiles([
            (path: path("a.pdf"), name: "a.pdf", ext: "pdf", size: 100, mtime: 3),
            (path: path("b.md"), name: "b.md", ext: "md", size: 200, mtime: 1),
            (path: path("c.docx"), name: "c.docx", ext: "docx", size: 300, mtime: 2),
        ])
        let exts = ["pdf", "md", "docx"]
        XCTAssertEqual(index.browseCount(rootPrefixes: [root], exts: exts), 3)

        // mtime 내림차순.
        let rows = index.browse(rootPrefixes: [root], exts: exts,
                                orderColumn: "mtime", ascending: false, limit: 100)
        XCTAssertEqual(rows.map(\.path), [path("a.pdf"), path("c.docx"), path("b.md")])
    }

    func testBrowseFiltersByExt() {
        index.upsertFiles([
            (path: path("a.pdf"), name: "a.pdf", ext: "pdf", size: 100, mtime: 1),
            (path: path("b.md"), name: "b.md", ext: "md", size: 200, mtime: 2),
        ])
        let rows = index.browse(rootPrefixes: [root], exts: ["pdf"],
                                orderColumn: "mtime", ascending: false, limit: 100)
        XCTAssertEqual(rows.map(\.path), [path("a.pdf")])
        XCTAssertEqual(index.browseCount(rootPrefixes: [root], exts: ["pdf"]), 1)
    }

    func testKnownPathsAndDelete() {
        index.upsertFiles([
            (path: path("k1"), name: "k1", ext: "md", size: 1, mtime: 1),
            (path: path("k2"), name: "k2", ext: "md", size: 1, mtime: 1),
        ])
        XCTAssertEqual(index.knownPaths(rootPrefixes: [root]), Set([path("k1"), path("k2")]))
        index.deleteFiles([path("k1")])
        XCTAssertEqual(index.knownPaths(rootPrefixes: [root]), Set([path("k2")]))
    }
}
