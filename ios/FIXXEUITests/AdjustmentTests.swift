import XCTest

/// Поправка к курсу на экране: полоса «Курсы с поправкой», пометка строк,
/// подвал, и главное — суммы не меняются, пока человек только переходит
/// между строками.
final class AdjustmentTests: XCTestCase {
    private let codes = ["EUR", "USD", "RSD", "GEL"]

    override func setUp() { continueAfterFailure = false }

    private func launch(adjust: String?, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-screen-currencies", codes.joined(separator: ",")] + extra
        if let adjust { app.launchArguments += ["-screen-adjust", adjust] }
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["amount-EUR"].waitForExistence(timeout: 25), "список не появился")
        XCTAssertTrue(app.descendants(matching: .any)["rate-USD"].waitForExistence(timeout: 25), "курсы не загрузились")
        return app
    }
    private func amount(_ app: XCUIApplication, _ c: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "amount-\(c)").firstMatch
    }
    /// число в строке: у строки с курсором это значение поля, у остальных — текст
    private func shown(_ app: XCUIApplication, _ c: String) -> String {
        let e = amount(app, c)
        return e.elementType == .textField ? (e.value as? String ?? "") : e.label
    }
    private func all(_ app: XCUIApplication) -> [String] { codes.map { "\($0)=\(shown(app, $0))" } }

    func testNoBannerWithoutAdjustment() {
        let app = launch(adjust: nil)
        XCTAssertFalse(app.descendants(matching: .any)["adjust-banner"].exists, "полоса видна при выключенной поправке")
        XCTAssertFalse(app.buttons["rates-info"].label.contains("Adjusted"))
    }

    func testBannerRowsAndFooterSayRatesAreAdjusted() {
        let app = launch(adjust: "1.5")
        let banner = app.descendants(matching: .any)["adjust-banner"]
        XCTAssertTrue(banner.waitForExistence(timeout: 5), "нет полосы «Курсы с поправкой»")
        XCTAssertEqual(banner.label, "Adjusted rates")
        XCTAssertFalse(banner.label.contains("1.5"), "на главном экране процент не показывается")
        XCTAssertTrue(app.buttons["rates-info"].label.hasPrefix("Adjusted rates"), "строка статуса всё ещё говорит «Market rate»")
        let usdRate = app.descendants(matching: .any)["rate-USD"]
        XCTAssertTrue(usdRate.label.hasPrefix("Adjusted: 1 EUR = "), "строка курса не помечена: «\(usdRate.label)»")
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); shot.lifetime = .keepAlways; shot.name = "adjusted"; add(shot)
    }

    /// Ходим по строкам, ничего не вводя: ни одно число не должно измениться.
    /// Без базовой строки процент прибавлялся бы при каждом переходе.
    func testMovingBetweenRowsDoesNotChangeAmounts() {
        let app = launch(adjust: "1.5")
        let before = all(app)
        for c in ["USD", "RSD", "EUR", "GEL", "USD", "EUR"] {
            amount(app, c).tap()
            XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "клавиатура не открылась на \(c)")
            Thread.sleep(forTimeInterval: 0.6)
            XCTAssertEqual(all(app), before, "после перехода на \(c) суммы изменились без ввода")
        }
    }

    func testTypingMakesRowTheBaseAndOthersFollow() {
        let app = launch(adjust: "1.5")
        amount(app, "USD").tap()
        let field = app.textFields["amount-USD"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.6)
        field.typeText("200")                     // число выделено целиком — заменяется
        XCTAssertEqual(field.value as? String, "200")
        let eurRate = app.descendants(matching: .any)["rate-EUR"]
        XCTAssertTrue(eurRate.label.hasPrefix("Adjusted: 1 USD = "), "база не сменилась на USD: «\(eurRate.label)»")
        XCTAssertEqual(app.descendants(matching: .any)["rate-USD"].label, "", "у базовой строки подписи курса нет")
    }

    func testBannerOpensSettingAndOffRemovesIt() {
        let app = launch(adjust: "1.5")
        let adjustedUsd = shown(app, "USD")
        app.descendants(matching: .any)["adjust-banner"].tap()
        let off = app.buttons["adjust-off"]
        XCTAssertTrue(off.waitForExistence(timeout: 5), "полоса не открыла настройку поправки")
        XCTAssertEqual(app.staticTexts["adjust-value"].label, "+1.5%", "в настройке текущее значение не показано")
        off.tap()
        app.buttons["adjust-close"].tap()
        XCTAssertTrue(amount(app, "EUR").waitForExistence(timeout: 5))
        let gone = expectation(for: NSPredicate(format: "exists == false"),
                               evaluatedWith: app.descendants(matching: .any)["adjust-banner"])
        wait(for: [gone], timeout: 5)
        XCTAssertTrue(app.buttons["rates-info"].label.hasPrefix("Market rate"), "строка статуса не вернулась к «Market rate»: \(app.buttons["rates-info"].label)")
        XCTAssertNotEqual(shown(app, "USD"), adjustedUsd, "суммы не пересчитались после выключения")
    }
}

extension AdjustmentTests {
    /// Окно настроек: пункты в нужном порядке, поправка — последней, внизу версия.
    /// Округление «к ближайшему» сразу меняет суммы на экране.
    func testSettingsWindowAndRounding() {
        let app = launch(adjust: nil, extra: ["-round_up", "YES"])
        // курс со строки USD: «1 EUR = 1.1206 USD»
        let rateText = app.descendants(matching: .any)["rate-USD"].label
        let r = Double(rateText.split(separator: " ")[3]) ?? 0
        XCTAssertGreaterThan(r, 0, "не прочитал курс: «\(rateText)»")
        // сумма EUR подобрана так, чтобы в долларах вышло ≈100.3: вверх — 101,
        // к ближайшему — 100. На «круглой» сумме оба способа могли совпасть.
        let eur = String(format: "%.2f", 100.3 / r)
        amount(app, "EUR").tap()
        let field = app.textFields["amount-EUR"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.6)
        field.typeText(eur)
        app.buttons["dismiss-keyboard-header"].tap()
        Thread.sleep(forTimeInterval: 0.6)
        let up = "101", near = "100"
        XCTAssertEqual(shown(app, "USD"), up, "вверх: \(eur) EUR по курсу \(r)")

        app.buttons["settings"].tap()
        let ids = ["set-theme", "set-precision", "set-rounding", "set-grouping", "set-source", "set-language", "set-adjust"]
        for id in ids { XCTAssertTrue(app.buttons[id].waitForExistence(timeout: 5), "в настройках нет пункта \(id)") }
        let ys = ids.map { app.buttons[$0].frame.minY }
        XCTAssertEqual(ys, ys.sorted(), "пункты настроек не в том порядке")
        XCTAssertTrue(app.buttons["set-version"].exists, "внизу настроек нет номера версии")
        app.buttons["set-rounding"].tap()
        XCTAssertTrue(app.buttons["rounding-1"].waitForExistence(timeout: 5), "не открылся выбор округления")
        app.buttons["rounding-1"].tap()
        XCTAssertTrue(app.buttons["set-rounding"].waitForExistence(timeout: 5), "после выбора не вернулись к настройкам")
        app.buttons["settings-close"].tap()
        XCTAssertTrue(amount(app, "USD").waitForExistence(timeout: 5))
        XCTAssertEqual(shown(app, "USD"), near, "к ближайшему: \(eur) EUR по курсу \(r)")
        // вернуть «вверх»: выбор сохраняется и иначе достался бы следующим тестам
        app.buttons["settings"].tap()
        XCTAssertTrue(app.buttons["set-rounding"].waitForExistence(timeout: 5))
        app.buttons["set-rounding"].tap()
        XCTAssertTrue(app.buttons["rounding-0"].waitForExistence(timeout: 5))
        app.buttons["rounding-0"].tap()
        XCTAssertTrue(app.buttons["set-rounding"].waitForExistence(timeout: 5))
        app.buttons["settings-close"].tap()
    }
}

// Те же сценарии ввода, каретки, клавиатуры, сдвига и возврата списка — с
// включённой поправкой: полоса меняет высоту экрана, а суммы и поле ввода
// получают другой цвет. Ни один из них не должен от этого сломаться.
final class TapInteractionWithAdjustmentTests: TapInteractionTests {
    override class var extraArgs: [String] { ["-screen-adjust", "1.5"] }
}
final class ListAfterKeyboardWithAdjustmentTests: ListAfterKeyboardTests {
    override class var extraArgs: [String] { ["-screen-adjust", "1.5"] }
}
final class KeyboardWithAdjustmentTests: KeyboardTests {
    override class var extraArgs: [String] { ["-screen-adjust", "1.5"] }
}
final class SelectOnFocusWithAdjustmentTests: SelectOnFocusTests {
    override class var extraArgs: [String] { ["-screen-adjust", "1.5"] }
}
final class ReorderWithAdjustmentTests: ReorderTests {
    override class var extraArgs: [String] { ["-screen-adjust", "1.5"] }
}
final class OrientationWithAdjustmentTests: OrientationTests {
    override class var extraArgs: [String] { ["-screen-adjust", "1.5"] }
}

extension XCTestCase {
    /// Наборы «…WithAdjustment» обязаны идти с поправкой: без этой проверки они
    /// при любой ошибке в аргументах запуска молча повторяли бы обычный прогон.
    func requireAdjustment(_ app: XCUIApplication, _ extraArgs: [String],
                           file: StaticString = #filePath, line: UInt = #line) {
        guard extraArgs.contains("-screen-adjust") else { return }
        let banner = app.descendants(matching: .any).matching(identifier: "adjust-banner").firstMatch
        XCTAssertTrue(banner.waitForExistence(timeout: 25),
                      "набор «с поправкой» запущен, а поправка не включилась — полосы нет", file: file, line: line)
    }
}
