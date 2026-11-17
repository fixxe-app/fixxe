import XCTest

/// Введённая сумма после закрытия приложения: по сроку из настроек
/// («Пока приложение открыто», 12 ч — по умолчанию, 24 ч, «Всегда»).
/// Запуски для тестов обычно начинают с 1 — здесь просим вернуть сумму (-keep-amount).
final class AmountMemoryUITests: XCTestCase {
    private let codes = "EUR,USD,RSD"

    override func setUp() { continueAfterFailure = false }

    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-screen-currencies", codes, "-keep-amount"] + extra
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["amount-EUR"].waitForExistence(timeout: 25), "список не появился")
        XCTAssertTrue(app.descendants(matching: .any)["rate-RSD"].waitForExistence(timeout: 25), "курсы не загрузились")
        return app
    }
    private func shown(_ app: XCUIApplication, _ c: String) -> String {
        let e = app.descendants(matching: .any).matching(identifier: "amount-\(c)").firstMatch
        return e.elementType == .textField ? (e.value as? String ?? "") : e.label
    }
    /// Свернуть (тут сумма записывается) и закрыть — как смахнуть из переключателя.
    private func close(_ app: XCUIApplication) {
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 1.5)
        app.terminate()
    }
    private func type50InUSD(_ app: XCUIApplication) {
        app.descendants(matching: .any)["amount-USD"].tap()
        let field = app.textFields["amount-USD"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.6)
        field.typeText("50")
        app.buttons["dismiss-keyboard-header"].tap()
        Thread.sleep(forTimeInterval: 0.6)
    }
    private func pickMemory(_ app: XCUIApplication, _ i: Int) {
        app.buttons["settings"].tap()
        XCTAssertTrue(app.buttons["set-memory"].waitForExistence(timeout: 5), "в настройках нет «Помнить сумму»")
        app.buttons["set-memory"].tap()
        XCTAssertTrue(app.buttons["memory-3"].waitForExistence(timeout: 5), "не открылся выбор срока")
        app.buttons["memory-\(i)"].tap()
        XCTAssertTrue(app.buttons["set-memory"].waitForExistence(timeout: 5), "после выбора не вернулись к настройкам")
    }

    /// По умолчанию (12 ч) сумма переживает закрытие; «Пока приложение открыто» — нет.
    func testAmountSurvivesCloseUnlessSessionOnly() {
        var app = launch()
        pickMemory(app, 1)                 // 12 ч — значение по умолчанию; прошлые прогоны могли его сменить
        app.buttons["settings-close"].tap()
        type50InUSD(app)
        close(app)
        app = launch()
        XCTAssertEqual(shown(app, "USD"), "50", "после закрытия сумма не вернулась")

        pickMemory(app, 0)
        XCTAssertTrue(app.buttons["set-memory"].label.contains("Until the app is closed"),
                      "пункт показывает другое: \(app.buttons["set-memory"].label)")
        app.buttons["settings-close"].tap()
        close(app)
        app = launch()
        XCTAssertEqual(shown(app, "EUR"), "1", "«Пока приложение открыто»: после закрытия не 1 EUR")

        pickMemory(app, 1)                 // вернуть 12 ч: выбор сохраняется и иначе достался бы следующим тестам
        app.buttons["settings-close"].tap()
    }

    /// Сроки: сумма записана 11 / 13 / 25 часов / 30 дней назад.
    func testTimeLimits() {
        let now = Date().timeIntervalSince1970
        func saved(hoursAgo: Double, mode: Int) -> [String] {
            ["-saved_code", "USD", "-saved_amount", "50", "-amount_memory", "\(mode)",
             "-adjust_left_at", String(format: "%.0f", now - hoursAgo * 3600)]
        }
        var app = launch(saved(hoursAgo: 11, mode: 1))
        XCTAssertEqual(shown(app, "USD"), "50", "12 ч, прошло 11: сумма не вернулась")
        app.terminate()
        app = launch(saved(hoursAgo: 13, mode: 1))
        XCTAssertEqual(shown(app, "EUR"), "1", "12 ч, прошло 13: сумма не сбросилась")
        app.terminate()
        app = launch(saved(hoursAgo: 13, mode: 2))
        XCTAssertEqual(shown(app, "USD"), "50", "24 ч, прошло 13: сумма не вернулась")
        app.terminate()
        app = launch(saved(hoursAgo: 25, mode: 2))
        XCTAssertEqual(shown(app, "EUR"), "1", "24 ч, прошло 25: сумма не сбросилась")
        app.terminate()
        app = launch(saved(hoursAgo: 720, mode: 3))
        XCTAssertEqual(shown(app, "USD"), "50", "«Всегда», прошло 30 дней: сумма не вернулась")
        app.terminate()
    }
}
