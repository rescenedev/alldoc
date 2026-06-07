import Foundation

/// fd / fzf / ripgrep 을 조합한 검색 엔진.
enum SearchService {
    static let maxResults = 800
    static let maxExtractFiles = 6000
    static let browseCap = 50000        // 최근순 선정을 위해 stat 하는 최대 개수
    static let browseDisplayCap = 2000  // 화면에 실제로 올리는 최대 개수(전체는 검색으로)

    // MARK: - 폴더 아래 모든 문서를 평탄하게 나열 (fd 재귀)
    // 호출 측에서 detached 로 실행해 stat 부하를 메인 스레드 밖에서 처리한다.

    static func listDocuments(roots: [URL], types: Set<DocType>) async throws -> [DocFile] {
        guard let fd = ToolLocator.shared.fd, !roots.isEmpty else { return [] }
        let exts = extensions(for: types)
        guard !exts.isEmpty else { return [] }

        var args = fdBaseArgs(exts: exts)
        args.append(".")
        args.append(contentsOf: roots.map { $0.path })

        let result = try await ProcessRunner.run(fd, arguments: args)
        try Task.checkCancellation()
        return result.stdoutString
            .split(separator: "\n").map(String.init)
            .filter { !$0.isEmpty }
            .prefix(browseCap)
            .compactMap { DocFile.read(from: URL(fileURLWithPath: $0)) }
    }

    // MARK: - 이름 검색 (fd 로 후보 수집 → fzf 로 퍼지 정렬)

    static func searchByName(
        query: String,
        roots: [URL],
        types: Set<DocType>
    ) async throws -> [DocFile] {
        guard let fd = ToolLocator.shared.fd, !roots.isEmpty else { return [] }
        let exts = extensions(for: types)
        guard !exts.isEmpty else { return [] }

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        // 글롭 패턴(*.md, report?.docx 등) → fd --glob 으로 파일명 매칭.
        if trimmed.contains("*") || trimmed.contains("?") {
            var args = fdBaseArgs(exts: exts)
            args.append(contentsOf: ["--glob", trimmed])
            args.append(contentsOf: roots.map { $0.path })
            let r = try await ProcessRunner.run(fd, arguments: args)
            try Task.checkCancellation()
            return r.stdoutString
                .split(separator: "\n").map(String.init)
                .filter { !$0.isEmpty }
                .prefix(maxResults)
                .compactMap { DocFile.read(from: URL(fileURLWithPath: $0)) }
        }

        // 일반: fd 로 후보 수집 → fzf 퍼지 정렬.
        var args = fdBaseArgs(exts: exts)
        args.append(".")
        args.append(contentsOf: roots.map { $0.path })

        let fdResult = try await ProcessRunner.run(fd, arguments: args)
        try Task.checkCancellation()
        let allPaths = fdResult.stdoutString
            .split(separator: "\n")
            .map(String.init)
            .filter { !$0.isEmpty }
        guard !allPaths.isEmpty else { return [] }

        let rankedPaths: [String]
        if trimmed.isEmpty {
            rankedPaths = Array(allPaths.prefix(maxResults))
        } else if let fzf = ToolLocator.shared.fzf {
            // 한글 정규화 주의: macOS Process 는 argv 를 NFD(분해형)로 변환해 자식에게 넘긴다.
            // 따라서 fzf 후보 목록도 NFD 로 맞추고, 질의도 NFD 로 보내야 한글 매칭이 된다.
            // fzf 출력은 입력 줄을 그대로 돌려주므로 NFD→원본 경로 매핑으로 되돌린다.
            var nfdToOriginal: [String: String] = [:]
            for path in allPaths {
                nfdToOriginal[path.decomposedStringWithCanonicalMapping] = path
            }
            let input = nfdToOriginal.keys.joined(separator: "\n")
            let nfdQuery = trimmed.decomposedStringWithCanonicalMapping
            let fzfResult = try await ProcessRunner.run(
                fzf,
                arguments: ["--filter", nfdQuery, "--no-sort"],
                stdin: Data(input.utf8)
            )
            try Task.checkCancellation()
            rankedPaths = fzfResult.stdoutString
                .split(separator: "\n").map(String.init)
                .filter { !$0.isEmpty }
                .compactMap { nfdToOriginal[$0] ?? $0 }
                .prefix(maxResults).map { $0 }
        } else {
            let lower = trimmed.decomposedStringWithCanonicalMapping.lowercased()
            rankedPaths = allPaths
                .filter {
                    ($0 as NSString).lastPathComponent
                        .decomposedStringWithCanonicalMapping.lowercased()
                        .contains(lower)
                }
                .prefix(maxResults).map { $0 }
        }

        return rankedPaths.compactMap { DocFile.read(from: URL(fileURLWithPath: $0)) }
    }

    // MARK: - 본문 검색 (SQLite FTS5)

    /// 본문 검색: DocIndex(FTS5) 질의(즉시). 색인은 ensureIndexed/prewarm 이 백그라운드로 유지.
    static func searchByContent(query: String, roots: [URL], types: Set<DocType>) async -> [DocFile] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !roots.isEmpty else { return [] }
        let hits = DocIndex.shared.search(query: trimmed, rootPrefixes: roots.map { $0.path }, limit: maxResults)
        return mapHits(hits, types: types)
    }

    private static func mapHits(_ hits: [DocIndex.Hit], types: Set<DocType>) -> [DocFile] {
        let chosen = types.isEmpty ? Set(DocType.allCases) : types
        return hits.compactMap { hit in
            let url = URL(fileURLWithPath: hit.path)
            guard let type = DocType.from(extension: url.pathExtension), chosen.contains(type) else { return nil }
            guard var f = DocFile.read(from: url) else { return nil }   // 삭제된 파일(스테일 인덱스) 자동 제외
            f.snippets = [ContentSnippet(lineNumber: 0, text: hit.snippet)]
            return f
        }
    }

    /// 루트 하위 추출 가능한 문서를 DocIndex 에 색인(변경분만). 백그라운드용.
    static func ensureIndexed(roots: [URL], types: Set<DocType>,
                              progress: (@Sendable (Int, Int) -> Void)? = nil) async {
        guard let fd = ToolLocator.shared.fd, !roots.isEmpty else { return }
        let exts = extensions(for: types).filter { DocType.canExtractContent(extension: $0) }
        guard !exts.isEmpty else { return }
        var args = fdBaseArgs(exts: exts)
        args.append(".")
        args.append(contentsOf: roots.map { $0.path })
        guard let result = try? await ProcessRunner.run(fd, arguments: args) else { return }
        let paths = result.stdoutString
            .split(separator: "\n").map(String.init)
            .filter { !$0.isEmpty }
            .prefix(maxExtractFiles)

        let stamps = DocIndex.shared.allStamps()
        var toIndex: [(path: String, mtime: Double, size: Int64)] = []
        for p in paths {
            guard let f = DocFile.read(from: URL(fileURLWithPath: p)) else { continue }
            let m = f.modified.timeIntervalSinceReferenceDate
            if let s = stamps[p], s.mtime == m, s.size == f.size { continue }
            toIndex.append((p, m, f.size))
        }
        let total = toIndex.count
        guard total > 0 else { progress?(0, 0); return }

        var done = 0
        for chunk in toIndex.chunked(into: 24) {
            if Task.isCancelled { return }
            let rows: [(path: String, mtime: Double, size: Int64, body: String)] =
                await withTaskGroup(of: (String, Double, Int64, String)?.self) { group in
                    for item in chunk {
                        group.addTask {
                            guard let body = await TextExtractor.extractText(from: URL(fileURLWithPath: item.path))
                            else { return nil }
                            return (item.path, item.mtime, item.size, body)
                        }
                    }
                    var out: [(String, Double, Int64, String)] = []
                    for await r in group { if let r { out.append((r.0, r.1, r.2, r.3)) } }
                    return out
                }
            DocIndex.shared.upsert(rows)
            done += chunk.count
            progress?(done, total)
        }
    }

    // MARK: - 특정 파일 집합(즐겨찾기 등) 안에서 검색

    static func searchAmongFiles(
        query: String,
        files: [URL],
        nameEnabled: Bool,
        contentEnabled: Bool
    ) async throws -> [DocFile] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !files.isEmpty else { return [] }

        var byURL: [URL: DocFile] = [:]
        var order: [URL] = []
        func add(_ f: DocFile) {
            if byURL[f.url] == nil { order.append(f.url); byURL[f.url] = f }
            else if !f.snippets.isEmpty, byURL[f.url]?.snippets.isEmpty == true { byURL[f.url]?.snippets = f.snippets }
        }

        // 이름 매칭 (글롭은 LIKE, 그 외 부분일치, NFD 정규화)
        if nameEnabled {
            let isGlob = trimmed.contains("*") || trimmed.contains("?")
            let needle = trimmed.decomposedStringWithCanonicalMapping.lowercased()
            for url in files {
                let name = url.lastPathComponent
                let nameN = name.decomposedStringWithCanonicalMapping.lowercased()
                let match = isGlob
                    ? NSPredicate(format: "SELF LIKE[c] %@", trimmed).evaluate(with: name)
                    : nameN.contains(needle)
                if match, let f = DocFile.read(from: url) { add(f) }
            }
        }

        // 본문 매칭: 즐겨찾기 파일들을 색인(변경분만)한 뒤 DocIndex 에서 정확 경로로 질의.
        if contentEnabled {
            let extractable = files.filter { DocType.canExtractContent(extension: $0.pathExtension) }
            let stamps = DocIndex.shared.allStamps()
            let rows: [(path: String, mtime: Double, size: Int64, body: String)] =
                await withTaskGroup(of: (String, Double, Int64, String)?.self) { group in
                    for url in extractable {
                        group.addTask {
                            guard let f = DocFile.read(from: url) else { return nil }
                            let m = f.modified.timeIntervalSinceReferenceDate
                            if let s = stamps[url.path], s.mtime == m, s.size == f.size { return nil }
                            guard let body = await TextExtractor.extractText(from: url) else { return nil }
                            return (url.path, m, f.size, body)
                        }
                    }
                    var out: [(String, Double, Int64, String)] = []
                    for await r in group { if let r { out.append((r.0, r.1, r.2, r.3)) } }
                    return out
                }
            DocIndex.shared.upsert(rows)
            let hits = DocIndex.shared.search(query: trimmed, exactPaths: extractable.map { $0.path }, limit: maxResults)
            for hit in hits {
                guard var f = DocFile.read(from: URL(fileURLWithPath: hit.path)) else { continue }
                f.snippets = [ContentSnippet(lineNumber: 0, text: hit.snippet)]
                add(f)
            }
        }

        return order.compactMap { byURL[$0] }
    }

    // MARK: - 백그라운드 사전 색인 (폴더 선택 시)

    static func prewarm(roots: [URL], types: Set<DocType>) async {
        await ensureIndexed(roots: roots, types: types)
    }

    // MARK: - 보조

    private static func extensions(for types: Set<DocType>) -> [String] {
        let chosen = types.isEmpty ? Set(DocType.allCases) : types
        return chosen.flatMap { $0.fileExtensions }
    }

    private static func fdBaseArgs(exts: [String]) -> [String] {
        var a = ["--type", "f", "--absolute-path", "--color", "never", "--hidden",
                 "--exclude", ".git", "--exclude", "node_modules", "--exclude", "Library"]
        for e in exts { a.append(contentsOf: ["-e", e]) }
        return a
    }

}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
