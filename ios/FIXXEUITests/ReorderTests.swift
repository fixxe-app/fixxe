import XCTest

/// Порядок валют меняется перетаскиванием за ручку справа, без режима
/// редактирования. Тест не зависит от того, в каком порядке строки лежат
/// сейчас: порядок сохраняется между запусками.
final class ReorderTests: XCTestCase {

    private func handle(_ app: XCUIApplication, _ code: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "drag-\(code)").firstMatch
    }

    /// коды строк сверху вниз
    private func order(_ app: XCUIApplication) -> [String] {
        ["EUR","USD","RSD","GEL","ILS","TJS","CHF"]
            .map { ($0, handle(app, $0)) }
            .filter { $0.1.exists }
            .sorted { $0.1.frame.midY < $1.1.frame.midY }
            .map { $0.0 }
    }

    func testDragReordersWithoutEditMode() {
        let app = XCUIApplication()
        // свой список: тест удаления в TapInteractionTests убирает USD, и это
        // сохраняется — без него тест зависел бы от прошлого прогона
        app.launchArguments += ["-screen-currencies", "EUR,USD,RSD,GEL,ILS,TJS,CHF"]
        app.launch()

        let usd = handle(app, "USD")
        let rsd = handle(app, "RSD")
        XCTAssertTrue(usd.waitForExistence(timeout: 20), "список не загрузился")
        XCTAssertTrue(rsd.exists, "нет строки RSD")

        let usdWasAbove = usd.frame.midY < rsd.frame.midY
        let (top, bottom) = usdWasAbove ? (usd, rsd) : (rsd, usd)

        // drag & drop требует медленного жеста с удержанием в конце,
        // иначе система не успевает принять drop
        let start = top.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = bottom.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 1.2, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 1.0)
        Thread.sleep(forTimeInterval: 2)

        let usdNowAbove = handle(app, "USD").frame.midY < handle(app, "RSD").frame.midY
        XCTAssertNotEqual(usdWasAbove, usdNowAbove,
                          "после перетаскивания строки должны были поменяться местами")

        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.lifetime = .keepAlways; shot.name = "after-drag"; add(shot)
    }
}
