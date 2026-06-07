import SwiftUI
import Quartz

/// 네이티브 Quick Look(QLPreviewView)으로 문서를 실제 렌더링한다.
/// docx·pptx·xlsx·hwpx·이미지 등 PDF/텍스트가 아닌 형식의 미리보기를 영역에 가득 채워 보여준다.
/// 내부 스크롤뷰가 통합 툴바 안전영역을 자동 보정한다.
struct QuickLookView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> QLPreviewView {
        let view = QLPreviewView(frame: .zero, style: .normal) ?? QLPreviewView()
        view.autostarts = true
        view.previewItem = url as QLPreviewItem
        return view
    }

    func updateNSView(_ view: QLPreviewView, context: Context) {
        if (view.previewItem as? URL) != url {
            view.previewItem = url as QLPreviewItem
            view.refreshPreviewItem()
        }
    }
}
