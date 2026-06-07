import Foundation

/// 사이드바에 표시되는 위치(즐겨찾기 폴더).
struct SidebarLocation: Identifiable, Hashable {
    let id: String
    let title: String
    let symbol: String
    let url: URL

    static func defaults() -> [SidebarLocation] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        func loc(_ id: String, _ title: String, _ symbol: String, _ sub: String) -> SidebarLocation? {
            let url = home.appendingPathComponent(sub, isDirectory: true)
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            return SidebarLocation(id: id, title: title, symbol: symbol, url: url)
        }
        var items: [SidebarLocation] = [
            SidebarLocation(id: "home", title: "홈", symbol: "house", url: home)
        ]
        items.append(contentsOf: [
            loc("desktop",   "데스크탑",  "menubar.dock.rectangle", "Desktop"),
            loc("documents", "문서",      "doc.on.doc",             "Documents"),
            loc("downloads", "다운로드",  "arrow.down.circle",      "Downloads"),
        ].compactMap { $0 })
        return items
    }
}
