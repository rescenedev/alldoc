import SwiftUI
import AppKit

/// docx·doc·rtf·odt·html 등 서식 있는 문서를 NSAttributedString 으로 직접 파싱해
/// 흰 페이지 위에 실제 서식 그대로 렌더링한다. 검색어는 노란 하이라이트 + 첫 일치로 스크롤.
/// NSScrollView 가 통합 툴바 안전영역을 자동 보정해 헤더를 침범하지 않는다.
struct RichDocPreview: NSViewRepresentable {
    let url: URL
    var query: String = ""

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = true
        scroll.backgroundColor = .white
        scroll.automaticallyAdjustsContentInsets = true
        if let tv = scroll.documentView as? NSTextView {
            tv.isEditable = false
            tv.isSelectable = true
            tv.drawsBackground = true
            tv.backgroundColor = .white
            tv.textColor = .black
            tv.textContainerInset = NSSize(width: 28, height: 24)
            tv.textContainer?.widthTracksTextView = true   // 폭 맞춤(뷰 너비에 맞춰 줄바꿈)
            tv.textContainer?.lineFragmentPadding = 0
        }
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let tv = scroll.documentView as? NSTextView else { return }
        let coord = context.coordinator
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)

        if coord.url != url {
            coord.url = url
            coord.appliedQuery = nil
            if let attr = Self.load(url) {
                tv.textStorage?.setAttributedString(Self.scaled(attr, by: 2.0))  // 기본 200%
            } else {
                tv.string = ""
            }
        }
        guard coord.appliedQuery != q else { return }
        coord.appliedQuery = q
        Self.applyHighlight(tv, query: q)
    }

    private static func load(_ url: URL) -> NSAttributedString? {
        // 확장자/내용으로 형식 자동 판별(docx=officeOpenXML, rtf, odt, html …).
        try? NSAttributedString(url: url, options: [:], documentAttributes: nil)
    }

    /// 문서 글꼴 크기를 일괄 배율 적용(가독성 위해 기본 확대).
    private static func scaled(_ attr: NSAttributedString, by factor: CGFloat) -> NSAttributedString {
        let m = NSMutableAttributedString(attributedString: attr)
        let full = NSRange(location: 0, length: m.length)
        m.enumerateAttribute(.font, in: full) { value, range, _ in
            let base = (value as? NSFont) ?? NSFont.systemFont(ofSize: 12)
            let bigger = NSFont(descriptor: base.fontDescriptor, size: base.pointSize * factor)
                ?? NSFont.systemFont(ofSize: base.pointSize * factor)
            m.addAttribute(.font, value: bigger, range: range)
        }
        return m
    }

    private static func applyHighlight(_ tv: NSTextView, query: String) {
        guard let storage = tv.textStorage else { return }
        let full = NSRange(location: 0, length: storage.length)
        storage.removeAttribute(.backgroundColor, range: full)
        guard !query.isEmpty else { return }
        let text = storage.string as NSString
        var search = NSRange(location: 0, length: text.length)
        var first: NSRange?
        while search.location < text.length {
            let found = text.range(of: query, options: [.caseInsensitive], range: search)
            if found.location == NSNotFound { break }
            storage.addAttribute(.backgroundColor,
                                 value: NSColor.systemYellow.withAlphaComponent(0.6),
                                 range: found)
            if first == nil { first = found }
            let next = found.location + max(found.length, 1)
            search = NSRange(location: next, length: text.length - next)
        }
        if let first { tv.scrollRangeToVisible(first) }
    }

    final class Coordinator {
        var url: URL?
        var appliedQuery: String?
    }
}
