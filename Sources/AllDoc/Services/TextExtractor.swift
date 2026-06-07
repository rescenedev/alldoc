import Foundation
import PDFKit
import AppKit

/// 문서에서 평문 텍스트를 추출한다(저장은 DocIndex 가 담당). 상태 없는 추출기.
enum TextExtractor {
    /// 거대한 PDF 의 최악 비용 제한.
    private static let maxPDFPages = 150

    /// 종류별 본문 텍스트 추출.
    static func extractText(from url: URL) async -> String? {
        let ext = url.pathExtension.lowercased()
        guard DocType.canExtractContent(extension: ext) else { return nil }

        switch ext {
        case "txt", "text", "log", "md", "markdown", "mdown", "csv", "tsv":
            return readPlainText(url)
        case "pdf":
            return extractPDF(url)
        case "rtf":
            return extractRTF(url)
        case "docx":
            return await extractZipXML(url, members: ["word/document.xml",
                                                      "word/footnotes.xml",
                                                      "word/endnotes.xml"])
        case "pptx":
            return await extractZipXML(url, members: ["ppt/slides/slide*.xml",
                                                      "ppt/notesSlides/notesSlide*.xml"])
        case "xlsx":
            return await extractZipXML(url, members: ["xl/sharedStrings.xml",
                                                      "xl/worksheets/sheet*.xml"])
        case "hwpx":
            return await extractZipXML(url, members: ["Contents/section*.xml"])
        default:
            return nil
        }
    }

    // MARK: - 종류별 구현

    private static func readPlainText(_ url: URL) -> String? {
        if let s = try? String(contentsOf: url, encoding: .utf8) { return s }
        var used: String.Encoding = .utf8
        if let s = try? String(contentsOf: url, usedEncoding: &used) { return s }
        if let data = try? Data(contentsOf: url) {
            return String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
        }
        return nil
    }

    private static func extractPDF(_ url: URL) -> String? {
        if let s = extractPDFViaCLI(url), !s.isEmpty { return s }
        guard let doc = PDFDocument(url: url) else { return nil }
        return doc.string
    }

    private static func extractPDFViaCLI(_ url: URL) -> String? {
        guard let pdftotext = ToolLocator.shared.pdftotext else { return nil }
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathExtension("txt")
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: pdftotext)
        proc.arguments = ["-q", "-l", "\(maxPDFPages)", url.path, tmp.path]
        do { try proc.run() } catch { return nil }
        proc.waitUntilExit()
        defer { try? FileManager.default.removeItem(at: tmp) }
        return try? String(contentsOf: tmp, encoding: .utf8)
    }

    private static func extractRTF(_ url: URL) -> String? {
        guard let data = try? Data(contentsOf: url),
              let attr = try? NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
              ) else { return readPlainText(url) }
        return attr.string
    }

    private static func extractZipXML(_ url: URL, members: [String]) async -> String? {
        guard let unzip = ToolLocator.shared.unzip else { return nil }
        var combined = ""
        for member in members {
            guard let result = try? await ProcessRunner.run(unzip, arguments: ["-p", url.path, member]),
                  result.exitCode == 0 || !result.stdout.isEmpty else { continue }
            let xml = result.stdoutString
            if !xml.isEmpty {
                combined += XMLTextStripper.plainText(from: xml)
                combined += "\n"
            }
        }
        return combined.isEmpty ? nil : combined
    }
}
