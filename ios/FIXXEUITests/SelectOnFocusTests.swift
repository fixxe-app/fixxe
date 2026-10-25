import XCTest

/// Поле суммы при получении фокуса выделяет число целиком — как на Android
/// (`android:selectAllOnFocus`). Это значит, что новую сумму можно набрать
/// сразу, не стирая старую: первая же цифра заменяет всё содержимое.
final class SelectOnFocusTests: XCTestCase {

    func testTypingReplacesWholeAmountAfterFocus() {
        let app = XCUIApplication()
        // свой список: тест удаления в TapInteractionTests убирает USD, и это
        // сохраняется — без него тест зависел бы от прошлого прогона
        app.launchArguments += ["-screen-currencies", "EUR,USD,RSD,GEL,ILS,TJS,CHF"]
        app.launch()

        let usd = app.descendants(matching: .any)["amount-USD"]
        XCTAssertTrue(usd.waitForExistence(timeout: 20), "строка USD не появилась")

        usd.tap()                                   // фокус → число выделено целиком
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5),
                      "клавиатура не открылась")

        // клавиши цифровой клавиатуры XCUITest нажать не может
        // (kAXErrorCannotComplete), поэтому печатаем прямо в поле
        usd.typeText("7")

        // Если выделения не было, к старому значению допишется семёрка
        // (получилось бы «1.137» или «71.13»); при выделении останется ровно «7».
        let value = (app.descendants(matching: .any)["amount-USD"].value as? String) ?? ""
        XCTAssertEqual(value, "7",
                       "ожидали, что цифра заменит всё число, а в поле «\(value)»")
    }
}
