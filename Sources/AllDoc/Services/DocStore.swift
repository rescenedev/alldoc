import SwiftUI
import AppKit

/// 앱 전체 상태. "문서 검색" 중심: 좌측은 내가 지정한 폴더 목록,
/// 본문 영역은 선택한 폴더 아래의 모든 문서를 평탄하게(재귀) 보여준다.
@MainActor
final class DocStore: ObservableObject {
    /// 단일 윈도우 공유 인스턴스.
    static let shared = DocStore()

    // 내가 지정해 관리하는 폴더들 (영구 저장)
    @Published private(set) var managedFolders: [SidebarLocation]
    @Published var selectedLocationID: String?

    // 즐겨찾기 (파일 경로, 영구 저장)
    @Published private(set) var favorites: [String] = []
    private let favKey = "AllDoc.favorites.v1"

    // 필터 / 정렬 / 보기
    @Published var enabledTypes: Set<DocType> = Set(DocType.allCases)
    @Published var sortKey: SortKey = .modified   // 기본: 최근 파일이 위로
    @Published var sortAscending = false
    @Published var viewMode: ViewMode = .list

    // 검색 — 이름/본문 각각 켜고 끌 수 있고, 기본은 둘 다(전체).
    @Published var searchText = "" { didSet { scheduleSearch() } }
    @Published private(set) var nameEnabled = true
    @Published private(set) var contentEnabled = true

    /// ⌘K 등으로 검색창 포커스를 요청할 때 증가하는 신호.
    @Published var focusSearchPulse = 0
    func focusSearch() { focusSearchPulse &+= 1 }

    /// 토글. 단, 둘 다 꺼지는 것은 막는다(최소 하나 유지).
    func toggleName() {
        if nameEnabled { if contentEnabled { nameEnabled = false } } else { nameEnabled = true }
        reSearchIfActive()
    }
    func toggleContent() {
        if contentEnabled { if nameEnabled { contentEnabled = false } } else { contentEnabled = true }
        reSearchIfActive()
    }
    private func reSearchIfActive() {
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            scheduleSearch(immediate: true)
        }
    }

    // 결과 / 상태
    @Published private(set) var items: [DocFile] = []
    @Published var selection: DocFile.ID?
    @Published private(set) var isSearching = false
    @Published private(set) var statusText = ""
    @Published private(set) var isSearchMode = false

    let tools = ToolLocator.shared

    private let foldersKey = "AllDoc.managedFolders.v1"
    private var searchTask: Task<Void, Never>?
    private var loadTask: Task<Void, Never>?
    private var prewarmTask: Task<Void, Never>?

    init() {
        managedFolders = DocStore.loadFolders(key: "AllDoc.managedFolders.v1")
        if managedFolders.isEmpty {
            // 첫 실행: 문서 폴더를 기본으로 하나 넣어둔다(제거 가능).
            let docs = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Documents", isDirectory: true)
            let url = FileManager.default.fileExists(atPath: docs.path)
                ? docs : FileManager.default.homeDirectoryForCurrentUser
            managedFolders = [makeLocation(url)]
        }
        favorites = (UserDefaults.standard.array(forKey: favKey) as? [String]) ?? []
        selectedLocationID = DocStore.allID   // 기본: 전체 폴더
        reload()
    }

    // MARK: - 범위

    static let allID = "__all__"
    static let favoritesID = "__fav__"

    var isFavoritesMode: Bool { selectedLocationID == DocStore.favoritesID }

    // MARK: - 즐겨찾기

    func isFavorite(_ file: DocFile) -> Bool { favorites.contains(file.url.path) }

    func toggleFavorite(_ file: DocFile) {
        let p = file.url.path
        if let i = favorites.firstIndex(of: p) { favorites.remove(at: i) } else { favorites.append(p) }
        UserDefaults.standard.set(favorites, forKey: favKey)
        if isFavoritesMode { refresh() }
    }

    /// 현재 검색/탐색 대상 루트들. "전체 폴더"면 지정 폴더 모두.
    var scopes: [URL] {
        if selectedLocationID == DocStore.allID { return managedFolders.map { $0.url } }
        if let loc = managedFolders.first(where: { $0.id == selectedLocationID }) { return [loc.url] }
        return managedFolders.map { $0.url }
    }

    var scopeTitle: String {
        if isFavoritesMode { return "즐겨찾기" }
        if selectedLocationID == DocStore.allID { return "전체 폴더" }
        return managedFolders.first { $0.id == selectedLocationID }?.title ?? "폴더"
    }

    // MARK: - 폴더 관리

    func selectLocationID(_ id: String) {
        guard selectedLocationID != id else { return }
        selectedLocationID = id
        searchText = ""
        selection = nil
        reload()
    }

    func selectLocation(_ location: SidebarLocation) { selectLocationID(location.id) }

    /// 폴더 선택 패널을 열어 관리 폴더로 추가.
    func promptAddFolders() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
        panel.prompt = "추가"
        panel.message = "문서를 관리·검색할 폴더를 선택하세요"
        if panel.runModal() == .OK {
            for url in panel.urls { addFolder(url) }
        }
    }

    func addFolder(_ url: URL) {
        if let existing = managedFolders.first(where: { $0.url.path == url.path }) {
            selectLocation(existing)
            return
        }
        let loc = makeLocation(url)
        managedFolders.append(loc)
        persistFolders()
        selectLocation(loc)
    }

    func removeFolder(_ location: SidebarLocation) {
        managedFolders.removeAll { $0.id == location.id }
        persistFolders()
        if selectedLocationID == location.id {
            selectedLocationID = DocStore.allID
            searchText = ""
            selection = nil
            reload()
        }
    }

    private func makeLocation(_ url: URL) -> SidebarLocation {
        SidebarLocation(id: "folder:" + url.path,
                        title: url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent,
                        symbol: "folder",
                        url: url)
    }

    private func persistFolders() {
        UserDefaults.standard.set(managedFolders.map { $0.url.path }, forKey: foldersKey)
    }

    private static func loadFolders(key: String) -> [SidebarLocation] {
        guard let paths = UserDefaults.standard.array(forKey: key) as? [String] else { return [] }
        return paths.compactMap { path in
            guard FileManager.default.fileExists(atPath: path) else { return nil }
            let url = URL(fileURLWithPath: path)
            return SidebarLocation(id: "folder:" + path,
                                   title: url.lastPathComponent.isEmpty ? path : url.lastPathComponent,
                                   symbol: "folder", url: url)
        }
    }

    // MARK: - 문서 열기

    func open(_ file: DocFile) { NSWorkspace.shared.open(file.url) }
    func revealInFinder(_ file: DocFile) {
        NSWorkspace.shared.activateFileViewerSelecting([file.url])
    }

    // MARK: - 로딩 / 검색

    func refresh() {
        if isSearchMode { scheduleSearch(immediate: true) } else { reload() }
    }

    private func reload() {
        searchTask?.cancel()
        loadTask?.cancel()
        prewarmTask?.cancel()
        isSearchMode = false

        // 즐겨찾기 모드: 저장된 파일들을 그대로 나열.
        if isFavoritesMode {
            let files = favorites.compactMap { DocFile.read(from: URL(fileURLWithPath: $0)) }
            items = sorted(files)
            isSearching = false
            statusText = files.isEmpty ? "즐겨찾기가 없습니다" : "즐겨찾기 \(files.count)개"
            if selection != nil, !files.contains(where: { $0.id == selection }) { selection = nil }
            return
        }

        let roots = scopes
        guard !roots.isEmpty else {
            items = []
            statusText = "왼쪽에서 관리할 폴더를 추가하세요"
            return
        }
        let types = enabledTypes
        isSearching = true
        statusText = "문서 불러오는 중…"
        loadTask = Task { [weak self] in
            let result = (try? await SearchService.listDocuments(roots: roots, types: types)) ?? []
            guard let self, !Task.isCancelled else { return }
            self.items = self.sorted(result)
            self.isSearching = false
            self.statusText = self.summary(count: result.count, capped: result.count >= SearchService.browseCap)
            if self.selection != nil, !result.contains(where: { $0.id == self.selection }) {
                self.selection = nil
            }
        }
        // 백그라운드에서 본문 캐시를 미리 데워 본문 검색을 빠르게.
        startPrewarm(roots: roots, types: types)
    }

    private func startPrewarm(roots: [URL], types: Set<DocType>) {
        prewarmTask?.cancel()
        prewarmTask = Task.detached(priority: .utility) {
            await SearchService.prewarm(roots: roots, types: types)
        }
    }

    private func scheduleSearch(immediate: Bool = false) {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            isSearching = false
            reload()
            return
        }
        guard isFavoritesMode || !scopes.isEmpty else { return }
        searchTask?.cancel()
        loadTask?.cancel()
        searchTask = Task { [weak self] in
            guard let self else { return }
            if !immediate {
                try? await Task.sleep(nanoseconds: 280_000_000)
                if Task.isCancelled { return }
            }
            await self.runSearch(query: trimmed)
        }
    }

    private func runSearch(query: String) async {
        isSearchMode = true
        isSearching = true
        statusText = "검색 중…"
        let types = enabledTypes
        let doName = nameEnabled
        let doContent = contentEnabled
        defer { isSearching = false }

        // 즐겨찾기 모드: 즐겨찾기 파일들 안에서만 검색.
        if isFavoritesMode {
            let favURLs = favorites.map { URL(fileURLWithPath: $0) }
            do {
                let res = try await SearchService.searchAmongFiles(
                    query: query, files: favURLs, nameEnabled: doName, contentEnabled: doContent)
                if Task.isCancelled { return }
                items = sorted(res)
                statusText = res.isEmpty ? "‘\(query)’ 결과 없음" : "검색 결과 \(res.count)개"
            } catch is CancellationError { return }
            catch { statusText = "검색 오류: \(error.localizedDescription)"; items = [] }
            return
        }

        let roots = scopes
        guard !roots.isEmpty else { return }

        // 이름·본문 결과를 합쳐서(중복 제거) 채운다. 본문 스니펫이 있으면 갱신.
        items = []
        var acc: [DocFile] = []
        var idx: [URL: Int] = [:]
        func upsert(_ batch: [DocFile], snippetsPreferred: Bool) {
            var changed = false
            for f in batch {
                if let i = idx[f.url] {
                    if snippetsPreferred, acc[i].snippets.isEmpty, !f.snippets.isEmpty {
                        acc[i].snippets = f.snippets; changed = true
                    }
                } else {
                    idx[f.url] = acc.count; acc.append(f); changed = true
                }
            }
            if changed { items = sorted(acc) }
        }

        do {
            if doName {
                let result = try await SearchService.searchByName(query: query, roots: roots, types: types)
                if Task.isCancelled { return }
                upsert(result, snippetsPreferred: false)
            }
            if doContent {
                try await SearchService.searchByContent(
                    query: query, roots: roots, types: types,
                    progress: { [weak self] msg in self?.statusText = msg },
                    onBatch: { batch in upsert(batch, snippetsPreferred: true) }
                )
            }
            if Task.isCancelled { return }
            statusText = acc.isEmpty
                ? "‘\(query)’ 검색 결과 없음"
                : "검색 결과 \(acc.count)개" + (acc.count >= SearchService.maxResults ? "+" : "")
        } catch is CancellationError {
            return
        } catch {
            statusText = "검색 오류: \(error.localizedDescription)"
            items = []
        }
    }

    // MARK: - 정렬

    func sorted(_ files: [DocFile]) -> [DocFile] {
        return files.sorted { a, b in
            let asc = sortAscending
            switch sortKey {
            case .name:
                let r = a.name.localizedStandardCompare(b.name)
                return asc ? r == .orderedAscending : r == .orderedDescending
            case .modified:
                return asc ? a.modified < b.modified : a.modified > b.modified
            case .size:
                return asc ? a.size < b.size : a.size > b.size
            case .kind:
                let ka = a.docType?.displayName ?? ""
                let kb = b.docType?.displayName ?? ""
                if ka == kb { return a.name.localizedStandardCompare(b.name) == .orderedAscending }
                let r = ka.localizedStandardCompare(kb)
                return asc ? r == .orderedAscending : r == .orderedDescending
            }
        }
    }

    var selectedFile: DocFile? {
        guard let selection else { return nil }
        return items.first { $0.id == selection }
    }

    var firstSelectableID: DocFile.ID? { items.first?.id }

    /// 화살표 키 이동: 현재 선택 기준 delta(±1) 만큼 이동.
    func moveSelection(by delta: Int) {
        guard !items.isEmpty else { return }
        let cur = items.firstIndex { $0.id == selection } ?? (delta > 0 ? -1 : 0)
        let next = max(0, min(items.count - 1, cur + delta))
        selection = items[next].id
    }

    /// 현재 선택된 문서의 URL (Quick Look 용).
    var selectedURL: URL? { selectedFile?.url }

    private func summary(count: Int, capped: Bool) -> String {
        count == 0 ? "문서 없음" : "문서 \(count)개" + (capped ? "+" : "")
    }
}
