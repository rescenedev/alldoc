import SwiftUI
import AppKit

struct FileBrowserView: View {
    @EnvironmentObject var store: DocStore

    var body: some View {
        Group {
            if store.items.isEmpty {
                EmptyStateView()
            } else if store.viewMode == .grid {
                gridView
            } else {
                listView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBG)
    }

    // MARK: - 목록 (기본)

    private var listView: some View {
        // 수동 선택: 클릭=무조건 선택(확실). 화살표 이동은 키 모니터가 store.selection 을
        // 바꾸고, 여기서 그 변화에 맞춰 스크롤한다.
        ScrollViewReader { proxy in
            List {
                ForEach(store.items) { file in
                    let selected = store.selection == file.id
                    // 선택 배경을 '행 콘텐츠' 레이어에 두면 라운드가 확실히 적용된다.
                    // (.listRowBackground 는 macOS 26 에서 행 전체를 꽉 채워 각지게 보임)
                    FileRowItem(file: file, isSelected: selected)
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(selected ? Color.accentColor : Color.clear)
                        )
                        .id(file.id)
                        .listRowInsets(EdgeInsets(top: 1, leading: 8, bottom: 1, trailing: 8))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture { store.select(file.id) }
                        .simultaneousGesture(TapGesture(count: 2).onEnded { store.open(file) })
                        .contextMenu { FileContextMenu(file: file) }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.appBG)
            .onChange(of: store.selection) { _, sel in
                if let sel { withAnimation(.easeOut(duration: 0.12)) { proxy.scrollTo(sel, anchor: .center) } }
            }
        }
    }

    // MARK: - 아이콘

    private var gridView: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 124, maximum: 156), spacing: 16)],
                spacing: 18
            ) {
                ForEach(store.items) { file in
                    FileGridItem(file: file, isSelected: store.selection == file.id)
                        .contentShape(Rectangle())
                        .onTapGesture { store.select(file.id) }
                        .simultaneousGesture(TapGesture(count: 2).onEnded { store.open(file) })
                        .contextMenu { FileContextMenu(file: file) }
                }
            }
            .padding(18)
        }
    }
}

/// 우클릭 컨텍스트 메뉴.
struct FileContextMenu: View {
    @EnvironmentObject var store: DocStore
    let file: DocFile

    var body: some View {
        Button("기본 앱으로 열기") { store.open(file) }
        Button("미리보기 (Space)") { store.selection = file.id; QuickLook.shared.toggle() }
        Button("Finder에서 보기") { store.revealInFinder(file) }
        Divider()
        Button(store.isFavorite(file) ? "즐겨찾기 제거" : "즐겨찾기 추가",
               systemImage: store.isFavorite(file) ? "star.slash" : "star") {
            store.toggleFavorite(file)
        }
        Divider()
        Button("경로 복사") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(file.url.path, forType: .string)
        }
    }
}

/// 비어있을 때 안내.
struct EmptyStateView: View {
    @EnvironmentObject var store: DocStore

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: emptyIcon)
                .font(.system(size: 46, weight: .light))
                .foregroundStyle(.tertiary)
            Text(emptyTitle)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            if store.managedFolders.isEmpty {
                Text("왼쪽 아래 ‘폴더 추가…’ 로 시작하세요")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyIcon: String {
        if store.isSearchMode { return "magnifyingglass" }
        return store.managedFolders.isEmpty ? "folder.badge.plus" : "doc"
    }
    private var emptyTitle: String {
        if store.isSearching { return "검색 중…" }
        if store.isSearchMode { return "검색 결과가 없습니다" }
        if store.managedFolders.isEmpty { return "관리할 폴더를 추가하세요" }
        return "이 폴더에 문서가 없습니다"
    }
}
