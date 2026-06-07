import Foundation

/// 화면에 보이는 한 개의 항목(문서 파일 또는 폴더).
struct DocFile: Identifiable, Hashable {
    let url: URL
    let isDirectory: Bool
    let size: Int64
    let modified: Date
    let created: Date

    /// 본문 검색 결과일 때 매칭된 줄 스니펫들.
    var snippets: [ContentSnippet]

    var id: URL { url }

    var name: String { url.lastPathComponent }

    var ext: String { url.pathExtension.lowercased() }

    var docType: DocType? {
        isDirectory ? nil : DocType.from(extension: ext)
    }

    /// 지원 대상 문서인지(폴더 제외, 알 수 없는 확장자 제외).
    var isSupportedDocument: Bool {
        !isDirectory && docType != nil
    }

    init(url: URL,
         isDirectory: Bool,
         size: Int64 = 0,
         modified: Date = .distantPast,
         created: Date = .distantPast,
         snippets: [ContentSnippet] = []) {
        self.url = url
        self.isDirectory = isDirectory
        self.size = size
        self.modified = modified
        self.created = created
        self.snippets = snippets
    }

    /// 파일 시스템에서 메타데이터를 읽어 DocFile 을 만든다.
    static func read(from url: URL) -> DocFile? {
        let keys: Set<URLResourceKey> = [
            .isDirectoryKey, .fileSizeKey,
            .contentModificationDateKey, .creationDateKey
        ]
        guard let values = try? url.resourceValues(forKeys: keys) else { return nil }
        let isDir = values.isDirectory ?? false
        return DocFile(
            url: url,
            isDirectory: isDir,
            size: Int64(values.fileSize ?? 0),
            modified: values.contentModificationDate ?? .distantPast,
            created: values.creationDate ?? .distantPast
        )
    }
}

/// 본문 검색에서 매칭된 한 줄.
struct ContentSnippet: Hashable, Identifiable {
    let lineNumber: Int
    let text: String
    var id: Int { lineNumber }
}

/// 정렬 기준.
enum SortKey: String, CaseIterable, Identifiable {
    case name = "이름"
    case modified = "수정일"
    case size = "크기"
    case kind = "종류"
    var id: String { rawValue }
}

/// 보기 방식.
enum ViewMode: String, CaseIterable, Identifiable {
    case grid = "아이콘"
    case list = "목록"
    var id: String { rawValue }
    var symbol: String { self == .grid ? "square.grid.2x2" : "list.bullet" }
}
