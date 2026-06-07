import Foundation

/// 진입점. `--selftest <폴더> <검색어>` 인자가 있으면 백엔드 검색 파이프라인을
/// 콘솔에서 검증하고 종료한다. 그 외에는 일반 GUI 앱을 실행한다.
@main
enum Main {
    static func main() {
        let args = CommandLine.arguments
        if let idx = args.firstIndex(of: "--selftest") {
            let folder = idx + 1 < args.count
                ? args[idx + 1]
                : FileManager.default.homeDirectoryForCurrentUser.path
            let query = idx + 2 < args.count ? args[idx + 2] : "클라우드"
            runSelfTest(folder: folder, query: query)
            return
        }
        AllDocApp.main()
    }

    private static func runSelfTest(folder: String, query: String) {
        setvbuf(stdout, nil, _IONBF, 0)   // 파이프에서도 즉시 출력
        let scope = URL(fileURLWithPath: folder)
        // 메인 런루프를 살려둬야 SearchService 의 MainActor.run(progress) 가 동작한다.
        Task {
            defer { CFRunLoopStop(CFRunLoopGetMain()) }
            print("== AllDoc 자체 검증 ==")
            print("범위: \(folder)")
            print("검색어: \(query)\n")

            let tools = ToolLocator.shared
            print("도구: fd=\(tools.fd ?? "없음") rg=\(tools.rg ?? "없음") fzf=\(tools.fzf ?? "없음") unzip=\(tools.unzip ?? "없음")\n")

            do {
                print("[이름 검색]")
                let byName = try await SearchService.searchByName(
                    query: query, roots: [scope], types: Set(DocType.allCases))
                for f in byName { print("  • \(f.name)") }
                if byName.isEmpty { print("  (없음)") }

                print("\n[본문 검색]")
                var byContent: [DocFile] = []
                try await SearchService.searchByContent(
                    query: query, roots: [scope], types: Set(DocType.allCases),
                    progress: { _ in },
                    onBatch: { batch in byContent.append(contentsOf: batch) })
                for f in byContent {
                    print("  • \(f.name)")
                    for s in f.snippets.prefix(1) {
                        print("      ↳ L\(s.lineNumber): \(s.text.prefix(60))")
                    }
                }
                if byContent.isEmpty { print("  (없음)") }
                print("\n결과: 이름 \(byName.count)건, 본문 \(byContent.count)건")
            } catch {
                print("오류: \(error)")
            }
        }
        CFRunLoopRun()
    }
}
