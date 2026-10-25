import XCTest
import UIKit

/// Нажатия по строке валюты: удаление с подтверждением, первый тап по
/// неактивной сумме и установка курсора внутри уже активного поля.
///
/// Жалобы: iPhone 6S / iOS 15 — крестик ничего не делает, а сумма неактивной
/// строки реагирует только со второго тапа; новые iPhone (iOS 18/26) — курсор
/// в поле суммы никуда не ставится.
///
/// Состав списка задаётся аргументом `-screen-currencies` (только DEBUG), чтобы
/// тесты не зависели от того, что сохранили прошлые запуски: при запуске
/// активна первая валюта (EUR), остальные — неактивные строки.
final class TapInteractionTests: XCTestCase {

    private let list = "EUR,USD,RSD,GEL,ILS,TJS,CHF"

    override func setUp() {
        continueAfterFailure = false
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-screen-currencies", list]
        app.launch()
        return app
    }

    private func amount(_ app: XCUIApplication, _ code: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "amount-\(code)").firstMatch
    }

    private func hasFocus(_ e: XCUIElement) -> Bool {
        (e.value(forKey: "hasKeyboardFocus") as? Bool) ?? false
    }

    private func value(_ e: XCUIElement) -> String { (e.value as? String) ?? "" }

    /// ждать условие без падения теста; вернуть, дождались ли
    @discardableResult
    private func wait(_ timeout: TimeInterval, _ cond: @escaping () -> Bool) -> Bool {
        let exp = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in cond() }, object: nil)
        return XCTWaiter().wait(for: [exp], timeout: timeout) == .completed
    }

    private func shot(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.lifetime = .keepAlways; a.name = name; add(a)
    }

    private func note(_ name: String, _ text: String) {
        let a = XCTAttachment(string: text)
        a.lifetime = .keepAlways; a.name = name; add(a)
        print("[TapInteraction] \(name): \(text)")
    }

    /// Тап в точку поля: x — в точках от левого края кадра элемента.
    private func tap(_ e: XCUIElement, atX x: CGFloat) {
        let f = e.frame
        e.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: x, dy: f.height / 2)).tap()
    }

    /// Ширина текста шрифтом поля (.title3.bold()) — поле выровнено вправо,
    /// значит, текст начинается в maxX − ширина.
    private func textWidth(_ s: String) -> CGFloat {
        let size = UIFont.preferredFont(forTextStyle: .title3).pointSize
        let font = UIFont.systemFont(ofSize: size, weight: .bold)
        return ceil((s as NSString).size(withAttributes: [.font: font]).width)
    }

    /// Фокус в поле суммы `code`; возвращает число тапов, которое понадобилось.
    private func focus(_ app: XCUIApplication, _ code: String) -> Int {
        let field = app.textFields["amount-\(code)"]
        for n in 1...2 {
            amount(app, code).tap()
            if wait(3, { field.exists && self.hasFocus(field) && app.keyboards.firstMatch.exists }) {
                Thread.sleep(forTimeInterval: 0.6)   // selectAll уходит через 0.05 с после фокуса
                return n
            }
        }
        XCTFail("поле amount-\(code) не получило фокус и после двух тапов")
        return 0
    }

    // MARK: 1. Удаление

    func testDeleteShowsConfirmationAndRemoves() {
        let app = launch()
        let usd = amount(app, "USD")
        XCTAssertTrue(usd.waitForExistence(timeout: 20), "строка USD не появилась")

        let delete = app.buttons["delete-USD"]
        XCTAssertTrue(delete.exists, "нет кнопки delete-USD")
        delete.tap()

        let alert = app.alerts.firstMatch
        if !alert.waitForExistence(timeout: 3) {
            shot("delete-no-alert")
            XCTFail("BUG A: тап по ✕ (delete-USD) не показал подтверждение «Remove currency?» за 3 с")
            return
        }
        shot("delete-alert")
        // разрушительная кнопка — «Delete» (или перевод); «Cancel» — вторая
        let buttons = alert.buttons.allElementsBoundByIndex
        let labels = buttons.map(\.label)
        let destructive = alert.buttons["Delete"].exists ? alert.buttons["Delete"]
            : buttons.first { !["Cancel", "Отмена", "Otkaži"].contains($0.label) }
        guard let destructive else {
            XCTFail("в алерте нет кнопки удаления, кнопки: \(labels)"); return
        }
        destructive.tap()

        XCTAssertTrue(wait(3) { !usd.exists },
                      "после подтверждения («\(destructive.label)») строка amount-USD не исчезла")
    }

    // MARK: 2. Первый тап по неактивной строке

    func testFirstTapOnInactiveRowFocusesAndSelects() {
        let app = launch()
        let rsd = amount(app, "RSD")
        XCTAssertTrue(rsd.waitForExistence(timeout: 20), "строка RSD не появилась")
        XCTAssertNotEqual(rsd.elementType, .textField, "RSD должна быть неактивной строкой при запуске")
        let before = rsd.label

        rsd.tap()                                     // ровно ОДИН тап
        let field = app.textFields["amount-RSD"]
        let ok = wait(3) { field.exists && self.hasFocus(field) && app.keyboards.firstMatch.exists }
        shot("rsd-after-first-tap")
        if !ok {
            let state = "textField exists=\(field.exists) focus=\(field.exists && hasFocus(field)) " +
                        "keyboard=\(app.keyboards.firstMatch.exists)"
            // диагностика: срабатывает ли второй тап
            amount(app, "RSD").tap()
            let second = wait(3) { field.exists && self.hasFocus(field) && app.keyboards.firstMatch.exists }
            XCTFail("BUG A: первый тап по неактивной сумме RSD не дал фокус и клавиатуру (\(state)); " +
                    "второй тап \(second ? "сработал" : "тоже не сработал")")
            return
        }
        Thread.sleep(forTimeInterval: 0.6)
        let shown = value(field)
        field.typeText("5")
        let after = value(field)
        XCTAssertEqual(after, "5",
                       "после первого тапа число «\(shown)» (было «\(before)») не выделено целиком: " +
                       "ввод «5» дал «\(after)»")
    }

    // MARK: 3. Курсор в уже активном поле

    /// Вся карточка — зона нажатия: тап по названию валюты или по пустому
    /// месту строки открывает ввод в её сумму, а не только тап по числу.
    func testTapAnywhereOnCardFocusesAmount() {
        let app = launch()
        for (code, place) in [("RSD", "название"), ("GEL", "пустое место")] {
            let a = amount(app, code)
            XCTAssertTrue(a.waitForExistence(timeout: 20), "строка \(code) не появилась")
            let origin = app.coordinate(withNormalizedOffset: .zero)
            if place == "название" {
                // название валюты — вторая строка карточки, слева, прямо под ✕:
                // по координатам, а не по элементу, чтобы тест мерил поведение
                // и на версиях без идентификатора name-…
                origin.withOffset(CGVector(dx: 60, dy: a.frame.maxY + 14)).tap()
            } else {
                // между кодом валюты и символом — Spacer, ничего не нарисовано
                let w = app.windows.firstMatch.frame
                origin.withOffset(CGVector(dx: w.midX - 20, dy: a.frame.midY)).tap()
            }
            XCTAssertFalse(app.alerts.firstMatch.waitForExistence(timeout: 1),
                           "тап по месту «\(place)» в карточке \(code) открыл удаление валюты")
            let field = app.textFields["amount-\(code)"]
            let ok = wait(3) { field.exists && self.hasFocus(field) && app.keyboards.firstMatch.exists }
            shot("card-tap-\(code)")
            XCTAssertTrue(ok, "тап по месту «\(place)» в карточке \(code) не открыл ввод суммы")
        }
    }

    func testTapInFocusedFieldPlacesCaret() {
        let app = launch()
        XCTAssertTrue(amount(app, "USD").waitForExistence(timeout: 20), "строка USD не появилась")
        continueAfterFailure = true   // обе половины (конец и начало) отчитываются отдельно
        let taps = focus(app, "USD")
        if taps == 2 { note("usd-focus", "фокус в USD только со ВТОРОГО тапа") }
        let field = app.textFields["amount-USD"]
        let prev = value(field)
        XCTAssertFalse(prev.isEmpty, "в поле USD пусто")
        let f = field.frame

        // тап у КОНЦА текста: должен снять выделение и поставить курсор в конец
        tap(field, atX: f.width - 3)
        Thread.sleep(forTimeInterval: 0.8)
        shot("usd-after-end-tap")
        field.typeText("9")
        let v1 = value(field)
        XCTAssertEqual(v1, prev + "9",
                       "BUG B: тап у конца текста не поставил курсор — «9» к «\(prev)» дало «\(v1)»" +
                       (v1 == "9" ? " (выделение не снялось, число заменено)" : ""))

        // тап у НАЧАЛА текста. Чтобы проверка не зависела от первой половины,
        // ставим известное значение «234» (стираем всё, курсор в конце) —
        // «1» в начале даст «1234», в конце — «2341».
        let del = String(repeating: XCUIKeyboardKey.delete.rawValue, count: 15)
        field.typeText(del + "234")
        let base = value(field)
        let w = textWidth(base)
        let firstChar = textWidth(String(base.prefix(1)))
        let startX = max(1, f.width - w + firstChar * 0.25)
        note("geometry", "frame=\(f) text=«\(base)» width≈\(w) startX=\(startX)")
        Thread.sleep(forTimeInterval: 0.6)
        tap(field, atX: startX)
        Thread.sleep(forTimeInterval: 0.8)
        shot("usd-after-start-tap")
        field.typeText("1")
        let v2 = value(field)
        XCTAssertEqual(v2, "1" + base,
                       "BUG B: тап у начала текста (x=\(Int(startX)) из \(Int(f.width))) не поставил курсор " +
                       "в начало — «1» к «\(base)» дало «\(v2)»")
    }

    // MARK: 4. Разведка: какие точки поля вообще двигают курсор

    /// Для набора точек поля: известное значение «1234», курсор в конце,
    /// тап в точку, ввод «8». Позиция «8» показывает, куда встал курсор.
    /// Отдельно — то же самое сразу после фокуса (с выделением всего числа).
    /// Падает, если ни один тап не поставил курсор ВНУТРЬ числа (только в
    /// начало или конец) — так ведёт себя UIKit, привязывая курсор к границе слова.
    func testCaretPlacementProbe() {
        let app = launch()
        XCTAssertTrue(amount(app, "USD").waitForExistence(timeout: 20), "строка USD не появилась")
        _ = focus(app, "USD")
        let field = app.textFields["amount-USD"]
        let f = field.frame
        let w = textWidth("1234")
        let left = f.width - w
        let xs: [CGFloat] = [left + 2, left + w * 0.3, left + w * 0.55, f.width - 3, max(1, left - 20), 4]
        let del = String(repeating: XCUIKeyboardKey.delete.rawValue, count: 15)

        var report: [String] = ["frame=\(f) text «1234» width≈\(w) leftEdge≈\(left)"]
        var moved = 0
        for x in xs {
            // известное состояние: «1234», курсор в конце
            tap(field, atX: f.width - 2); Thread.sleep(forTimeInterval: 0.6)
            field.typeText(del + "1234")
            let base = value(field)
            Thread.sleep(forTimeInterval: 0.6)
            tap(field, atX: x); Thread.sleep(forTimeInterval: 0.8)
            field.typeText("8")
            let v = value(field)
            let idx = v.firstIndex(of: "8").map { v.distance(from: v.startIndex, to: $0) } ?? -1
            report.append("no-selection x=\(Int(x)): base=«\(base)» → «\(v)» (caret index \(idx))")
            Thread.sleep(forTimeInterval: 0.6)
        }
        // середина дробного числа: «12.34», тапы по каждой цифре
        let wd = textWidth("12.34"), ld = f.width - wd
        for frac in [0.1, 0.3, 0.5, 0.7, 0.9] as [CGFloat] {
            tap(field, atX: f.width - 2); Thread.sleep(forTimeInterval: 0.6)
            field.typeText(del + "12.34")
            Thread.sleep(forTimeInterval: 0.6)
            let x = ld + wd * frac
            tap(field, atX: x); Thread.sleep(forTimeInterval: 0.8)
            field.typeText("8")
            let v = value(field)
            let idx = v.firstIndex(of: "8").map { v.distance(from: v.startIndex, to: $0) } ?? -1
            if idx > 0 && idx < 5 { moved += 1 }
            report.append("decimal x=\(Int(x)) (\(Int(frac * 100))% of «12.34»): → «\(v)» (caret index \(idx))")
            Thread.sleep(forTimeInterval: 0.6)
        }
        // с выделением (сразу после фокуса): один тап и два тапа подряд
        for (x, taps) in [(left + 2, 1), (f.width - 3, 1), (left + 2, 2), (f.width - 3, 2)] {
            app.buttons["dismiss-keyboard-header"].firstMatch.tap()
            _ = wait(3) { !app.keyboards.firstMatch.exists }
            let before = value(app.textFields["amount-USD"])
            _ = focus(app, "USD")
            for _ in 0..<taps { tap(field, atX: x); Thread.sleep(forTimeInterval: 1.0) }
            if taps == 2 && x > left + 2 { shot("probe-after-focus-two-taps") }
            field.typeText("8")
            report.append("after-focus x=\(Int(x)) taps=\(taps): «\(before)» → «\(value(field))»")
        }
        note("caret-probe", report.joined(separator: "\n"))
        shot("probe-end")
        XCTAssertGreaterThan(moved, 0, "BUG B: ни один тап не поставил курсор внутрь числа «12.34» " +
                             "(только в начало/конец):\n" + report.joined(separator: "\n"))
    }
}
