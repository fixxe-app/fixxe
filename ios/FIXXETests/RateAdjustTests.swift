import XCTest
@testable import FIXXE

/// Поправка к курсу: пересчёт, базовая строка, отсутствие «уползания» сумм
/// при переходах между строками, правило сброса.
@MainActor
final class RateAdjustTests: XCTestCase {

    // модель пишет настройки в UserDefaults приложения — после теста возвращаем как было
    private var savedDefaults: [String: Any]?
    private let domain = Bundle.main.bundleIdentifier ?? "com.karpinity.fixxe"
    override func setUp() { savedDefaults = UserDefaults.standard.persistentDomain(forName: domain) }
    override func tearDown() {
        if let d = savedDefaults { UserDefaults.standard.setPersistentDomain(d, forName: domain) }
        else { UserDefaults.standard.removePersistentDomain(forName: domain) }
    }

    private func model(_ pct: Double) -> ConverterViewModel {
        UserDefaults.standard.removeObject(forKey: "adjust_pct")
        let vm = ConverterViewModel()
        vm.currencies = ["EUR", "USD", "RSD", "BTC"]
        vm.decimals = 2; vm.grouping = 0
        vm.rates = ["EUR": 1, "USD": 1.1237, "RSD": 117.55, "BTC": 0.0000098]
        vm.setActive("EUR"); vm.inputChanged("100")
        vm.setAdjust(pct)
        return vm
    }
    private func snapshot(_ vm: ConverterViewModel) -> [String: Double] {
        Dictionary(uniqueKeysWithValues: vm.currencies.map { ($0, vm.converted($0)) })
    }

    func testOtherRowsAreChangedByPercentAndBaseIsExact() {
        let vm = model(1.5)
        XCTAssertEqual(vm.converted("EUR"), 100, "базовая строка — ровно то, что ввели")
        XCTAssertEqual(vm.converted("USD"), 100 * 1.1237 * 1.015, accuracy: 1e-9)
        XCTAssertEqual(vm.converted("RSD"), 100 * 117.55 * 1.015, accuracy: 1e-9)
        XCTAssertEqual(vm.rateLine("USD"), "1 EUR = \(SmartFormat.rate(1.1237 * 1.015)) USD", "строка курса — тоже с поправкой")
        XCTAssertEqual(vm.rateLine("EUR"), "", "у базовой строки подписи нет")
        XCTAssertTrue(vm.isAdjusted("USD")); XCTAssertFalse(vm.isAdjusted("EUR"))

        let down = model(-1.5)
        XCTAssertEqual(down.converted("USD"), 100 * 1.1237 * 0.985, accuracy: 1e-9, "отрицательная поправка уменьшает")

        let off = model(0)
        XCTAssertEqual(off.converted("USD"), 100 * 1.1237, accuracy: 1e-9)
        XCTAssertFalse(off.isAdjusted("USD"))
    }

    /// Главный риск: процент не должен прибавляться заново при каждом переходе
    /// между строками. Ходим по всем строкам туда-обратно, ничего не вводя, —
    /// и ещё отдаём модели её же текст, как это делает TextField на Mac.
    func testMovingBetweenRowsNeverChangesAmounts() {
        let vm = model(1.5)
        let before = snapshot(vm)
        for _ in 0..<5 {
            for code in ["USD", "RSD", "BTC", "EUR", "RSD", "USD", "EUR"] {
                vm.setActive(code)
                vm.inputChanged(vm.inputText)
            }
        }
        let after = snapshot(vm)
        for code in vm.currencies {
            XCTAssertEqual(after[code]!, before[code]!, accuracy: 0,
                           "\(code): сумма изменилась без ввода (\(before[code]!) → \(after[code]!))")
        }
        XCTAssertEqual(vm.baseCode, "EUR", "база — строка последнего ввода, переходы её не меняют")
    }

    func testTypingInAnotherRowMakesItTheBase() {
        let vm = model(1.5)
        vm.setActive("USD")
        XCTAssertEqual(vm.inputText, SmartFormat.amount(100 * 1.1237 * 1.015, decimals: 2), "в поле — то же число, что было в строке")
        vm.inputChanged("200")
        XCTAssertEqual(vm.baseCode, "USD")
        XCTAssertEqual(vm.converted("USD"), 200)
        XCTAssertEqual(vm.converted("EUR"), 200 / 1.1237 * 1.015, accuracy: 1e-9)
        XCTAssertFalse(vm.isAdjusted("USD")); XCTAssertTrue(vm.isAdjusted("EUR"))
    }

    func testWithoutAdjustmentCursorRowIsTheBaseAsBefore() {
        let vm = model(0)
        vm.setActive("USD")
        XCTAssertEqual(vm.baseCode, "USD", "без поправки переход на строку делает её базой — прежнее поведение")
        XCTAssertEqual(vm.rateLine("EUR"), "1 USD = \(SmartFormat.rate(1 / 1.1237)) EUR")
    }

    func testRemovingRows() {
        let vm = model(1.5)
        vm.setActive("USD")                       // курсор на USD, база EUR
        let rsd = vm.converted("RSD")
        vm.remove("USD")                          // удалили строку с курсором
        XCTAssertEqual(vm.activeCode, "EUR"); XCTAssertEqual(vm.baseCode, "EUR")
        XCTAssertEqual(vm.converted("RSD"), rsd, accuracy: 0, "остальные суммы не изменились")

        let vm2 = model(1.5)
        let shownUsd = vm2.converted("USD")
        vm2.remove("EUR")                         // удалили базу
        XCTAssertEqual(vm2.baseCode, "USD")
        XCTAssertEqual(vm2.converted("USD"), shownUsd, accuracy: 0, "новая база — с той суммой, что была на экране")
    }

    func testChangingPercentKeepsWhatWasTyped() {
        let vm = model(1.5)
        vm.setActive("RSD")                       // курсор ушёл с базы
        vm.setAdjust(3)
        XCTAssertEqual(vm.activeCode, "EUR", "курсор вернулся на базовую строку")
        XCTAssertEqual(vm.converted("EUR"), 100)
        XCTAssertEqual(vm.converted("USD"), 100 * 1.1237 * 1.03, accuracy: 1e-9)
        vm.setAdjust(0)
        XCTAssertEqual(vm.converted("USD"), 100 * 1.1237, accuracy: 1e-9)
    }

    func testResetRule() {
        let h: TimeInterval = 3600, t0: TimeInterval = 1_000_000
        XCTAssertFalse(RateAdjust.shouldReset(pct: 1.5, keep: false, leftAt: t0, now: t0 + 3.9 * h), "меньше 4 часов — остаётся")
        XCTAssertTrue(RateAdjust.shouldReset(pct: 1.5, keep: false, leftAt: t0, now: t0 + 4.1 * h), "больше 4 часов — сброс")
        XCTAssertFalse(RateAdjust.shouldReset(pct: 1.5, keep: true, leftAt: t0, now: t0 + 400 * h), "«действует постоянно» — не сбрасывается")
        XCTAssertFalse(RateAdjust.shouldReset(pct: 0, keep: false, leftAt: t0, now: t0 + 400 * h), "выключенную сбрасывать нечего")
        XCTAssertTrue(RateAdjust.shouldReset(pct: -2, keep: false, leftAt: t0, now: t0 - 60), "часы ушли назад — сброс")
    }

    func testExpiredAdjustmentIsResetWithUndo() {
        let vm = model(1.5)
        let now = Date().timeIntervalSince1970
        vm.resetAdjustIfExpired(now: now + 60)
        XCTAssertEqual(vm.adjustPct, 1.5, "минуту спустя поправка на месте")
        vm.resetAdjustIfExpired(now: now + 5 * 3600)
        XCTAssertEqual(vm.adjustPct, 0); XCTAssertEqual(vm.adjustResetFrom, 1.5, "сброс не молчаливый")
        XCTAssertEqual(vm.converted("USD"), 100 * 1.1237, accuracy: 1e-9)
        vm.setAdjust(vm.adjustResetFrom!)         // «Вернуть»
        XCTAssertEqual(vm.adjustPct, 1.5); XCTAssertNil(vm.adjustResetFrom)

        vm.adjustKeep = true
        vm.resetAdjustIfExpired(now: now + 500 * 3600)
        XCTAssertEqual(vm.adjustPct, 1.5, "закреплённая поправка не сбрасывается")
    }

    func testLabelAndClamp() {
        XCTAssertEqual(RateAdjust.label(1.5), "+1.5%")
        XCTAssertEqual(RateAdjust.label(2), "+2%")
        XCTAssertEqual(RateAdjust.label(0.25), "+0.25%")
        XCTAssertEqual(RateAdjust.label(-1.5), "\u{2212}1.5%")
        XCTAssertEqual(RateAdjust.clamp(1.23456), 1.23)
        XCTAssertEqual(RateAdjust.clamp(500), 99.99); XCTAssertEqual(RateAdjust.clamp(-500), -99.99)
        XCTAssertEqual(RateAdjust.clamp(.nan), 0)
    }
}
