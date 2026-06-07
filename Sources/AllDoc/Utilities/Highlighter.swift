import SwiftUI

/// 스니펫 안의 마커(\u{1}…\u{2})로 감싼 부분을 굵게 렌더링한다.
/// DocIndex 가 FTS snippet()/LIKE 폴백에서 일치 부분을 이 마커로 감싸 돌려준다.
enum Highlighter {
    static let open: Character = "\u{1}"
    static let close: Character = "\u{2}"

    /// 마커를 제거한 평문(정렬/접근성/폴백용).
    static func plain(_ s: String) -> String {
        s.filter { $0 != open && $0 != close }
    }

    /// 문자열 안의 term 모든 출현을 마커로 감싼다. (대소문자 무시)
    static func mark(_ s: String, term: String) -> (marked: String, hasMatch: Bool) {
        guard !term.isEmpty else { return (s, false) }
        var result = ""
        var rest = Substring(s)
        var found = false
        while let r = rest.range(of: term, options: .caseInsensitive) {
            result += rest[rest.startIndex..<r.lowerBound]
            result += String(open) + rest[r] + String(close)
            rest = rest[r.upperBound...]
            found = true
        }
        result += rest
        return found ? (result, true) : (s, false)
    }

    /// 마커 구간을 .bold 로 강조한 Text. (색은 부모 foregroundStyle 상속)
    static func text(_ s: String) -> Text {
        var result = Text("")
        var rest = Substring(s)
        while let start = rest.firstIndex(of: open) {
            if start > rest.startIndex {
                result = result + Text(String(rest[rest.startIndex..<start]))
            }
            let afterOpen = rest.index(after: start)
            if let end = rest[afterOpen...].firstIndex(of: close) {
                result = result + Text(String(rest[afterOpen..<end])).fontWeight(.bold)
                rest = rest[rest.index(after: end)...]
            } else {
                rest = rest[afterOpen...]
                break
            }
        }
        if !rest.isEmpty { result = result + Text(String(rest)) }
        return result
    }
}
