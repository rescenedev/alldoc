import SwiftUI
import PDFKit
import AppKit

/// PDF 본문을 PDFKit 으로 실제 렌더링해 미리보기 영역을 가득 채운다.
/// 검색어가 있으면 일치 텍스트를 하이라이트하고 첫 일치로 스크롤한다.
/// PDFView 내부 NSScrollView 가 통합 툴바 안전영역을 자동 보정해 헤더를 침범하지 않는다.
struct PDFPreview: NSViewRepresentable {
    let url: URL
    var query: String = ""

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = NSColor(Color.appBG)
        return view
    }

    func updateNSView(_ view: PDFView, context: Context) {
        let coord = context.coordinator
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)

        // 문서 교체
        if coord.url != url {
            coord.url = url
            coord.appliedQuery = nil
            view.document = PDFDocument(url: url)
        }
        guard let doc = view.document else { return }

        // 같은 (문서, 검색어) 면 재작업 안 함(깜박임 방지)
        guard coord.appliedQuery != q else { return }
        coord.appliedQuery = q

        if q.isEmpty {
            view.highlightedSelections = nil
            if let first = doc.page(at: 0) { view.go(to: first) }
            return
        }

        let matches = doc.findString(q, withOptions: [.caseInsensitive, .diacriticInsensitive])
        if matches.isEmpty {
            view.highlightedSelections = nil
            if let first = doc.page(at: 0) { view.go(to: first) }
            return
        }
        for sel in matches { sel.color = NSColor.systemYellow.withAlphaComponent(0.55) }
        view.highlightedSelections = matches
        if let firstSel = matches.first {
            view.setCurrentSelection(firstSel, animate: false)
            view.go(to: firstSel)   // 첫 일치 위치로 스크롤
        }
    }

    final class Coordinator {
        var url: URL?
        var appliedQuery: String?
    }
}
