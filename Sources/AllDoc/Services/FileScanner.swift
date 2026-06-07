import Foundation

/// 현재 폴더 내용을 읽어 보여주는 브라우즈 기능 (검색 아님).
enum FileScanner {
    /// 한 폴더의 직속 항목을 읽는다. 폴더 + 지원 문서만, 숨김 파일 제외.
    static func browse(_ directory: URL, types: Set<DocType>) -> [DocFile] {
        let keys: [URLResourceKey] = [
            .isDirectoryKey, .fileSizeKey,
            .contentModificationDateKey, .creationDateKey, .isHiddenKey
        ]
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var result: [DocFile] = []
        for url in urls {
            guard let file = DocFile.read(from: url) else { continue }
            if file.isDirectory {
                result.append(file)
            } else if let type = file.docType, types.contains(type) {
                result.append(file)
            }
        }
        return result
    }
}
