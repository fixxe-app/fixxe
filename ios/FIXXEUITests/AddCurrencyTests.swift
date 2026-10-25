import XCTest

/// Валюта, которой нет у текущего источника (ETH у ExchangeRate-API):
/// приложение предлагает переключить источник и добавить её. На iPhone
/// кнопка «Switch source and add» ничего не делала — алерт обнулял
/// выбранную валюту раньше, чем кнопка успевала её прочитать.
final class AddCurrencyTests: XCTestCase {

    func testSwitchSourceAndAddActuallyAdds() {
        let app = XCUIApplication()
        app.launchArguments += ["-screen-currencies", "EUR,USD,RSD",
                                "-screen-source", "1",            // ExchangeRate-API: ETH там нет
                                "-screen-add", "-screen-query", "ETH"]
        app.launch()

        let eth = app.descendants(matching: .any).matching(identifier: "add-ETH").firstMatch
        XCTAssertTrue(eth.waitForExistence(timeout: 20), "в списке добавления нет ETH")
        eth.tap()

        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "не спросили про смену источника")
        // кнопка подтверждения — не «Back»
        let confirm = alert.buttons.allElementsBoundByIndex.first { $0.label != "Back" }!
        confirm.tap()

        let row = app.descendants(matching: .any).matching(identifier: "amount-ETH").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 20),
                      "после «\(confirm.label)» ETH так и не появилась в списке")
        let status = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'F.A.'")).firstMatch
        XCTAssertTrue(status.waitForExistence(timeout: 20), "источник не переключился на F.A.")
    }
}
