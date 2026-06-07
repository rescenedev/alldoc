import SwiftUI

/// 툴바의 종류 필터 메뉴.
struct TypeFilterMenu: View {
    @EnvironmentObject var store: DocStore

    private var isAll: Bool { store.enabledTypes.count == DocType.allCases.count }

    var body: some View {
        Menu {
            Button {
                store.enabledTypes = Set(DocType.allCases)
                store.refresh()
            } label: {
                Label("전체 보기", systemImage: isAll ? "checkmark" : "")
            }
            Divider()
            ForEach(DocType.allCases) { type in
                Button {
                    toggle(type)
                } label: {
                    Label(type.displayName,
                          systemImage: store.enabledTypes.contains(type) ? "checkmark" : "")
                }
            }
        } label: {
            Image(systemName: isAll ? "line.3.horizontal.decrease.circle"
                                    : "line.3.horizontal.decrease.circle.fill")
        }
        .help("문서 종류 필터")
    }

    private func toggle(_ type: DocType) {
        if store.enabledTypes.contains(type) {
            if store.enabledTypes.count > 1 { store.enabledTypes.remove(type) }
        } else {
            store.enabledTypes.insert(type)
        }
        store.refresh()
    }
}

/// 툴바의 정렬 메뉴.
struct SortMenu: View {
    @EnvironmentObject var store: DocStore

    var body: some View {
        Menu {
            ForEach(SortKey.allCases) { key in
                Button {
                    if store.sortKey == key {
                        store.sortAscending.toggle()
                    } else {
                        store.sortKey = key
                    }
                    store.refresh()
                } label: {
                    Label(key.rawValue,
                          systemImage: store.sortKey == key
                            ? (store.sortAscending ? "chevron.up" : "chevron.down")
                            : "")
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
        .help("정렬 기준")
    }
}
