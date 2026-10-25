import XCTest
@testable import FIXXE

/// Переключение строк не должно менять суммы.
///
/// На Mac (приложение из App Store на Apple silicon) TextField сообщает об
/// изменении текста и тогда, когда текст подставило само приложение при
/// переходе на другую строку. Такой «ввод» принимался за настоящий, и точная
/// сумма заменялась показанной, округлённой: 1,1239 USD становилось 1,13.
/// Человек просто переставлял курсор между EUR и USD, ничего не вводя, а
/// числа уползали.
///
/// Тест делает ровно то, что делает TextField на Mac: после каждого
/// переключения отдаёт модели обратно тот текст, который она сама поставила.
@MainActor
final class SwitchRowsTests: XCTestCase {

    // Модель сохраняет список валют и настройки в UserDefaults приложения,
    // а тесты идут внутри него же. Без восстановления удалённая здесь USD
    // пропадала и у следующего UI-теста — тот ждал строку USD и падал,
    // причём только при одном порядке запуска.
    private var savedDefaults: [String: Any]?
    private let domain = Bundle.main.bundleIdentifier ?? "com.karpinity.fixxe"

    override func setUp() {
        super.setUp()
        savedDefaults = UserDefaults.standard.persistentDomain(forName: domain)
    }

    override func tearDown() {
        if let saved = savedDefaults { UserDefaults.standard.setPersistentDomain(saved, forName: domain) }
        else { UserDefaults.standard.removePersistentDomain(forName: domain) }
        super.tearDown()
    }

    private func model() -> ConverterViewModel {
        let vm = ConverterViewModel()
        // Точность и группировку задаём явно, а не берём из сохранённых
        // настроек: при точности 4 знака 1,1239 показывается без округления,
        // дрейфа нет — и тест проходил бы даже на сломанном коде.
        vm.decimals = 0
        vm.grouping = 0
        // курсы как в отчёте об ошибке: база EUR
        vm.rates = ["EUR": 1, "USD": 1.1239, "RSD": 117.42, "ETH": 0.000450]
        vm.activeCode = "EUR"
        vm.activeAmount = 1
        vm.inputText = "1"
        return vm
    }

    /// Как ведёт себя TextField на Mac: эхо программно поставленного текста.
    private func echo(_ vm: ConverterViewModel) { vm.inputChanged(vm.inputText) }

    func testSwitchingBackAndForthKeepsExactAmount() {
        let vm = model()
        for _ in 0..<6 {
            vm.setActive("USD"); echo(vm)
            vm.setActive("EUR"); echo(vm)
        }
        XCTAssertEqual(vm.converted("EUR"), 1, accuracy: 1e-9,
                       "после переключений 1 EUR превратился в \(vm.converted("EUR"))")
        XCTAssertEqual(vm.converted("USD"), 1.1239, accuracy: 1e-9,
                       "после переключений USD стал \(vm.converted("USD")) вместо 1.1239")
    }

    /// Тот же сценарий через валюту с мелкими суммами — там округление показа
    /// грубее всего, и дрейф был бы самым заметным.
    func testSwitchingThroughCryptoKeepsExactAmount() {
        let vm = model()
        for _ in 0..<6 {
            vm.setActive("ETH"); echo(vm)
            vm.setActive("RSD"); echo(vm)
            vm.setActive("EUR"); echo(vm)
        }
        XCTAssertEqual(vm.converted("EUR"), 1, accuracy: 1e-9)
    }

    /// Настоящий ввод по-прежнему обязан работать: защита от эха не должна
    /// глотать то, что человек напечатал сам.
    func testRealInputStillApplies() {
        let vm = model()
        vm.setActive("USD"); echo(vm)
        vm.inputChanged("50")
        XCTAssertEqual(vm.activeAmount, 50, accuracy: 1e-9)
        XCTAssertEqual(vm.converted("EUR"), 50 / 1.1239, accuracy: 1e-9)
    }

    /// Удаление активной валюты переводит сумму, а не переносит её как есть.
    func testRemovingActiveCurrencyConvertsAmount() {
        let vm = model()
        vm.currencies = ["EUR", "USD", "RSD"]
        vm.setActive("USD"); vm.inputChanged("100")
        vm.remove("USD")
        XCTAssertEqual(vm.activeCode, "EUR")
        XCTAssertEqual(vm.activeAmount, 100 / 1.1239, accuracy: 1e-9,
                       "100 USD после удаления USD должны стать \(100 / 1.1239) EUR, а стали \(vm.activeAmount)")
    }
}

/// Форматирование и разбор сумм.
final class SmartFormatTests: XCTestCase {

    /// Огромная сумма не роняет приложение. Раньше при точности 0 знаков
    /// число переводилось в Int, а это аварийное завершение выше 9,2·10¹⁸.
    func testHugeAmountDoesNotCrash() {
        let s = SmartFormat.amount(3e19, decimals: 0)
        XCTAssertTrue(s.hasPrefix("3"), "получилось \(s)")
        XCTAssertEqual(SmartFormat.amount(.infinity, decimals: 0), "0")
        XCTAssertEqual(SmartFormat.amount(.nan, decimals: 2), "0.00")
    }

    func testParse() {
        // запятая как десятичный знак — при любой группировке
        XCTAssertEqual(SmartFormat.parse("1,5", grouping: 0), 1.5, accuracy: 1e-12)
        XCTAssertEqual(SmartFormat.parse("1,5", grouping: 2), 1.5, accuracy: 1e-12)   // было 15
        XCTAssertEqual(SmartFormat.parse("2.5"), 2.5, accuracy: 1e-12)
        // оба знака: десятичный — правый
        XCTAssertEqual(SmartFormat.parse("1,234.56"), 1234.56, accuracy: 1e-9)
        XCTAssertEqual(SmartFormat.parse("1.234,56"), 1234.56, accuracy: 1e-9)
        // пробелы — разряды
        XCTAssertEqual(SmartFormat.parse("1 234,56", grouping: 2), 1234.56, accuracy: 1e-9)   // было 123456
        // повтор знака — разряды
        XCTAssertEqual(SmartFormat.parse("1,234,567"), 1234567, accuracy: 1e-9)
        // группировка запятой и ровно тройки цифр — тысячи
        XCTAssertEqual(SmartFormat.parse("1,500", grouping: 2), 1500, accuracy: 1e-9)
        // мусор — ноль
        for s in ["", ",", ".", "-", "abc", "1e999"] { XCTAssertEqual(SmartFormat.parse(s), 0, "«\(s)»") }
    }
}
