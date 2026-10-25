import XCTest

/// На цифровой клавиатуре iOS нет кнопки «Готово», поэтому у поля суммы
/// есть своя кнопка в панели над клавиатурой. Без неё клавиатуру нечем убрать.
final class KeyboardTests: XCTestCase {

    func testNumericKeyboardCanBeDismissed() {
        let app = XCUIApplication()
        // свой список: тест удаления в TapInteractionTests убирает USD, и это
        // сохраняется — без него тест зависел бы от прошлого прогона
        app.launchArguments += ["-screen-currencies", "EUR,USD,RSD,GEL,ILS,TJS,CHF"]
        app.launch()

        // ждём, пока подгрузятся курсы и появится список
        let amount = app.descendants(matching: .any)["amount-USD"]
        XCTAssertTrue(amount.waitForExistence(timeout: 20), "строка USD не появилась")

        amount.tap()
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 5), "клавиатура не открылась по тапу на сумму")

        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.lifetime = .keepAlways; shot.name = "keyboard-open"; add(shot)

        // кнопка закрытия в панели над клавиатурой
        let dismiss = app.buttons["dismiss-keyboard"]
        XCTAssertTrue(dismiss.waitForExistence(timeout: 5), "нет кнопки закрытия клавиатуры")
        dismiss.tap()

        let gone = NSPredicate(format: "exists == false")
        expectation(for: gone, evaluatedWith: keyboard, handler: nil)
        waitForExpectations(timeout: 5) { error in
            XCTAssertNil(error, "клавиатура не закрылась после нажатия кнопки")
        }
    }
}
