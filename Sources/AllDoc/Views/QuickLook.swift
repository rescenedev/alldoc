import AppKit
import Quartz

/// 스페이스바 Quick Look 미리보기 (Finder 와 동일한 동작).
final class QuickLook: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    static let shared = QuickLook()

    /// 현재 미리볼 문서 URL. (메인 스레드에서만 갱신/조회)
    private var currentURL: URL?

    @MainActor
    func toggle() {
        currentURL = DocStore.shared.selectedURL
        guard currentURL != nil, let panel = QLPreviewPanel.shared() else {
            NSSound.beep()
            return
        }
        if QLPreviewPanel.sharedPreviewPanelExists() && panel.isVisible {
            panel.orderOut(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            panel.dataSource = self
            panel.delegate = self
            panel.makeKeyAndOrderFront(nil)
            panel.reloadData()
        }
    }

    /// 패널이 열려 있을 때 선택이 바뀌면 갱신.
    @MainActor
    func refreshIfVisible() {
        guard QLPreviewPanel.sharedPreviewPanelExists(),
              let panel = QLPreviewPanel.shared(), panel.isVisible else { return }
        currentURL = DocStore.shared.selectedURL
        panel.reloadData()
    }

    // MARK: - QLPreviewPanelDataSource

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        currentURL == nil ? 0 : 1
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        currentURL as NSURL?
    }

    // MARK: - QLPreviewPanelDelegate

    /// 미리보기가 열린 상태에서 ↑/↓ → 목록의 다음/이전 파일로 이동하고 미리보기 갱신 (Finder 동일).
    func previewPanel(_ panel: QLPreviewPanel!, handle event: NSEvent!) -> Bool {
        guard event.type == .keyDown else { return false }
        let delta: Int
        switch event.keyCode {
        case 125: delta = 1     // ↓
        case 126: delta = -1    // ↑
        default: return false
        }
        MainActor.assumeIsolated {
            DocStore.shared.moveSelection(by: delta)
            currentURL = DocStore.shared.selectedURL
        }
        panel.reloadData()
        return true
    }
}
