import SwiftUI
import AppKit

/// 배경(머티리얼)에 영향받지 않는 고정색 구분선 — 위/아래/좌우 색을 통일.
private struct HSep: View { var body: some View { Color.appLine.frame(height: 1) } }
private struct VSep: View { var body: some View { Color.appLine.frame(width: 1) } }

struct ContentView: View {
    @EnvironmentObject var store: DocStore
    @State private var showInspector = false   // 기본은 목록 중심, 미리보기는 Space(Quick Look)
    @State private var showSidebar = true
    @FocusState private var searchFocused: Bool
    @AppStorage("inspectorWidth") private var storedInspectorWidth: Double = 460
    @State private var liveInspectorWidth: Double?
    @State private var dragStartWidth: Double?
    private var inspectorWidth: Double { liveInspectorWidth ?? storedInspectorWidth }

    var body: some View {
        // NavigationStack 으로 네이티브 통합 툴바를 한 줄로 쓴다(신호등 세로 중앙 정렬).
        // NavigationSplitView 와 달리 사이드바 토글/추가 줄을 만들지 않는다. 분할은 수동.
        NavigationStack {
            HStack(spacing: 0) {
                if showSidebar {
                    SidebarView()
                        .frame(width: 240)
                        .transition(.move(edge: .leading))
                    VSep()
                }
                VStack(spacing: 0) {
                    FileBrowserView()
                    HSep()
                    StatusBar()
                }
                .frame(maxWidth: .infinity)
                if showInspector {
                    inspectorResizeHandle
                    InspectorView()
                        .frame(width: inspectorWidth)
                        .transition(.move(edge: .trailing))
                }
            }
            .navigationTitle("")
            .toolbar { toolbarContent }
            // 슬레이트 단일 톤. 불투명이라 아래로 들어온 콘텐츠도 비치지 않음.
            .toolbarBackground(Color.appBG, for: .windowToolbar)
            .toolbarBackground(.visible, for: .windowToolbar)
        }
        .onChange(of: store.focusSearchPulse) {
            searchFocused = true
            // ⌘K 로 검색 시작하면 본문 미리보기를 바로 볼 수 있게 패널도 연다.
            if !showInspector { withAnimation(.easeInOut(duration: 0.18)) { showInspector = true } }
        }
        .frame(minWidth: 900, minHeight: 580)
    }

    // 인스펙터 폭 조절 드래그 핸들 (1px 선 + 10px 히트영역).
    private var inspectorResizeHandle: some View {
        Rectangle()
            .fill(Color.appLine)
            .frame(width: 1)
            .overlay(
                Color.clear
                    .frame(width: 10)
                    .contentShape(Rectangle())
                    .onHover { inside in
                        if inside { NSCursor.resizeLeftRight.set() } else { NSCursor.arrow.set() }
                    }
                    .gesture(
                        // 전역 좌표 기준: 핸들이 같이 움직여도 좌표가 흔들리지 않아 진동(떨림) 없음.
                        DragGesture(coordinateSpace: .global)
                            .onChanged { v in
                                if dragStartWidth == nil { dragStartWidth = storedInspectorWidth }
                                let start = dragStartWidth ?? storedInspectorWidth
                                let maxW = Double(NSApp.keyWindow?.frame.width ?? 1800) * 0.62
                                liveInspectorWidth = min(maxW, max(320, start - Double(v.translation.width)))
                            }
                            .onEnded { _ in
                                if let w = liveInspectorWidth { storedInspectorWidth = w }  // 끝에만 저장
                                liveInspectorWidth = nil
                                dragStartWidth = nil
                            }
                    )
            )
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // 좌상단: 사이드바 접기/펴기 + 폴더 추가
        ToolbarItemGroup(placement: .navigation) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { showSidebar.toggle() }
            } label: {
                Image(systemName: "sidebar.left")
            }
            .help("사이드바 표시/숨김")

            Button {
                store.promptAddFolders()
            } label: {
                Image(systemName: "folder.badge.plus")
            }
            .help("폴더 추가")
        }
        // 정중앙: 검색창 + 범위 토글(이름/본문 다중 선택, 기본 둘 다)
        ToolbarItem(placement: .principal) {
            HStack(spacing: 8) {
                searchField
                HStack(spacing: 2) {
                    scopeChip("이름", on: store.nameEnabled) { store.toggleName() }
                    scopeChip("본문", on: store.contentEnabled) { store.toggleContent() }
                }
                .padding(2)
                .background(Capsule(style: .continuous).fill(Color.appElevated))
            }
        }
        // 우측: 보기 / 필터 / 정렬 / 미리보기
        ToolbarItemGroup(placement: .primaryAction) {
            Picker("보기", selection: $store.viewMode) {
                ForEach(ViewMode.allCases) { Image(systemName: $0.symbol).tag($0) }
            }
            .pickerStyle(.segmented)
            .help("보기 방식")

            TypeFilterMenu()
            SortMenu()

            Button { withAnimation(.easeInOut(duration: 0.18)) { showInspector.toggle() } } label: {
                Image(systemName: "sidebar.right")
            }
            .help("미리보기 패널")
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 12, weight: .medium))

            TextField(searchPrompt, text: $store.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($searchFocused)
                .frame(maxWidth: .infinity)
                .onSubmit { store.submitSearch() }   // Enter: 본문까지 검색

            if store.isSearching {
                ProgressView().controlSize(.small)
            } else if !store.searchText.isEmpty {
                Button { store.searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)   // 좌우 동일
        .frame(width: 380, height: 30)
        // 단일선: 평상시엔 채움 한 겹만, 포커스 때만 가장자리에 맞춘 강조선.
        .background(
            Capsule(style: .continuous)
                .fill(Color.appElevated)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.accentColor, lineWidth: 1.5)
                .opacity(searchFocused ? 1 : 0)
        )
    }

    private func scopeChip(_ title: String, on: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: on ? .semibold : .regular))
                .foregroundStyle(on ? Color.white : Color.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Capsule(style: .continuous).fill(on ? Color.accentColor : Color.clear))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(on ? "\(title) 검색 켜짐" : "\(title) 검색 꺼짐")
    }

    private var searchPrompt: String {
        // 본문 검색이 켜져 있으면 Enter 로 본문까지 검색함을 알린다.
        store.contentEnabled ? "‘\(store.scopeTitle)’ 검색  ·  Enter로 본문" : "‘\(store.scopeTitle)’ 검색  ⌘K"
    }
}

/// 하단 상태 줄.
struct StatusBar: View {
    @EnvironmentObject var store: DocStore

    var body: some View {
        HStack(spacing: 8) {
            if store.isSearchMode {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
            }
            Text(store.statusText)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            Text("Space: 미리보기")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            BackendBadge()
        }
        .padding(.horizontal, 12)
        .frame(height: 24)
        .background(Color.appBG)
    }
}

/// 백엔드 도구 가용 상태 배지.
struct BackendBadge: View {
    @EnvironmentObject var store: DocStore

    var body: some View {
        let missing = store.tools.missingRequired
        HStack(spacing: 6) {
            if missing.isEmpty {
                Label("fd · fzf · SQLite FTS5", systemImage: "bolt.horizontal.circle")
                    .foregroundStyle(.secondary)
            } else {
                Label("도구 없음: \(missing.joined(separator: ", "))", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
        }
        .font(.system(size: 10))
        .help(missing.isEmpty
              ? "fd, ripgrep, fzf 백엔드 사용 가능"
              : "brew install \(missing.joined(separator: " ")) 필요")
    }
}
