import SwiftUI

/// 텍스트 문서 본문을 SwiftUI 로 렌더링(검색어 전부 하이라이트, 일치 줄로 스크롤).
/// Quick Look(AppKit)과 달리 통합 툴바를 침범하지 않고, 검색 위치를 보여줄 수 있다.
struct TextMatchPreview: View {
    let path: String
    let query: String
    @Binding var selectedMatch: Int?

    @State private var lines: [String] = []          // 마커가 적용된 본문 줄(상한)
    @State private var matchLineIndices: [Int] = []  // 일치가 있는 줄 인덱스(출현 순)

    private static let lineCap = 6000

    var body: some View {
        // List 를 쓰면 통합 툴바 안전영역만큼 자동으로 내려써서 헤더를 침범하지 않는다.
        ScrollViewReader { proxy in
            List {
                ForEach(lines.indices, id: \.self) { i in
                    Highlighter.text(lines[i])
                        .font(.system(size: 22, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 1, leading: 8, bottom: 1, trailing: 8))
                        .listRowBackground(
                            (selectedMatch.flatMap { matchLineIndices.indices.contains($0) ? matchLineIndices[$0] : nil } == i)
                                ? Color.accentColor.opacity(0.28) : Color.clear
                        )
                        .id(i)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.appBG)
            .onChange(of: selectedMatch) { _, sel in
                guard let sel, matchLineIndices.indices.contains(sel) else { return }
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo(matchLineIndices[sel], anchor: .center)
                }
            }
        }
        .task(id: "\(path)|\(query)") { load() }
    }

    private func load() {
        guard let body = DocIndex.shared.body(path: path) else {
            lines = []; matchLineIndices = []; return
        }
        let raw = body.split(separator: "\n", omittingEmptySubsequences: false).prefix(Self.lineCap)
        var marked: [String] = []
        var matches: [Int] = []
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        for (i, line) in raw.enumerated() {
            if q.isEmpty {
                marked.append(String(line))
            } else {
                let m = Highlighter.mark(String(line), term: q)
                marked.append(m.marked)
                if m.hasMatch { matches.append(i) }
            }
        }
        lines = marked
        matchLineIndices = matches
    }
}
