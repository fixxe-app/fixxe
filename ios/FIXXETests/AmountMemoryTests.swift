import XCTest
@testable import FIXXE

/// Сколько помнить введённую сумму: 4 варианта из настроек — как на Android и в вебе.
final class AmountMemoryTests: XCTestCase {
    private let h: TimeInterval = 60 * 60
    private let now: TimeInterval = 1_000 * 24 * 60 * 60

    func testDefaultIs12Hours() { XCTAssertEqual(AmountMemory.defaultMode, AmountMemory.h12) }

    func testSessionNeverRestoresAfterLaunchAndNeverExpiresInMemory() {
        XCTAssertFalse(AmountMemory.restoreOnLaunch(mode: AmountMemory.session, leftAt: now - 1, now: now))
        XCTAssertFalse(AmountMemory.expired(mode: AmountMemory.session, leftAt: now - 100 * 24 * h, now: now))
    }

    func testTwelveHours() {
        XCTAssertTrue(AmountMemory.restoreOnLaunch(mode: AmountMemory.h12, leftAt: now - 11 * h, now: now))
        XCTAssertFalse(AmountMemory.restoreOnLaunch(mode: AmountMemory.h12, leftAt: now - 13 * h, now: now))
        XCTAssertFalse(AmountMemory.expired(mode: AmountMemory.h12, leftAt: now - 11 * h, now: now))
        XCTAssertTrue(AmountMemory.expired(mode: AmountMemory.h12, leftAt: now - 13 * h, now: now))
    }

    func testTwentyFourHours() {
        XCTAssertTrue(AmountMemory.restoreOnLaunch(mode: AmountMemory.h24, leftAt: now - 23 * h, now: now))
        XCTAssertFalse(AmountMemory.restoreOnLaunch(mode: AmountMemory.h24, leftAt: now - 25 * h, now: now))
        XCTAssertTrue(AmountMemory.expired(mode: AmountMemory.h24, leftAt: now - 25 * h, now: now))
    }

    func testForeverRestoresAfterMonthsAndNeverExpires() {
        XCTAssertTrue(AmountMemory.restoreOnLaunch(mode: AmountMemory.forever, leftAt: now - 90 * 24 * h, now: now))
        XCTAssertFalse(AmountMemory.expired(mode: AmountMemory.forever, leftAt: now - 90 * 24 * h, now: now))
    }

    func testNeverLeftOrClockWentBackMeansFreshStart() {
        XCTAssertFalse(AmountMemory.restoreOnLaunch(mode: AmountMemory.h12, leftAt: 0, now: now))
        XCTAssertTrue(AmountMemory.expired(mode: AmountMemory.h24, leftAt: now + h, now: now))
    }
}
