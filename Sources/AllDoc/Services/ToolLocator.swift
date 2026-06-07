import Foundation

/// fd / rg / fzf / unzip / pdftotext 실행 파일 경로를 찾아둔다.
struct ToolLocator {
    let fd: String?
    let rg: String?
    let fzf: String?
    let unzip: String?
    let pdftotext: String?

    static let shared = ToolLocator.locate()

    static func locate() -> ToolLocator {
        ToolLocator(
            fd: find(["fd", "fdfind"]),
            rg: find(["rg"]),
            fzf: find(["fzf"]),
            unzip: find(["unzip"]),
            pdftotext: find(["pdftotext"])
        )
    }

    private static let searchDirs = [
        "/opt/homebrew/bin",
        "/opt/zerobrew/prefix/bin",
        "/usr/local/bin",
        "/usr/bin",
        "/bin",
    ]

    private static func find(_ names: [String]) -> String? {
        for name in names {
            for dir in searchDirs {
                let path = "\(dir)/\(name)"
                if FileManager.default.isExecutableFile(atPath: path) {
                    return path
                }
            }
        }
        return nil
    }

    var missingRequired: [String] {
        var missing: [String] = []
        if fd == nil { missing.append("fd") }
        if fzf == nil { missing.append("fzf") }   // 본문검색은 SQLite FTS5 사용(rg 불필요)
        return missing
    }
}
