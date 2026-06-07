import XCTest
@testable import AllDoc

final class XMLTextStripperTests: XCTestCase {
    func testParagraphBreaks() {
        let xml = "<w:p><w:t>첫 줄</w:t></w:p><w:p><w:t>둘째 줄</w:t></w:p>"
        let out = XMLTextStripper.plainText(from: xml)
        let lines = out.split(separator: "\n").map(String.init)
        XCTAssertEqual(lines, ["첫 줄", "둘째 줄"])
    }

    func testTagsAreRemoved() {
        let xml = "<a><b>text</b> <c>more</c></a>"
        let out = XMLTextStripper.plainText(from: xml)
        XCTAssertFalse(out.contains("<"))
        XCTAssertFalse(out.contains(">"))
        XCTAssertTrue(out.contains("text"))
        XCTAssertTrue(out.contains("more"))
    }

    func testNamedEntityDecode() {
        let xml = "<t>a &amp; b &lt; c &gt; d &quot;e&quot;</t>"
        let out = XMLTextStripper.plainText(from: xml)
        XCTAssertTrue(out.contains("a & b < c > d \"e\""))
    }

    func testNumericEntityDecode() {
        // &#65; = A, &#x42; = B
        let xml = "<t>&#65;&#x42;</t>"
        let out = XMLTextStripper.plainText(from: xml)
        XCTAssertTrue(out.contains("AB"))
    }

    func testWhitespaceCollapsing() {
        let xml = "<t>a     b</t>"
        let out = XMLTextStripper.plainText(from: xml)
        XCTAssertFalse(out.contains("  "))   // 연속 공백 없음
    }

    func testEmptyInput() {
        XCTAssertEqual(XMLTextStripper.plainText(from: ""), "")
    }

    func testTableRowBreaks() {
        let xml = "<w:tr><w:t>r1</w:t></w:tr><w:tr><w:t>r2</w:t></w:tr>"
        let out = XMLTextStripper.plainText(from: xml)
        XCTAssertTrue(out.contains("r1"))
        XCTAssertTrue(out.contains("r2"))
        XCTAssertTrue(out.contains("\n"))
    }
}
