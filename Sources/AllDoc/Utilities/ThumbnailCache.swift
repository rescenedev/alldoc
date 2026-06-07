import SwiftUI
import QuickLookThumbnailing

/// Quick Look 썸네일을 비동기 생성·캐시한다. (그리드 보기용)
@MainActor
final class ThumbnailCache {
    static let shared = ThumbnailCache()
    private var cache: [String: NSImage] = [:]

    func thumbnail(for url: URL, pixel: CGFloat) async -> NSImage? {
        let key = "\(url.path)#\(Int(pixel))"
        if let cached = cache[key] { return cached }
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: pixel, height: pixel),
            scale: 1,
            representationTypes: .thumbnail
        )
        guard let rep = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request) else {
            return nil
        }
        let image = rep.nsImage
        cache[key] = image
        return image
    }
}

/// 썸네일이 준비되기 전엔 파일 아이콘을 보여주고, 준비되면 교체.
struct DocThumbnail: View {
    let url: URL
    var size: CGFloat = 64

    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                FileIcon(url: url, size: size)
            }
        }
        .frame(width: size, height: size)
        .task(id: url) {
            image = await ThumbnailCache.shared.thumbnail(for: url, pixel: size * 2)
        }
    }
}
