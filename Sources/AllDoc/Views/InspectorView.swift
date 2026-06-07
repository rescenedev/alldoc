import SwiftUI

struct InspectorView: View {
    @EnvironmentObject var store: DocStore
    @State private var matchLines: [String] = []
    @State private var selectedMatch: Int?

    var body: some View {
        Group {
            if let file = store.selectedFile {
                detail(for: file)
            } else {
                placeholder
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBG)
    }

    private var placeholder: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.tertiary)
            Text("항목을 선택하면\n미리보기가 표시됩니다")
                .font(.system(size: 12))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private static let textExts: Set<String> = ["txt", "text", "log", "md", "markdown", "mdown", "csv", "tsv"]
    // 서식을 그대로 파싱·렌더링하는 형식(NSAttributedString) — 흰 페이지 + 하이라이트.
    private static let richExts: Set<String> = ["docx", "doc", "rtf", "rtfd", "odt", "html", "htm"]
    // 서식 파서가 없는 형식 — 추출 본문을 텍스트 미리보기로(하이라이트 가능).
    private static let officeTextExts: Set<String> = ["pptx", "ppt", "xlsx", "xls", "hwpx", "hwp"]
    private func usesTextPreview(_ ext: String) -> Bool {
        Self.textExts.contains(ext) || Self.officeTextExts.contains(ext)
    }

    private func detail(for file: DocFile) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 미리보기 — 텍스트 문서는 SwiftUI 본문 뷰(하이라이트·스크롤), 그 외는 썸네일.
            Group {
                if file.isDirectory {
                    folderPreview(file)
                } else if file.ext == "pdf" {
                    PDFPreview(url: file.url, query: store.searchText)
                } else if Self.richExts.contains(file.ext) {
                    // docx 등: 서식 유지 + 폭 맞춤 + 검색어 하이라이트.
                    RichDocPreview(url: file.url, query: store.searchText)
                } else if usesTextPreview(file.ext) {
                    // 텍스트·오피스 문서: 추출 본문을 폭 가득 렌더링 + 검색어 하이라이트 + 일치 줄 스크롤.
                    TextMatchPreview(path: file.url.path, query: store.searchText, selectedMatch: $selectedMatch)
                } else {
                    // 이미지 등 본문이 없는 형식은 네이티브 Quick Look 으로 가득 채워 표시.
                    QuickLookView(url: file.url)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 200, maxHeight: .infinity)

            Divider()

            // 하단: 본문 일치(위) → 파일 정보(아래) → 열기.
            // 내용만큼만 차지(고정 높이 X) → 빈 공간 없이 미리보기가 위쪽을 채움.
            VStack(alignment: .leading, spacing: 14) {
                header(file)
                if !matchLines.isEmpty {
                    snippetsSection(matchLines)
                }
                metadata(file)
                actions(file)
            }
            .padding(16)
        }
        .task(id: "\(file.url.path)|\(store.searchText)") {
            selectedMatch = nil
            let q = store.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            if q.isEmpty {
                matchLines = file.snippets.map { $0.text }
            } else {
                let lines = DocIndex.shared.matchLines(path: file.url.path, query: q, limit: 25)
                matchLines = lines.isEmpty ? file.snippets.map { $0.text } : lines
            }
        }
    }

    private func folderPreview(_ file: DocFile) -> some View {
        VStack {
            Image(systemName: "folder.fill")
                .font(.system(size: 72))
                .foregroundStyle(Color.accentColor)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func header(_ file: DocFile) -> some View {
        HStack(spacing: 10) {
            FileIcon(url: file.url, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(2)
                if let type = file.docType {
                    Text(type.displayName)
                        .font(.system(size: 11))
                        .foregroundStyle(type.tint)
                } else if file.isDirectory {
                    Text("폴더").font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func metadata(_ file: DocFile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            metaRow("크기", file.isDirectory ? "--" : Formatters.size(file.size))
            metaRow("수정일", Formatters.dateAbsolute(file.modified))
            metaRow("생성일", Formatters.dateAbsolute(file.created))
            metaRow("위치", file.url.deletingLastPathComponent().path)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appElevated, in: RoundedRectangle(cornerRadius: 8))
    }

    private func metaRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .leading)
            Text(value)
                .font(.system(size: 11))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func snippetsSection(_ lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("본문 일치 \(lines.count)곳", systemImage: "text.quote")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            // 줄이 많으면 내부 스크롤(고정 높이)로 묶어 하단 정보 영역 높이를 안정화.
            if lines.count > 6 {
                ScrollView { snippetRows(lines) }.frame(height: 200)
            } else {
                snippetRows(lines)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appElevated, in: RoundedRectangle(cornerRadius: 8))
    }

    private func snippetRows(_ lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(lines.enumerated()), id: \.offset) { idx, line in
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "text.quote")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .frame(width: 16, alignment: .trailing)
                    Highlighter.text(line)
                        .font(.system(size: 11))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 3)
                .padding(.horizontal, 6)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(selectedMatch == idx ? Color.accentColor.opacity(0.30) : .clear)
                )
                .contentShape(Rectangle())
                .onTapGesture { selectedMatch = (selectedMatch == idx ? nil : idx) }
            }
        }
    }

    private func actions(_ file: DocFile) -> some View {
        HStack(spacing: 8) {
            Button {
                store.open(file)
            } label: {
                Label(file.isDirectory ? "열기" : "기본 앱으로 열기",
                      systemImage: file.isDirectory ? "folder" : "arrow.up.forward.app")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            Button {
                store.revealInFinder(file)
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .controlSize(.large)
            .help("Finder에서 보기")
        }
    }
}
