import Foundation

/// fd / fzf / ripgrep 을 조합한 검색 엔진.
enum SearchService {
    static let maxResults = 800
    static let maxExtractFiles = 6000
    static let browseCap = 4000

    // MARK: - 폴더 아래 모든 문서를 평탄하게 나열 (fd 재귀)

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

    // MARK: - 본문 검색 (텍스트 추출 → ripgrep)

    /// 본문 검색(스트리밍). 결과가 나오는 대로 `onBatch` 로 흘려보낸다.
    /// 1단계: 평문 파일(txt/md/csv/log…)은 추출 없이 ripgrep 으로 즉시 검색.
    /// 2단계: pdf/office/hwpx 는 작은 청크로 추출→검색하며 진행 상황을 보고.
    static func searchByContent(
        query: String,
        roots: [URL],
        types: Set<DocType>,
        progress: @MainActor @escaping (String) -> Void,
        onBatch: @MainActor @escaping ([DocFile]) -> Void
    ) async throws {
        let pattern = query.trimmingCharacters(in: .whitespacesAndNewlines)
            .decomposedStringWithCanonicalMapping
        guard !pattern.isEmpty else { return }
        guard let fd = ToolLocator.shared.fd, !roots.isEmpty else { return }
        guard ToolLocator.shared.rg != nil else { throw ProcessRunnerError.launchFailed("rg 없음") }

        let exts = extensions(for: types).filter { DocType.canExtractContent(extension: $0) }
        guard !exts.isEmpty else { return }

        var args = fdBaseArgs(exts: exts)
        args.append(".")
        args.append(contentsOf: roots.map { $0.path })

        let fdResult = try await ProcessRunner.run(fd, arguments: args)
        try Task.checkCancellation()
        let candidates = fdResult.stdoutString
            .split(separator: "\n").map(String.init)
            .filter { !$0.isEmpty }
            .prefix(maxExtractFiles).map { $0 }
        guard !candidates.isEmpty else { return }

        // 정규화 주의: Process 가 argv 를 NFD 로 바꾸므로 질의는 항상 NFD 로 도착한다.
        // 따라서 원본을 직접 검색하지 않고, 모든 문서를 NFD 캐시로 추출해 검색한다.
        // 단, 추출이 싼 평문 파일을 먼저 처리해 결과가 빨리 뜨도록 순서를 잡는다.
        let cheapExts: Set<String> = ["txt", "text", "log", "md", "markdown", "mdown", "csv", "tsv"]
        let ordered = candidates.sorted { a, b in
            let ca = cheapExts.contains((a as NSString).pathExtension.lowercased())
            let cb = cheapExts.contains((b as NSString).pathExtension.lowercased())
            return ca && !cb   // 평문 먼저
        }

        let extractor = TextExtractor.shared
        let total = ordered.count
        var processed = 0
        var emitted = 0

        for chunk in ordered.chunked(into: 16) {
            try Task.checkCancellation()
            let doneCount = processed, foundCount = emitted
            await MainActor.run { progress("문서 색인 \(doneCount)/\(total) · 결과 \(foundCount)개") }

            // 청크 동시 추출(NFD 캐시) → shadow경로 : 원본경로 매핑.
            let pairs: [(String, String)] = await withTaskGroup(of: (String, String)?.self) { group in
                for path in chunk {
                    group.addTask {
                        let url = URL(fileURLWithPath: path)
                        guard let f = DocFile.read(from: url),
                              let shadow = await extractor.ensureExtracted(url, mtime: f.modified, size: f.size)
                        else { return nil }
                        return (shadow.path, path)
                    }
                }
                var out: [(String, String)] = []
                for await r in group { if let r { out.append(r) } }
                return out
            }
            processed += chunk.count
            guard !pairs.isEmpty else { continue }

            let shadowToOrig = Dictionary(pairs, uniquingKeysWith: { a, _ in a })
            let matches = try await rgMatches(pattern: pattern, files: pairs.map { $0.0 })
            let docs: [DocFile] = matches.compactMap { shadow, snips in
                guard let orig = shadowToOrig[shadow],
                      var f = DocFile.read(from: URL(fileURLWithPath: orig)) else { return nil }
                f.snippets = snips
                return f
            }
            if !docs.isEmpty { emitted += docs.count; await MainActor.run { onBatch(docs) } }
            extractor.flush()
            if emitted >= maxResults { break }
        }
        extractor.flush()
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

        // 본문 매칭 (추출 → rg)
        if contentEnabled {
            let extractor = TextExtractor.shared
            let extractable = files.filter { DocType.canExtractContent(extension: $0.pathExtension) }
            let pairs: [(String, String)] = await withTaskGroup(of: (String, String)?.self) { group in
                for url in extractable {
                    group.addTask {
                        guard let f = DocFile.read(from: url),
                              let shadow = await extractor.ensureExtracted(url, mtime: f.modified, size: f.size)
                        else { return nil }
                        return (shadow.path, url.path)
                    }
                }
                var out: [(String, String)] = []
                for await r in group { if let r { out.append(r) } }
                return out
            }
            extractor.flush()
            if !pairs.isEmpty {
                let shadowToOrig = Dictionary(pairs, uniquingKeysWith: { a, _ in a })
                let matches = try await rgMatches(pattern: trimmed.decomposedStringWithCanonicalMapping,
                                                  files: pairs.map { $0.0 })
                for (shadow, snips) in matches {
                    guard let orig = shadowToOrig[shadow],
                          var f = DocFile.read(from: URL(fileURLWithPath: orig)) else { continue }
                    f.snippets = snips
                    add(f)
                }
            }
        }

        return order.compactMap { byURL[$0] }
    }

    // MARK: - 백그라운드 사전 색인 (폴더 선택 시 캐시 미리 데우기)

    static func prewarm(roots: [URL], types: Set<DocType>) async {
        guard let fd = ToolLocator.shared.fd, !roots.isEmpty else { return }
        let exts = extensions(for: types).filter { DocType.canExtractContent(extension: $0) }
        guard !exts.isEmpty else { return }

        var args = fdBaseArgs(exts: exts)
        args.append(".")
        args.append(contentsOf: roots.map { $0.path })

        guard let result = try? await ProcessRunner.run(fd, arguments: args) else { return }
        let files = result.stdoutString
            .split(separator: "\n").map(String.init)
            .filter { !$0.isEmpty }
            .prefix(maxExtractFiles).map { $0 }
        let extractor = TextExtractor.shared

        for chunk in files.chunked(into: 16) {
            if Task.isCancelled { extractor.flush(); return }
            await withTaskGroup(of: Void.self) { group in
                for path in chunk {
                    group.addTask {
                        if Task.isCancelled { return }
                        let url = URL(fileURLWithPath: path)
                        guard let f = DocFile.read(from: url) else { return }
                        _ = await extractor.ensureExtracted(url, mtime: f.modified, size: f.size)
                    }
                }
            }
            extractor.flush()
        }
        extractor.flush()
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

    /// 주어진 파일들에 대해 ripgrep 을 돌려 (파일경로, 스니펫들) 목록을 매칭 순서대로 반환.
    private static func rgMatches(pattern: String, files: [String]) async throws -> [(String, [ContentSnippet])] {
        guard let rg = ToolLocator.shared.rg, !files.isEmpty else { return [] }
        var args = ["--json", "--smart-case", "--fixed-strings", "--max-count", "6", "--max-columns", "300", "--", pattern]
        args.append(contentsOf: files)
        let result = try await ProcessRunner.run(rg, arguments: args)
        try Task.checkCancellation()

        var byPath: [String: [ContentSnippet]] = [:]
        var order: [String] = []
        for line in result.stdoutString.split(separator: "\n") {
            guard let data = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  obj["type"] as? String == "match",
                  let payload = obj["data"] as? [String: Any],
                  let pathInfo = payload["path"] as? [String: Any],
                  let p = pathInfo["text"] as? String,
                  let linesInfo = payload["lines"] as? [String: Any],
                  let text = linesInfo["text"] as? String
            else { continue }
            let n = (payload["line_number"] as? Int) ?? 0
            if byPath[p] == nil { byPath[p] = []; order.append(p) }
            if byPath[p]!.count < 5 {
                byPath[p]!.append(ContentSnippet(
                    lineNumber: n,
                    text: text.trimmingCharacters(in: .whitespacesAndNewlines)
                ))
            }
        }
        return order.map { ($0, byPath[$0] ?? []) }
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
