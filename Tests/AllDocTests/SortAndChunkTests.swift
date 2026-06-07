import XCTest
@testable import AllDoc

final class SortAndChunkTests: XCTestCase {
    private func file(_ path: String, size: Int64 = 0, modified: Date = .distantPast) -> DocFile {
        DocFile(url: URL(fileURLWithPath: path), isDirectory: false, size: size, modified: modified)
    }

    func testSortByNameAscendingNumericAware() {
        let files = [file("/t/file10.txt"), file("/t/file2.txt"), file("/t/file1.txt")]
        let sorted = DocStore.sortFiles(files, key: .name, ascending: true)
        XCTAssertEqual(sorted.map(\.name), ["file1.txt", "file2.txt", "file10.txt"])
    }

    func testSortByNameDescending() {
        let files = [file("/t/a.txt"), file("/t/c.txt"), file("/t/b.txt")]
        let sorted = DocStore.sortFiles(files, key: .name, ascending: false)
        XCTAssertEqual(sorted.map(\.name), ["c.txt", "b.txt", "a.txt"])
    }

    func testSortBySizeDescending() {
        let files = [file("/t/a", size: 10), file("/t/b", size: 300), file("/t/c", size: 50)]
        let sorted = DocStore.sortFiles(files, key: .size, ascending: false)
        XCTAssertEqual(sorted.map(\.size), [300, 50, 10])
    }

    func testSortByModifiedAscending() {
        let now = Date()
        let files = [
            file("/t/a", modified: now),
            file("/t/b", modified: now.addingTimeInterval(-1000)),
            file("/t/c", modified: now.addingTimeInterval(-500)),
        ]
        let sorted = DocStore.sortFiles(files, key: .modified, ascending: true)
        XCTAssertEqual(sorted.map(\.name), ["b", "c", "a"])
    }

    func testSortByKindGroups() {
        let files = [file("/t/z.pdf"), file("/t/a.txt"), file("/t/b.pdf")]
        let sorted = DocStore.sortFiles(files, key: .kind, ascending: true)
        // 같은 종류끼리 모이고, 동일 종류 내에서는 이름순.
        let kinds = sorted.map { $0.docType?.displayName ?? "" }
        // 인접한 동일 종류 그룹이 깨지지 않아야 한다.
        var seen: Set<String> = []
        var prev = ""
        for k in kinds {
            if k != prev { XCTAssertFalse(seen.contains(k), "종류 그룹이 분리됨: \(k)"); seen.insert(prev) }
            prev = k
        }
    }

    func testSortStableCountPreserved() {
        let files = (0..<20).map { file("/t/\($0).txt", size: Int64($0)) }
        XCTAssertEqual(DocStore.sortFiles(files, key: .size, ascending: true).count, 20)
    }

    // MARK: - Array.chunked

    func testChunkedEvenSplit() {
        let r = [1, 2, 3, 4].chunked(into: 2)
        XCTAssertEqual(r, [[1, 2], [3, 4]])
    }

    func testChunkedRemainder() {
        let r = [1, 2, 3, 4, 5].chunked(into: 2)
        XCTAssertEqual(r, [[1, 2], [3, 4], [5]])
    }

    func testChunkedLargerThanCount() {
        XCTAssertEqual([1, 2].chunked(into: 10), [[1, 2]])
    }

    func testChunkedEmpty() {
        XCTAssertEqual([Int]().chunked(into: 3), [])
    }

    func testChunkedZeroSizeReturnsWhole() {
        XCTAssertEqual([1, 2, 3].chunked(into: 0), [[1, 2, 3]])
    }
}
