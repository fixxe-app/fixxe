import XCTest

/// Проверка вёрстки в ландшафте: для iPad Apple ожидает поддержку всех
/// ориентаций, а повернуть симулятор из командной строки нечем — simctl
/// этого не умеет. XCUIDevice умеет.
final class OrientationTests: XCTestCase {

    func testLandscapeKeepsHeaderAndFooterVisible() {
        let app = XCUIApplication()
        // свой список: тест удаления в TapInteractionTests убирает USD, и это
        // сохраняется — без него тест зависел бы от прошлого прогона
        app.launchArguments += ["-screen-currencies", "EUR,USD,RSD,GEL,ILS,TJS,CHF"]
        app.launch()
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }

        // даём время на перерисовку и на внешний screenshot
        Thread.sleep(forTimeInterval: 10)

        XCTAssertTrue(app.staticTexts["FIXXE"].exists, "шапка с названием пропала в ландшафте")
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'currency'")).firstMatch.exists,
                      "кнопка добавления валюты не видна в ландшафте")

        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.lifetime = .keepAlways
        shot.name = "landscape"
        add(shot)
    }
}
