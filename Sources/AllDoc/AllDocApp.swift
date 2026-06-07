import SwiftUI
import AppKit
import Quartz

struct AllDocApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = DocStore.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 900, minHeight: 580)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .toolbar) {
                Button("검색으로 이동") { store.focusSearch() }
                    .keyboardShortcut("k", modifiers: [.command])
                Button("Finder에서 위치 열기") {
                    if let f = store.selectedFile { store.revealInFinder(f) }
                }
                .keyboardShortcut("o", modifiers: [.command])
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var keyMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        installKeyMonitor()

        // 스냅샷 모드: 자기 윈도우를 직접 캡처(화면 녹화 권한 불필요).
        let env = ProcessInfo.processInfo.environment
        if let prefix = env["ALLDOC_SNAPSHOT"] {
            Task { @MainActor in
                await SnapshotDriver.run(
                    outPrefix: prefix,
                    dir: env["ALLDOC_DIR"],
                    query: env["ALLDOC_QUERY"] ?? "클라우드"
                )
                NSApp.terminate(nil)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    /// Space=미리보기, Enter=열기. 단, 텍스트 입력 중(검색창)일 땐 가로채지 않는다.
    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // 검색창 등 텍스트 편집 중이면 그대로 통과.
            if event.window?.firstResponder is NSText { return event }
            let code = event.keyCode
            let consumed = MainActor.assumeIsolated { () -> Bool in
                switch code {
                case 49: // Space → Quick Look
                    guard DocStore.shared.selectedFile != nil else { return false }
                    QuickLook.shared.toggle()
                    return true
                case 36, 76: // Return / Enter → 열기
                    guard let f = DocStore.shared.selectedFile else { return false }
                    DocStore.shared.open(f)
                    return true
                case 125: // ↓
                    DocStore.shared.moveSelection(by: 1)
                    return true
                case 126: // ↑
                    DocStore.shared.moveSelection(by: -1)
                    return true
                default:
                    return false
                }
            }
            return consumed ? nil : event
        }
    }

    // MARK: - Quick Look 패널 제어 (응답 체인)

    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool { true }

    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.dataSource = QuickLook.shared
        panel.delegate = QuickLook.shared
    }

    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {}
}
