import XCTest
@testable import AllDoc

final class TextExtractorTests: XCTestCase {
    private func writeTemp(_ content: String, ext: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("alldoc-extract-\(UUID().uuidString).\(ext)")
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func testExtractPlainTxt() async throws {
        let url = try writeTemp("hello\nworld", ext: "txt")
        defer { try? FileManager.default.removeItem(at: url) }
        let text = await TextExtractor.extractText(from: url)
        XCTAssertEqual(text, "hello\nworld")
    }

    func testExtractMarkdown() async throws {
        let url = try writeTemp("# Title\n\nbody text", ext: "md")
        defer { try? FileManager.default.removeItem(at: url) }
        let text = await TextExtractor.extractText(from: url)
        XCTAssertEqual(text, "# Title\n\nbody text")
    }

    func testExtractCSV() async throws {
        let url = try writeTemp("a,b,c\n1,2,3", ext: "csv")
        defer { try? FileManager.default.removeItem(at: url) }
        let text = await TextExtractor.extractText(from: url)
        XCTAssertTrue(text?.contains("a,b,c") ?? false)
    }

    func testExtractKoreanText() async throws {
        let url = try writeTemp("한글 본문 내용", ext: "txt")
        defer { try? FileManager.default.removeItem(at: url) }
        let text = await TextExtractor.extractText(from: url)
        XCTAssertEqual(text, "한글 본문 내용")
    }

    func testUnsupportedExtensionReturnsNil() async throws {
        let url = try writeTemp("binary-ish", ext: "bin")
        defer { try? FileManager.default.removeItem(at: url) }
        let text = await TextExtractor.extractText(from: url)
        XCTAssertNil(text)
    }

    func testLegacyDocReturnsNil() async throws {
        // .doc 는 본문 추출 비지원(canExtractContent=false) → nil.
        let url = try writeTemp("not really a doc", ext: "doc")
        defer { try? FileManager.default.removeItem(at: url) }
        let text = await TextExtractor.extractText(from: url)
        XCTAssertNil(text)
    }
}
