import Foundation

/// OOXML/HWPX XML 에서 사람이 읽는 텍스트만 뽑아낸다. 본문 검색용이라 완벽한 파싱은 불필요.
enum XMLTextStripper {
    /// 문단 경계로 줄바꿈을 만들고, 나머지 태그는 제거한 뒤 엔티티를 디코드한다.
    static func plainText(from xml: String) -> String {
        var s = xml

        // 문단/줄/셀 경계를 줄바꿈으로 치환 (docx <w:p>, pptx/hwpx <a:p>/<p>, xlsx 행 등).
        let breakTags = [
            "</w:p>", "</a:p>", "</p>",
            "<w:br/>", "<w:br />", "<a:br/>", "<a:br />",
            "</w:tr>", "</row>", "</c>",
        ]
        for tag in breakTags {
            s = s.replacingOccurrences(of: tag, with: "\n")
        }

        // 모든 XML 태그 제거.
        s = s.replacingOccurrences(
            of: "<[^>]+>",
            with: " ",
            options: .regularExpression
        )

        s = decodeEntities(s)

        // 공백 정리: 연속 공백 축소, 줄 앞뒤 공백 제거, 연속 빈 줄 축소.
        s = s.replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: "[ \\t]*\\n[ \\t]*", with: "\n", options: .regularExpression)
        s = s.replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)

        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func decodeEntities(_ input: String) -> String {
        var s = input
        let map = [
            "&amp;": "&", "&lt;": "<", "&gt;": ">",
            "&quot;": "\"", "&apos;": "'", "&#xA;": "\n", "&#10;": "\n",
            "&#x9;": "\t", "&#9;": "\t",
        ]
        for (k, v) in map { s = s.replacingOccurrences(of: k, with: v) }

        // 숫자 엔티티(&#1234; / &#x1F600;) 디코드.
        s = replaceRegex(s, pattern: "&#x([0-9A-Fa-f]+);", radix: 16)
        s = replaceRegex(s, pattern: "&#([0-9]+);", radix: 10)
        return s
    }

    private static func replaceRegex(_ input: String, pattern: String, radix: Int) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return input }
        let ns = input as NSString
        var result = ""
        var last = 0
        regex.enumerateMatches(in: input, range: NSRange(location: 0, length: ns.length)) { match, _, _ in
            guard let match, match.numberOfRanges >= 2 else { return }
            result += ns.substring(with: NSRange(location: last, length: match.range.location - last))
            let code = ns.substring(with: match.range(at: 1))
            if let scalarValue = UInt32(code, radix: radix), let scalar = Unicode.Scalar(scalarValue) {
                result.append(Character(scalar))
            }
            last = match.range.location + match.range.length
        }
        result += ns.substring(from: last)
        return result
    }
}
