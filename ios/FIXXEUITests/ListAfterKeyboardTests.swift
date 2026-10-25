import XCTest

/// Клавиатура поднимает список к строке ввода. После того как её убрали,
/// список обязан стоять как до клавиатуры — на Android он оставался сдвинутым.
final class ListAfterKeyboardTests: XCTestCase {
    private let codes = ["EUR","USD","RSD","GBP","CHF","JPY","CNY","TRY","GEL","ILS","PLN","CZK"]

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-screen-currencies", codes.joined(separator: ",")]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["amount-EUR"].waitForExistence(timeout: 20),
                      "список не появился")
        return app
    }

    /// Нижняя строка, которую клавиатура заведомо накроет.
    private func lowestVisible(_ app: XCUIApplication) -> XCUIElement {
        let h = app.windows.firstMatch.frame.height
        return codes.map { app.descendants(matching: .any)["amount-\($0)"] }
            .filter { $0.exists && $0.isHittable && $0.frame.maxY < h - 60 }
            .max { $0.frame.minY < $1.frame.minY }!
    }

    private func top(_ app: XCUIApplication) -> CGFloat? {
        let e = app.descendants(matching: .any)["amount-EUR"]
        return e.exists ? e.frame.minY : nil
    }

    private func check(_ how: String, close: (XCUIApplication) -> Void) {
        let app = launch()
        let before = top(app)!
        lowestVisible(app).tap()
        let kb = app.keyboards.firstMatch
        XCTAssertTrue(kb.waitForExistence(timeout: 5), "клавиатура не открылась")
        let during = top(app)
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.lifetime = .keepAlways; shot.name = "\(how)-open"; add(shot)
        close(app)
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: kb)
        wait(for: [gone], timeout: 5)
        Thread.sleep(forTimeInterval: 1)       // анимация списка после клавиатуры
        let after = top(app)
        print("[\(how)] EUR minY: до=\(before) с клавиатурой=\(String(describing: during)) после=\(String(describing: after))")
        XCTAssertNotNil(after, "\(how): после закрытия клавиатуры строка EUR ушла за экран")
        if let after { XCTAssertEqual(after, before, accuracy: 1, "\(how): список остался сдвинутым") }
    }

    /// Как на скриншотах с 6S: список прокручен к концу, ввод в нижнюю
    /// строку, клавиатуру открывают и закрывают несколько раз подряд — каждый
    /// раз список обязан встать в то же место, что до первого ввода.
    func testListReturnsToSamePlaceEveryTimeWhenScrolled() {
        let app = launch()
        app.swipeUp(); Thread.sleep(forTimeInterval: 1.5)     // к концу списка, как у пользователя
        // «как стоит список» — место строки, которая видна до и после
        func anchor() -> (String, CGFloat)? {
            for c in codes.reversed() {
                let e = app.descendants(matching: .any)["amount-\(c)"]
                if e.exists && e.isHittable { return (c, e.frame.minY) }
            }
            return nil
        }
        let before = anchor()!
        var results: [String] = []
        for round in 1...3 {
            lowestVisible(app).tap()
            let kb = app.keyboards.firstMatch
            XCTAssertTrue(kb.waitForExistence(timeout: 5), "раунд \(round): клавиатура не открылась")
            Thread.sleep(forTimeInterval: 0.8)
            app.buttons["dismiss-keyboard"].tap()
            let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: kb)
            wait(for: [gone], timeout: 5)
            Thread.sleep(forTimeInterval: 1.2)
            let e = app.descendants(matching: .any)["amount-\(before.0)"]
            let y = e.exists ? e.frame.minY : -999
            results.append(String(format: "%.1f", y))
            let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            shot.lifetime = .keepAlways; shot.name = "round-\(round)"; add(shot)
        }
        print("[повторы] \(before.0) minY до=\(before.1) после раундов=\(results)")
        for (i, r) in results.enumerated() {
            XCTAssertEqual(Double(r)!, Double(before.1), accuracy: 2,
                           "раунд \(i + 1): список встал не на место (до \(before.1), после \(results))")
        }
    }

    func testListReturnsAfterToolbarButton() {
        check("кнопка над клавиатурой") { $0.buttons["dismiss-keyboard"].tap() }
    }
}
