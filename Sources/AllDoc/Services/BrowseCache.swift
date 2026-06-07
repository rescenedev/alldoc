import Foundation
import CryptoKit

/// 폴더 브라우즈 목록(파일 경로+메타데이터)을 디스크에 캐싱한다.
/// 큰 폴더를 다시 열 때 이전 목록을 즉시 보여주고, 최신 목록은 백그라운드에서 갱신한다.
enum BrowseCache {
    private static let dir: URL = {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("AllDoc/browse", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }()

    private struct Entry: Codable {
        let path: String
        let isDir: Bool
        let size: Int64
        let modified: Double
        let created: Double
    }

    private static func keyURL(roots: [URL], types: Set<DocType>) -> URL {
        let rootsPart = roots.map { $0.path }.sorted().joined(separator: "\n")
        let typesPart = types.map { $0.rawValue }.sorted().joined(separator: ",")
        let digest = SHA256.hash(data: Data("\(rootsPart)|\(typesPart)".utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return dir.appendingPathComponent(hex).appendingPathExtension("json")
    }

    static func load(roots: [URL], types: Set<DocType>) -> [DocFile]? {
        guard let data = try? Data(contentsOf: keyURL(roots: roots, types: types)),
              let entries = try? JSONDecoder().decode([Entry].self, from: data),
              !entries.isEmpty else { return nil }
        return entries.map {
            DocFile(url: URL(fileURLWithPath: $0.path),
                    isDirectory: $0.isDir,
                    size: $0.size,
                    modified: Date(timeIntervalSinceReferenceDate: $0.modified),
                    created: Date(timeIntervalSinceReferenceDate: $0.created))
        }
    }

    static func save(roots: [URL], types: Set<DocType>, files: [DocFile]) {
        let entries = files.map {
            Entry(path: $0.url.path,
                  isDir: $0.isDirectory,
                  size: $0.size,
                  modified: $0.modified.timeIntervalSinceReferenceDate,
                  created: $0.created.timeIntervalSinceReferenceDate)
        }
        if let data = try? JSONEncoder().encode(entries) {
            try? data.write(to: keyURL(roots: roots, types: types))
        }
    }
}
