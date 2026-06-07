import XCTest
@testable import AllDoc

final class FormattersTests: XCTestCase {
    func testSizeZeroIsDash() {
        XCTAssertEqual(Formatters.size(0), "--")
    }

    func testSizeNegativeIsDash() {
        XCTAssertEqual(Formatters.size(-100), "--")
    }

    func testSizePositiveIsNonEmpty() {
        let s = Formatters.size(2048)
        XCTAssertFalse(s.isEmpty)
        XCTAssertNotEqual(s, "--")
        // 바이트 카운트 포맷이면 숫자를 포함한다.
        XCTAssertTrue(s.rangeOfCharacter(from: .decimalDigits) != nil)
    }

    func testDateRelativeDistantPastIsDash() {
        XCTAssertEqual(Formatters.dateRelative(.distantPast), "--")
    }

    func testDateAbsoluteDistantPastIsDash() {
        XCTAssertEqual(Formatters.dateAbsolute(.distantPast), "--")
    }

    func testDateRelativeRealDateIsNotDash() {
        let s = Formatters.dateRelative(Date(timeIntervalSinceNow: -3600))
        XCTAssertNotEqual(s, "--")
        XCTAssertFalse(s.isEmpty)
    }

    func testDateAbsoluteRealDateIsNotDash() {
        let s = Formatters.dateAbsolute(Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertNotEqual(s, "--")
        XCTAssertFalse(s.isEmpty)
    }
}
