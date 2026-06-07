import SwiftUI

/// 지원하는 문서 종류. 확장자 → 종류 매핑, 아이콘/색상, 텍스트 추출 가능 여부를 담는다.
enum DocType: String, CaseIterable, Identifiable, Hashable {
    case pdf
    case word
    case powerpoint
    case excel
    case hangul
    case markdown
    case text
    case csv
    case rtf

    var id: String { rawValue }

    /// 사이드바/필터에 보일 한글 이름.
    var displayName: String {
        switch self {
        case .pdf:        return "PDF"
        case .word:       return "Word"
        case .powerpoint: return "PowerPoint"
        case .excel:      return "Excel"
        case .hangul:     return "한글"
        case .markdown:   return "Markdown"
        case .text:       return "텍스트"
        case .csv:        return "CSV"
        case .rtf:        return "서식 문서"
        }
    }

    /// 이 종류에 속하는 파일 확장자(소문자, 점 없음).
    var fileExtensions: [String] {
        switch self {
        case .pdf:        return ["pdf"]
        case .word:       return ["docx", "doc"]
        case .powerpoint: return ["pptx", "ppt"]
        case .excel:      return ["xlsx", "xls"]
        case .hangul:     return ["hwpx", "hwp"]
        case .markdown:   return ["md", "markdown", "mdown"]
        case .text:       return ["txt", "text", "log"]
        case .csv:        return ["csv", "tsv"]
        case .rtf:        return ["rtf"]
        }
    }

    var symbol: String {
        switch self {
        case .pdf:        return "doc.richtext"
        case .word:       return "doc.text"
        case .powerpoint: return "rectangle.on.rectangle.angled"
        case .excel:      return "tablecells"
        case .hangul:     return "character.book.closed"
        case .markdown:   return "text.alignleft"
        case .text:       return "doc.plaintext"
        case .csv:        return "tablecells.badge.ellipsis"
        case .rtf:        return "doc.append"
        }
    }

    var tint: Color {
        switch self {
        case .pdf:        return Color(red: 0.90, green: 0.22, blue: 0.21)
        case .word:       return Color(red: 0.16, green: 0.38, blue: 0.74)
        case .powerpoint: return Color(red: 0.83, green: 0.36, blue: 0.18)
        case .excel:      return Color(red: 0.16, green: 0.56, blue: 0.33)
        case .hangul:     return Color(red: 0.20, green: 0.55, blue: 0.78)
        case .markdown:   return Color(red: 0.40, green: 0.40, blue: 0.45)
        case .text:       return Color(red: 0.45, green: 0.45, blue: 0.50)
        case .csv:        return Color(red: 0.30, green: 0.60, blue: 0.45)
        case .rtf:        return Color(red: 0.50, green: 0.40, blue: 0.70)
        }
    }

    /// 본문 텍스트 추출이 가능한 종류인지. (구형 OLE 포맷 doc/ppt/xls/hwp 은 제외)
    var supportsContentExtraction: Bool {
        switch self {
        case .pdf, .markdown, .text, .csv, .rtf:
            return true
        case .word, .powerpoint, .excel, .hangul:
            // 신형(zip) 포맷만 추출 가능. 확장자 단위 판단은 DocType.extractable(for:) 에서.
            return true
        }
    }

    /// 모든 지원 확장자 (소문자).
    static var allExtensions: [String] {
        allCases.flatMap { $0.fileExtensions }
    }

    /// 확장자로 종류를 찾는다.
    static func from(extension ext: String) -> DocType? {
        let lower = ext.lowercased()
        return allCases.first { $0.fileExtensions.contains(lower) }
    }

    /// 해당 확장자가 본문 추출 가능한지 (구형 바이너리 포맷은 false).
    static func canExtractContent(extension ext: String) -> Bool {
        let lower = ext.lowercased()
        let unsupported: Set<String> = ["doc", "ppt", "xls", "hwp"]
        guard !unsupported.contains(lower) else { return false }
        return from(extension: lower)?.supportsContentExtraction ?? false
    }
}
