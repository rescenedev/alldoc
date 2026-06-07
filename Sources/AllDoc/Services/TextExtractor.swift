import Foundation
import CryptoKit
import PDFKit
import AppKit

/// 문서에서 평문 텍스트를 추출하고, 추출 결과를 캐시(그림자 .txt)로 보관한다.
/// 본문 검색은 이 캐시 폴더를 ripgrep 으로 훑어서 동작한다.
///
/// 중요: 액터가 아니라 락으로 인덱스만 보호하는 클래스다. 추출(서브프로세스 호출)이
/// 직렬화되지 않고 **진짜 병렬**로 실행되도록 하기 위함.
final class TextExtractor: @unchecked Sendable {
    static let shared = TextExtractor()

    /// 그림자 텍스트 파일이 쌓이는 캐시 폴더.
    let cacheDir: URL

    /// 거대한 PDF 의 최악 비용을 제한 (앞에서부터 이 페이지 수까지만 추출).
    private let maxPDFPages = 150

    private let indexURL: URL
    private let lock = NSLock()
    private var index: [String: ShadowEntry] = [:]   // sha → 원본 정보
    private var dirty = false
    private var lastFlush = Date.distantPast

    struct ShadowEntry: Codable {
        let path: String
        let mtime: Double
        let size: Int64
    }

    init() {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("AllDoc", isDirectory: true)
        cacheDir = base.appendingPathComponent("textcache", isDirectory: true)
        indexURL = base.appendingPathComponent("index.json")
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)

        // 캐시 포맷 버전. 바뀌면 기존 캐시를 비운다.
        let versionURL = base.appendingPathComponent("cache-version")
        let currentVersion = "3-nfd-class"
        let storedVersion = (try? String(contentsOf: versionURL, encoding: .utf8)) ?? ""
        if storedVersion != currentVersion {
            try? FileManager.default.removeItem(at: cacheDir)
            try? FileManager.default.removeItem(at: indexURL)
            try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
            try? currentVersion.write(to: versionURL, atomically: true, encoding: .utf8)
        }

        if let data = try? Data(contentsOf: indexURL),
           let decoded = try? JSONDecoder().decode([String: ShadowEntry].self, from: data) {
            index = decoded
        }
    }

    // MARK: - 인덱스 (락 보호)

    private func getEntry(_ key: String) -> ShadowEntry? {
        lock.lock(); defer { lock.unlock() }
        return index[key]
    }

    private func putEntry(_ key: String, _ entry: ShadowEntry) {
        lock.lock(); index[key] = entry; dirty = true; lock.unlock()
    }

    func originalPath(forShadow sha: String) -> String? {
        lock.lock(); defer { lock.unlock() }
        return index[sha]?.path
    }

    /// 변경된 인덱스를 디스크에 기록. 잦은 호출 시 2초 간격으로 합쳐(coalesce) 전체-재기록 비용을 줄인다.
    /// `force: true` 면 즉시 기록(작업 종료 시점에 사용).
    func flush(force: Bool = false) {
        lock.lock()
        guard dirty else { lock.unlock(); return }
        if !force, Date().timeIntervalSince(lastFlush) < 2.0 { lock.unlock(); return }
        let snapshot = index
        dirty = false
        lastFlush = Date()
        lock.unlock()
        if let data = try? JSONEncoder().encode(snapshot) {
            try? data.write(to: indexURL)
        }
    }

    // MARK: - 추출 / 캐시 보장

    private func sha(for url: URL) -> String {
        let digest = SHA256.hash(data: Data(url.path.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func shadowURL(for sha: String) -> URL {
        cacheDir.appendingPathComponent(sha).appendingPathExtension("txt")
    }

    /// 원본을 추출해 그림자 파일을 최신 상태로 보장하고 그림자 URL 반환. 실패 시 nil.
    func ensureExtracted(_ url: URL, mtime: Date, size: Int64) async -> URL? {
        let key = sha(for: url)
        let shadow = shadowURL(for: key)
        let stamp = mtime.timeIntervalSinceReferenceDate

        if let entry = getEntry(key),
           entry.mtime == stamp, entry.size == size,
           FileManager.default.fileExists(atPath: shadow.path) {
            return shadow   // 캐시 적중
        }

        guard let text = await extractText(from: url) else { return nil }
        let normalized = text.decomposedStringWithCanonicalMapping   // 질의(NFD)와 매칭되도록
        do {
            try normalized.write(to: shadow, atomically: true, encoding: .utf8)
            putEntry(key, ShadowEntry(path: url.path, mtime: stamp, size: size))
            return shadow
        } catch {
            return nil
        }
    }

    /// 종류별 본문 텍스트 추출.
    func extractText(from url: URL) async -> String? {
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

    private func readPlainText(_ url: URL) -> String? {
        if let s = try? String(contentsOf: url, encoding: .utf8) { return s }
        var used: String.Encoding = .utf8
        if let s = try? String(contentsOf: url, usedEncoding: &used) { return s }
        if let data = try? Data(contentsOf: url) {
            return String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .isoLatin1)
        }
        return nil
    }

    private func extractPDF(_ url: URL) -> String? {
        // pdftotext(poppler)이 PDFKit 보다 훨씬 빠르다 — 있으면 우선 사용.
        if let s = extractPDFViaCLI(url), !s.isEmpty { return s }
        guard let doc = PDFDocument(url: url) else { return nil }
        return doc.string
    }

    private func extractPDFViaCLI(_ url: URL) -> String? {
        guard let pdftotext = ToolLocator.shared.pdftotext else { return nil }
        let tmp = cacheDir.appendingPathComponent(UUID().uuidString).appendingPathExtension("txt")
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: pdftotext)
        proc.arguments = ["-q", "-l", "\(maxPDFPages)", url.path, tmp.path]
        do { try proc.run() } catch { return nil }
        proc.waitUntilExit()
        defer { try? FileManager.default.removeItem(at: tmp) }
        return try? String(contentsOf: tmp, encoding: .utf8)
    }

    private func extractRTF(_ url: URL) -> String? {
        guard let data = try? Data(contentsOf: url),
              let attr = try? NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
              ) else { return readPlainText(url) }
        return attr.string
    }

    /// zip 기반 문서에서 지정 멤버 XML 들을 unzip 으로 꺼내 태그를 제거.
    private func extractZipXML(_ url: URL, members: [String]) async -> String? {
        guard let unzip = ToolLocator.shared.unzip else { return nil }
        var combined = ""
        for member in members {
            guard let result = try? await ProcessRunner.run(
                unzip, arguments: ["-p", url.path, member]
            ), result.exitCode == 0 || !result.stdout.isEmpty else { continue }
            let xml = result.stdoutString
            if !xml.isEmpty {
                combined += XMLTextStripper.plainText(from: xml)
                combined += "\n"
            }
        }
        return combined.isEmpty ? nil : combined
    }
}
