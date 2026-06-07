import XCTest
@testable import AllDoc

final class HighlighterTests: XCTestCase {
    private let open = "\u{1}"
    private let close = "\u{2}"

    func testPlainRemovesMarkers() {
        let marked = "abc\u{1}def\u{2}ghi"
        XCTAssertEqual(Highlighter.plain(marked), "abcdefghi")
    }

    func testPlainNoMarkersIsIdentity() {
        XCTAssertEqual(Highlighter.plain("hello world"), "hello world")
    }

    func testMarkSingleOccurrence() {
        let (marked, hit) = Highlighter.mark("hello world", term: "world")
        XCTAssertTrue(hit)
        XCTAssertEqual(marked, "hello \(open)world\(close)")
    }

    func testMarkIsCaseInsensitive() {
        let (marked, hit) = Highlighter.mark("Hello WORLD", term: "world")
        XCTAssertTrue(hit)
        // 원문 대소문자는 보존된다.
        XCTAssertEqual(marked, "Hello \(open)WORLD\(close)")
    }

    func testMarkMultipleOccurrences() {
        let (marked, hit) = Highlighter.mark("a a a", term: "a")
        XCTAssertTrue(hit)
        XCTAssertEqual(marked, "\(open)a\(close) \(open)a\(close) \(open)a\(close)")
        // 마커를 제거하면 원문과 같아야 한다.
        XCTAssertEqual(Highlighter.plain(marked), "a a a")
    }

    func testMarkNoMatchReturnsOriginal() {
        let (marked, hit) = Highlighter.mark("hello", term: "zzz")
        XCTAssertFalse(hit)
        XCTAssertEqual(marked, "hello")
    }

    func testMarkEmptyTermReturnsOriginal() {
        let (marked, hit) = Highlighter.mark("hello", term: "")
        XCTAssertFalse(hit)
        XCTAssertEqual(marked, "hello")
    }

    func testMarkKorean() {
        let (marked, hit) = Highlighter.mark("이력서 박성일 이력", term: "이력")
        XCTAssertTrue(hit)
        XCTAssertEqual(Highlighter.plain(marked), "이력서 박성일 이력")
        XCTAssertTrue(marked.contains("\(open)이력\(close)"))
    }

    func testTextRendersWithoutCrash() {
        // SwiftUI Text 의 내부 내용은 단언하기 어렵지만, 마커가 있는 문자열로도
        // 크래시 없이 Text 를 만들어야 한다.
        _ = Highlighter.text("plain text")
        _ = Highlighter.text("a \u{1}b\u{2} c")
        _ = Highlighter.text("\u{1}열린 마커만\u{1} 닫힘 없음")   // 비정상 입력도 안전
    }
}
