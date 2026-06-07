import XCTest
@testable import AllDoc

final class DocTypeTests: XCTestCase {
    func testFromExtensionMapping() {
        XCTAssertEqual(DocType.from(extension: "pdf"), .pdf)
        XCTAssertEqual(DocType.from(extension: "docx"), .word)
        XCTAssertEqual(DocType.from(extension: "doc"), .word)
        XCTAssertEqual(DocType.from(extension: "pptx"), .powerpoint)
        XCTAssertEqual(DocType.from(extension: "xlsx"), .excel)
        XCTAssertEqual(DocType.from(extension: "hwpx"), .hangul)
        XCTAssertEqual(DocType.from(extension: "md"), .markdown)
        XCTAssertEqual(DocType.from(extension: "markdown"), .markdown)
        XCTAssertEqual(DocType.from(extension: "txt"), .text)
        XCTAssertEqual(DocType.from(extension: "csv"), .csv)
        XCTAssertEqual(DocType.from(extension: "rtf"), .rtf)
    }

    func testFromExtensionIsCaseInsensitive() {
        XCTAssertEqual(DocType.from(extension: "PDF"), .pdf)
        XCTAssertEqual(DocType.from(extension: "DocX"), .word)
    }

    func testFromUnknownExtensionIsNil() {
        XCTAssertNil(DocType.from(extension: "exe"))
        XCTAssertNil(DocType.from(extension: ""))
        XCTAssertNil(DocType.from(extension: "zip"))
    }

    func testAllExtensionsContainsKnown() {
        let all = Set(DocType.allExtensions)
        for ext in ["pdf", "docx", "pptx", "xlsx", "hwpx", "md", "txt", "csv", "rtf"] {
            XCTAssertTrue(all.contains(ext), "allExtensions 에 \(ext) 누락")
        }
    }

    func testAllExtensionsAreLowercase() {
        for ext in DocType.allExtensions {
            XCTAssertEqual(ext, ext.lowercased())
        }
    }

    func testCanExtractContentForModernFormats() {
        XCTAssertTrue(DocType.canExtractContent(extension: "pdf"))
        XCTAssertTrue(DocType.canExtractContent(extension: "docx"))
        XCTAssertTrue(DocType.canExtractContent(extension: "md"))
        XCTAssertTrue(DocType.canExtractContent(extension: "txt"))
    }

    func testCanExtractContentFalseForLegacyBinary() {
        XCTAssertFalse(DocType.canExtractContent(extension: "doc"))
        XCTAssertFalse(DocType.canExtractContent(extension: "ppt"))
        XCTAssertFalse(DocType.canExtractContent(extension: "xls"))
        XCTAssertFalse(DocType.canExtractContent(extension: "hwp"))
    }

    func testCanExtractContentFalseForUnknown() {
        XCTAssertFalse(DocType.canExtractContent(extension: "exe"))
    }

    func testDisplayNameAndExtensionsNonEmpty() {
        for type in DocType.allCases {
            XCTAssertFalse(type.displayName.isEmpty)
            XCTAssertFalse(type.fileExtensions.isEmpty)
            XCTAssertFalse(type.symbol.isEmpty)
        }
    }
}
