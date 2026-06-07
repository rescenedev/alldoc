import AppKit

/// 실행 중인 앱이 자기 윈도우를 PNG 로 캡처한다. (화면 녹화 권한이 필요 없는 self-capture)
/// 데모/문서화용. 브라우즈 화면 → 본문 검색 화면을 순서대로 찍는다.
@MainActor
enum SnapshotDriver {
    static func run(outPrefix: String, dir: String?, query: String) async {
        let store = DocStore.shared

        // 시작 폴더 지정(없으면 샘플 폴더 → 홈 순으로 시도).
        let target: URL
        if let dir { target = URL(fileURLWithPath: dir) }
        else {
            let sample = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("AllDocSample")
            target = FileManager.default.fileExists(atPath: sample.path)
                ? sample : FileManager.default.homeDirectoryForCurrentUser
        }
        store.addFolder(target)

        await settle(seconds: 2.2)
        capture(to: "\(outPrefix)-1-browse.png")

        // 검색 구동 (이름+본문 둘 다 기본).
        store.searchText = query
        await settle(seconds: 3.5)
        capture(to: "\(outPrefix)-2-content-search.png")

        // 첫 결과 선택 → 인스펙터 미리보기/스니펫까지 보이게.
        if let first = store.firstSelectableID {
            store.selection = first
            await settle(seconds: 1.5)
            capture(to: "\(outPrefix)-3-detail.png")
        }
    }

    private static func settle(seconds: Double) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    private static func capture(to path: String) {
        guard let window = NSApp.windows.first(where: { $0.isVisible && $0.contentView != nil }),
              let view = window.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            FileHandle.standardError.write("스냅샷 실패: 윈도우 없음\n".data(using: .utf8)!)
            return
        }
        view.cacheDisplay(in: view.bounds, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: URL(fileURLWithPath: path))
        FileHandle.standardError.write("스냅샷 저장: \(path)\n".data(using: .utf8)!)
    }
}
