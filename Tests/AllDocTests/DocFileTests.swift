import XCTest
@testable import AllDoc

final class DocFileTests: XCTestCase {
    func testNameAndExt() {
        let f = DocFile(url: URL(fileURLWithPath: "/tmp/Report.PDF"), isDirectory: false)
        XCTAssertEqual(f.name, "Report.PDF")
        XCTAssertEqual(f.ext, "pdf")   // 소문자
        XCTAssertEqual(f.id, f.url)
    }

    func testDocTypeForFile() {
        let f = DocFile(url: URL(fileURLWithPath: "/tmp/a.docx"), isDirectory: false)
        XCTAssertEqual(f.docType, .word)
        XCTAssertTrue(f.isSupportedDocument)
    }

    func testDirectoryHasNoDocType() {
        let d = DocFile(url: URL(fileURLWithPath: "/tmp/folder"), isDirectory: true)
        XCTAssertNil(d.docType)
        XCTAssertFalse(d.isSupportedDocument)
    }

    func testUnknownExtensionNotSupported() {
        let f = DocFile(url: URL(fileURLWithPath: "/tmp/a.bin"), isDirectory: false)
        XCTAssertNil(f.docType)
        XCTAssertFalse(f.isSupportedDocument)
    }

    func testReadFromRealFile() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("alldoc-docfile-\(UUID().uuidString).txt")
        try "hello".write(to: tmp, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let f = try XCTUnwrap(DocFile.read(from: tmp))
        XCTAssertFalse(f.isDirectory)
        XCTAssertEqual(f.ext, "txt")
        XCTAssertEqual(f.docType, .text)
        XCTAssertGreaterThan(f.size, 0)
        XCTAssertGreaterThan(f.modified, .distantPast)
    }

    func testReadFromMissingFileIsNil() {
        let missing = URL(fileURLWithPath: "/tmp/does-not-exist-\(UUID().uuidString).txt")
        XCTAssertNil(DocFile.read(from: missing))
    }
}
