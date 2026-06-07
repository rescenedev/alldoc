import SwiftUI

struct InspectorView: View {
    @EnvironmentObject var store: DocStore

    var body: some View {
        Group {
            if let file = store.selectedFile {
                detail(for: file)
            } else {
                placeholder
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
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

    private func detail(for file: DocFile) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 미리보기
            Group {
                if file.isDirectory {
                    folderPreview(file)
                } else {
                    QuickLookPreview(url: file.url)
                        .id(file.url)
                }
            }
            .frame(height: 260)
            .frame(maxWidth: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header(file)
                    metadata(file)
                    if !file.snippets.isEmpty {
                        snippetsSection(file)
                    }
                    actions(file)
                }
                .padding(16)
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
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
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

    private func snippetsSection(_ file: DocFile) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("본문 일치", systemImage: "text.quote")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            ForEach(file.snippets) { snippet in
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "text.quote")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .frame(width: 16, alignment: .trailing)
                    Highlighter.text(snippet.text)
                        .font(.system(size: 11))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.yellow.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
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
