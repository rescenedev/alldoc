import SwiftUI

/// 아이콘(그리드) 보기의 한 칸.
struct FileGridItem: View {
    let file: DocFile
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .bottomTrailing) {
                DocThumbnail(url: file.url, size: 64)
                    .shadow(color: .black.opacity(0.12), radius: 1, y: 1)
                if let type = file.docType {
                    Text(file.ext.uppercased())
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(type.tint, in: Capsule())
                        .offset(x: 4, y: 2)
                }
            }
            .frame(height: 66)

            Text(file.name)
                .font(.system(size: 11))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isSelected ? Color.accentColor : .clear)
                )
                .foregroundStyle(isSelected ? Color.white : Color.primary)

            if let snippet = file.snippets.first {
                Highlighter.text(snippet.text)
                    .font(.system(size: 9))
                    .lineLimit(2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 2)
            }
        }
        .frame(width: 126)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : .clear)
        )
        .contentShape(Rectangle())
    }
}
