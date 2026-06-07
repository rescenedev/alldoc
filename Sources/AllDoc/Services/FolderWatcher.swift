import Foundation
import CoreServices

/// FSEvents 로 지정 폴더 트리의 파일 추가/수정/삭제를 감지한다.
/// 변경이 감지되면 (배치 후) onChange 를 메인에서 호출한다.
final class FolderWatcher {
    private var stream: FSEventStreamRef?
    private let onChange: () -> Void
    private let queue = DispatchQueue(label: "AllDoc.fswatch")
    private var watchedPaths: [String] = []

    init(onChange: @escaping () -> Void) { self.onChange = onChange }

    /// 주어진 경로들이 이미 감시 중이면 무시, 아니면 재설정.
    func watch(_ paths: [String]) {
        let sorted = paths.sorted()
        guard sorted != watchedPaths else { return }
        stop()
        watchedPaths = sorted
        guard !sorted.isEmpty else { return }

        var ctx = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil, release: nil, copyDescription: nil
        )
        let flags = UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer)
        guard let s = FSEventStreamCreate(
            kCFAllocatorDefault, fsEventsCallback, &ctx,
            sorted as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            1.5,                       // latency(초): 변경 버스트를 묶어 보고
            flags
        ) else { return }
        stream = s
        FSEventStreamSetDispatchQueue(s, queue)
        FSEventStreamStart(s)
    }

    func stop() {
        guard let s = stream else { return }
        FSEventStreamStop(s)
        FSEventStreamInvalidate(s)
        FSEventStreamRelease(s)
        stream = nil
        watchedPaths = []
    }

    deinit { stop() }

    fileprivate func fire() { onChange() }
}

private func fsEventsCallback(
    _ stream: ConstFSEventStreamRef,
    _ info: UnsafeMutableRawPointer?,
    _ numEvents: Int,
    _ eventPaths: UnsafeMutableRawPointer,
    _ eventFlags: UnsafePointer<FSEventStreamEventFlags>,
    _ eventIds: UnsafePointer<FSEventStreamEventId>
) {
    guard let info else { return }
    let watcher = Unmanaged<FolderWatcher>.fromOpaque(info).takeUnretainedValue()
    DispatchQueue.main.async { watcher.fire() }
}
