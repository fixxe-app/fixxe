import XCTest
@testable import FIXXE

/// Просьба об оценке: не раньше 50-го открытия и 14 дней, второй раз — втрое позже, не больше двух.
/// Те же случаи — в app/src/test/.../ui/ReviewAskTest.kt.
final class ReviewAskTests: XCTestCase {
    private let min = 60.0, day = 86400.0, t0 = 1_800_000_000.0

    /// `n` открытий раз в `every` начиная с `from`; между ними приложение уходит с экрана.
    private func visits(_ s0: ReviewAsk.State, _ n: Int, from: Double, every: Double) -> (ReviewAsk.State, Double) {
        var s = s0, now = from, left = 0.0
        for _ in 0..<n { s = ReviewAsk.opened(s, now: now, leftAt: left); left = now + min; now += every }
        return (s, now - every)
    }

    func testFirstOpenStartsTheClock() {
        let s = ReviewAsk.opened(.init(), now: t0, leftAt: 0)
        XCTAssertEqual(s.opens, 1); XCTAssertEqual(s.firstAt, t0)
    }

    func testQuickSwitchIsNotANewOpen() {
        var s = ReviewAsk.opened(.init(), now: t0, leftAt: 0)
        s = ReviewAsk.opened(s, now: t0 + 10 * min, leftAt: t0 + 5 * min)
        XCTAssertEqual(s.opens, 1)
        s = ReviewAsk.opened(s, now: t0 + 60 * min, leftAt: t0 + 20 * min)
        XCTAssertEqual(s.opens, 2)
    }

    func testNotBefore50Opens() {
        let (s, now) = visits(.init(), 49, from: t0, every: day)
        XCTAssertFalse(ReviewAsk.due(s, now: now))
        XCTAssertTrue(ReviewAsk.due(ReviewAsk.opened(s, now: now + day, leftAt: now + min), now: now + day))
    }

    func testNotBefore14Days() {
        let (s, now) = visits(.init(), 60, from: t0, every: 4 * 60 * min)
        XCTAssertFalse(ReviewAsk.due(s, now: now))
        XCTAssertTrue(ReviewAsk.due(s, now: t0 + 14 * day))
    }

    func testSecondTimeOnlyThreeTimesLaterAndAfter100MoreOpens() {
        let (s1, now1) = visits(.init(), 50, from: t0, every: day)
        XCTAssertTrue(ReviewAsk.due(s1, now: now1))
        let a = ReviewAsk.asked(s1, now: now1)
        XCTAssertFalse(ReviewAsk.due(a, now: now1), "сразу после просьбы — нет")
        let (s2, _) = visits(a, 100, from: now1 + day, every: 6 * 60 * min)
        XCTAssertFalse(ReviewAsk.due(s2, now: now1 + 41 * day), "100 открытий есть, а 42 дней нет")
        XCTAssertTrue(ReviewAsk.due(s2, now: now1 + 42 * day))
        let (s3, _) = visits(a, 99, from: now1 + day, every: day)
        XCTAssertFalse(ReviewAsk.due(s3, now: now1 + 100 * day), "42 дня прошло, а 100 открытий нет")
    }

    func testNeverMoreThanTwice() {
        var s = ReviewAsk.State(opens: 50, firstAt: t0)
        s = ReviewAsk.asked(s, now: t0 + 20 * day)
        s.opens = 200
        s = ReviewAsk.asked(s, now: t0 + 70 * day)
        s.opens = 10_000
        XCTAssertFalse(ReviewAsk.due(s, now: t0 + 3650 * day))
    }
}
