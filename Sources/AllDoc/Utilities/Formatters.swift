import Foundation

enum Formatters {
    static let byteFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        f.allowsNonnumericFormatting = true
        return f
    }()

    static let relativeDate: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.unitsStyle = .abbreviated
        return f
    }()

    static let absoluteDate: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "yyyy. M. d. a h:mm"
        return f
    }()

    static func size(_ bytes: Int64) -> String {
        guard bytes > 0 else { return "--" }
        return byteFormatter.string(fromByteCount: bytes)
    }

    static func dateRelative(_ date: Date) -> String {
        guard date > .distantPast else { return "--" }
        return relativeDate.localizedString(for: date, relativeTo: Date())
    }

    static func dateAbsolute(_ date: Date) -> String {
        guard date > .distantPast else { return "--" }
        return absoluteDate.string(from: date)
    }
}
