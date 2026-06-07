import SwiftUI
import AppKit

struct SidebarView: View {
    @EnvironmentObject var store: DocStore

    var body: some View {
        List(selection: Binding(
            get: { store.selectedLocationID },
            set: { id in if let id { store.selectLocationID(id) } }
        )) {
            Section {
                Label("전체 폴더", systemImage: "square.grid.2x2.fill")
                    .tag(DocStore.allID)
                    .contentShape(Rectangle())
                    .onTapGesture { store.selectLocationID(DocStore.allID) }
                HStack {
                    Label("즐겨찾기", systemImage: "star.fill")
                    Spacer()
                    if !store.favorites.isEmpty {
                        Text("\(store.favorites.count)")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .tag(DocStore.favoritesID)
                .contentShape(Rectangle())
                .onTapGesture { store.selectLocationID(DocStore.favoritesID) }
            }

            Section("지정 폴더") {
                ForEach(store.managedFolders) { loc in
                    HStack(spacing: 8) {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(Color.accentColor)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(loc.title).font(.system(size: 13))
                            Text(loc.url.deletingLastPathComponent().path)
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                                .truncationMode(.head)
                        }
                    }
                    .tag(loc.id)
                    .contentShape(Rectangle())
                    .onTapGesture { store.selectLocationID(loc.id) }
                    .contextMenu {
                        Button("Finder에서 보기") {
                            NSWorkspace.shared.activateFileViewerSelecting([loc.url])
                        }
                        Divider()
                        Button("목록에서 제거", role: .destructive) {
                            store.removeFolder(loc)
                        }
                    }
                }

                if store.managedFolders.isEmpty {
                    Text("관리할 폴더가 없습니다")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .listStyle(.sidebar)
    }
}
