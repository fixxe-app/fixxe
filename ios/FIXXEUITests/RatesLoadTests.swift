import XCTest

/// Самая дорогая поломка — та, при которой курсы просто не грузятся.
/// В 1.57 такое случилось на Android: защита от частых нажатий отсекала
/// самый первый запрос, и приложение навсегда оставалось на «Loading…».
/// Эти тесты стерегут то же самое на iOS.
final class RatesLoadTests: XCTestCase {

    /// Холодный запуск обязан показать курсы, а не застрять на загрузке.
    func testRatesLoadOnLaunch() {
        let app = XCUIApplication()
        // свой список: тест удаления в TapInteractionTests убирает USD, и это
        // сохраняется — без него тест зависел бы от прошлого прогона
        app.launchArguments += ["-screen-currencies", "EUR,USD,RSD,GEL,ILS,TJS,CHF"]
        app.launch()

        // «1 EUR = …» под строкой валюты появляется только после реальных курсов
        let rateLine = app.staticTexts.containing(
            NSPredicate(format: "label BEGINSWITH '1 EUR = '")).firstMatch
        XCTAssertTrue(rateLine.waitForExistence(timeout: 25),
                      "курсы не загрузились при запуске — экран застрял на загрузке?")

        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.lifetime = .keepAlways; shot.name = "rates-loaded"; add(shot)
    }

    /// Частые нажатия не должны ни долбить API, ни убивать кнопку насовсем:
    /// после паузы «обновить» обязана снова работать.
    func testRefreshStaysAliveAfterRapidTaps() {
        let app = XCUIApplication()
        // свой список: тест удаления в TapInteractionTests убирает USD, и это
        // сохраняется — без него тест зависел бы от прошлого прогона
        app.launchArguments += ["-screen-currencies", "EUR,USD,RSD,GEL,ILS,TJS,CHF"]
        app.launch()

        let amount = app.descendants(matching: .any)["amount-USD"]
        XCTAssertTrue(amount.waitForExistence(timeout: 25), "строка USD не появилась")

        // кнопку ищем строго по идентификатору: «вторая кнопка в шапке» могла
        // оказаться чем угодно, и тест проверял бы не то
        let button = app.buttons["refresh"]
        XCTAssertTrue(button.waitForExistence(timeout: 5), "не нашёл кнопку «обновить»")
        // в accessibilityValue — сколько запросов к источникам реально ушло
        func fetches() -> Int { Int(button.value as? String ?? "") ?? -1 }
        XCTAssertGreaterThanOrEqual(fetches(), 1, "при запуске не ушло ни одного запроса")

        // Окно тротлинга (10 с) считается от последнего запроса. Раньше его
        // отсчитывали от запроса при запуске, и на нагруженном Mac ожидание
        // списка плюс 12 тапов выходили за 10 с — законный второй запрос тест
        // принимал за поломку. Теперь: переждать окно, первый тап обязан дать
        // ровно один запрос, и окно начинается от него.
        Thread.sleep(forTimeInterval: 11)
        let before = fetches()
        button.tap()
        let first = NSPredicate { _, _ in fetches() == before + 1 }
        expectation(for: first, evaluatedWith: button, handler: nil)
        waitForExpectations(timeout: 10) { error in
            XCTAssertNil(error, "после паузы первое нажатие не отправило запрос")
        }
        let start = fetches()
        let t0 = Date()
        for _ in 0..<11 { button.tap() }
        let elapsed = Date().timeIntervalSince(t0)
        XCTAssertTrue(app.state == .runningForeground, "приложение не пережило частые нажатия")
        // если тапы растянулись дольше окна, следующий запрос законен
        let allowed = Int(elapsed / 10)
        XCTAssertLessThanOrEqual(fetches() - start, allowed,
            "11 быстрых нажатий за \(String(format: "%.1f", elapsed)) с дали \(fetches() - start) лишних запросов — тротлинг не работает")

        // переждать окно тротлинга: кнопка обязана снова отправить запрос
        Thread.sleep(forTimeInterval: 11)
        button.tap()
        let alive = NSPredicate { _, _ in fetches() > start }
        expectation(for: alive, evaluatedWith: button, handler: nil)
        waitForExpectations(timeout: 10) { error in
            XCTAssertNil(error, "после паузы нажатие «обновить» не отправило запрос")
        }
    }
}
