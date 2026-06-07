import SwiftUI

/// 목록 보기의 한 줄 (문서 전용, 평탄 목록이라 위치를 함께 보여준다).
struct FileRowItem: View {
    @EnvironmentObject var store: DocStore
    let file: DocFile
    var isSelected: Bool = false

    private var nameColor: Color { isSelected ? .white : .primary }
    private var subColor: Color { isSelected ? Color.white.opacity(0.85) : .secondary }
    private var subColorDim: Color { isSelected ? Color.white.opacity(0.7) : Color(nsColor: .tertiaryLabelColor) }

    private var relativeLocation: String {
        let parent = file.url.deletingLastPathComponent().path
        // 파일을 포함하는 지정 폴더(루트)를 찾아 그 기준의 상대 경로를 보여준다.
        if let root = store.scopes
            .filter({ parent == $0.path || parent.hasPrefix($0.path + "/") })
            .max(by: { $0.path.count < $1.path.count }) {
            if parent == root.path { return root.lastPathComponent }
            let rel = String(parent.dropFirst(root.path.count))
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return rel.isEmpty ? root.lastPathComponent : "\(root.lastPathComponent)/\(rel)"
        }
        return (parent as NSString).lastPathComponent
    }

    var body: some View {
        HStack(spacing: 13) {
            FileIcon(url: file.url, size: 42)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(file.name)
                        .font(.system(size: 18))
                        .foregroundStyle(nameColor)
                        .lineLimit(1)
                    if store.isFavorite(file) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(isSelected ? Color.white : Color.yellow)
                    }
                }
                if let snippet = file.snippets.first {
                    HStack(spacing: 5) {
                        Image(systemName: "text.quote")
                            .font(.system(size: 11))
                            .foregroundStyle(subColorDim)
                        Highlighter.text(snippet.text)
                            .font(.system(size: 14))
                            .foregroundStyle(subColor)
                            .lineLimit(1)
                    }
                } else {
                    HStack(spacing: 5) {
                        Image(systemName: "folder")
                            .font(.system(size: 11))
                            .foregroundStyle(subColorDim)
                        Text(relativeLocation)
                            .font(.system(size: 14))
                            .foregroundStyle(subColorDim)
                            .lineLimit(1)
                            .truncationMode(.head)
                    }
                }
            }

            Spacer(minLength: 10)

            if let type = file.docType {
                Text(type.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isSelected ? Color.white : type.tint)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background((isSelected ? Color.white.opacity(0.22) : type.tint.opacity(0.12)), in: Capsule())
            }

            Text(Formatters.size(file.size))
                .font(.system(size: 14))
                .foregroundStyle(subColor)
                .frame(width: 92, alignment: .trailing)

            Text(Formatters.dateRelative(file.modified))
                .font(.system(size: 14))
                .foregroundStyle(subColor)
                .frame(width: 112, alignment: .trailing)
        }
        .frame(height: 52)   // 고정 행 높이 → 리사이즈 시 높이 재계산(떨림) 방지
    }
}
