import AppKit
import SwiftUI

/// NSWorkspace 의 실제 파일 아이콘을 캐시해서 제공한다.
@MainActor
final class FileIconProvider {
    static let shared = FileIconProvider()
    private var cache: [String: NSImage] = [:]

    func icon(for url: URL, size: CGFloat) -> NSImage {
        let key = "\(url.pathExtension.lowercased())#\(Int(size))"
        if let cached = cache[key] { return cached }
        let image = NSWorkspace.shared.icon(forFile: url.path)
        image.size = NSSize(width: size, height: size)
        cache[key] = image
        return image
    }
}

/// SwiftUI 에서 NSWorkspace 아이콘을 그리는 뷰.
struct FileIcon: View {
    let url: URL
    var size: CGFloat = 32

    var body: some View {
        Image(nsImage: FileIconProvider.shared.icon(for: url, size: size))
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
    }
}
