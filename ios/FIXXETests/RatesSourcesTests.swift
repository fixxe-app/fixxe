import XCTest
@testable import FIXXE

/// Источники курсов: разбор ответов, порядок, резерв, перенос сохранённого
/// выбора. Сеть подменяется — тест не зависит от того, какой источник жив.
final class RatesSourcesTests: XCTestCase {

    private var savedLoader: ((String) async throws -> Data)!
    override func setUp() { savedLoader = RatesService.loader }
    override func tearDown() { RatesService.loader = savedLoader }

    /// запросы уходят параллельно — запись под замком
    private final class Asked {
        private let lock = NSLock(); private var list: [String] = []
        func add(_ u: String) { lock.lock(); list.append(u); lock.unlock() }
        var urls: [String] { lock.lock(); defer { lock.unlock() }; return list }
    }
    private func json(_ s: String) -> Data { Data(s.utf8) }
    private var wise: Int { RatesService.sources.firstIndex { $0.name == "Wise" }! + 1 }

    func testLiveSourcesParseStringRates() throws {
        XCTAssertEqual(RatesService.numRates(["EUR": "1", "rsd": "117.6", "BAD": "x", "ZERO": "0",
                                              "NEG": "-2", "INF": "inf", "NUM": 3.5]),
                       ["EUR": 1, "RSD": 117.6, "NUM": 3.5])
        let cb = try RatesService.sources[0].parse(json(
            #"{"data":{"currency":"EUR","rates":{"EUR":"1","USD":"1.1237","BTC":"0.0000098"}}}"#))
        XCTAssertEqual(RatesService.sources[0].name, "Coinbase")
        XCTAssertEqual(cb, ["EUR": 1, "USD": 1.1237, "BTC": 0.0000098])
        let fx = try RatesService.sources[1].parse(json(#"{"success":true,"base":"EUR","rates":{"EUR":1,"USD":1.1237}}"#))
        XCTAssertEqual(RatesService.sources[1].name, "FXRatesAPI")
        XCTAssertEqual(fx, ["EUR": 1, "USD": 1.1237])
        XCTAssertThrowsError(try RatesService.sources[1].parse(json(#"{"success":false,"error":"limit"}"#)),
                             "отказ FXRatesAPI (success=false) принят за успешный ответ")
        // отказ решает именно поле success, даже если в ответе что-то похожее на курсы
        XCTAssertThrowsError(try RatesService.sources[1].parse(json(#"{"success":false,"rates":{"EUR":1,"USD":9}}"#)),
                             "FXRatesAPI: success=false с курсами принят за успешный ответ")
    }

    func testAutoOrderIsLiveFirstAndSkipsManualOnly() {
        XCTAssertEqual(RatesService.order(preferred: 0).map(\.name),
                       ["Coinbase", "FXRatesAPI", "ExchangeRate-API", "F.A.", "Frankfurter (ECB)"])
        XCTAssertEqual(RatesService.order(preferred: 4).map(\.name),
                       ["F.A.", "Coinbase", "FXRatesAPI", "ExchangeRate-API", "Frankfurter (ECB)"],
                       "выбранный источник — первым, Wise в резерв не попадает")
        XCTAssertEqual(RatesService.order(preferred: wise).map(\.name),
                       ["Wise", "Coinbase", "FXRatesAPI", "ExchangeRate-API", "F.A.", "Frankfurter (ECB)"])
        XCTAssertEqual(RatesService.order(preferred: 99).map(\.name).count, 5, "неизвестный номер = «Авто»")
    }

    func testFallsBackWhenCoinbaseIsDownAndNeverAsksWise() async throws {
        let asked = Asked()
        RatesService.loader = { url in
            asked.add(url)
            if url.contains("api.fxratesapi.com") { return Data(#"{"success":true,"rates":{"EUR":1,"USD":1.5}}"#.utf8) }
            throw RatesError.allFailed          // Coinbase недоступен
        }
        let r = try await RatesService.fetchRates(preferred: 0, codes: ["EUR", "USD"])
        XCTAssertEqual(r.source, "FXRatesAPI")
        XCTAssertEqual(r.rates["USD"], 1.5)
        XCTAssertEqual(asked.urls.count, 2, "после успешного ответа дальше не спрашиваем: \(asked.urls)")
        XCTAssertTrue(asked.urls[0].contains("api.coinbase.com"), "первым идёт Coinbase")
        XCTAssertFalse(asked.urls.contains { $0.contains("wise.com") }, "в «Авто» Wise не участвует")
    }

    func testWiseAsksOnlyShownCurrencies() async throws {
        let asked = Asked()
        RatesService.loader = { url in
            asked.add(url)
            guard url.contains("wise.com") else { throw RatesError.allFailed }
            return Data(#"{"source":"EUR","target":"X","value":117.6,"time":1}"#.utf8)
        }
        let r = try await RatesService.fetchRates(preferred: wise, codes: ["EUR", "RSD", "USD", "RSD"])
        XCTAssertEqual(r.source, "Wise")
        XCTAssertEqual(r.rates, ["EUR": 1, "RSD": 117.6, "USD": 117.6])
        XCTAssertEqual(Set(asked.urls), ["https://wise.com/rates/live?source=EUR&target=RSD",
                                         "https://wise.com/rates/live?source=EUR&target=USD"])
    }

    func testSavedSourceChoiceMovesToNewNumbering() {
        // до 1.65: 1 — ExchangeRate-API, 2 — F.A., 3 — Frankfurter
        XCTAssertEqual([0, 1, 2, 3].map { RatesService.migrateSource($0, version: 0) }, [0, 3, 4, 5])
        XCTAssertEqual(RatesService.sources[3 - 1].name, "ExchangeRate-API")
        XCTAssertEqual(RatesService.sources[4 - 1].name, "F.A.")
        XCTAssertEqual(RatesService.sources[5 - 1].name, "Frankfurter (ECB)")
        XCTAssertEqual([1, 2, 3, 6].map { RatesService.migrateSource($0, version: 2) }, [1, 2, 3, 6],
                       "повторный перенос ничего не сдвигает")
    }
}
