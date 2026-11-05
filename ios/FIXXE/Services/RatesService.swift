import Foundation

/// Источник курсов: та же цепочка, что в Android и веб-версии. База у всех — EUR.
struct RateSource {
    let name: String
    let short: String            // подпись на чипе в списке валют
    let colorHex: String
    let site: String             // куда ведёт подпись в подвале
    var urls: [String] = []
    /// Только по ручному выбору в настройках: ни в «Авто», ни в резерв не
    /// попадает, в списке валют не показывается. Так подключён Wise — его
    /// адрес недокументирован и может исчезнуть без предупреждения.
    var manualOnly = false
    var parse: (Data) throws -> [String: Double] = { _ in [:] }
    /// Свой способ загрузки вместо «адрес + разбор»: получает коды валют,
    /// которые сейчас на экране, и возвращает курсы только для них.
    var fetch: (([String]) async -> [String: Double]?)? = nil

    /// Название в настройках
    var title: String { manualOnly ? name + " (beta)" : name }
}

enum RatesError: Error { case allFailed }

enum RatesService {
    /// Порядок = приоритет в режиме «Авто». Первые два — живые: обновляются
    /// раз в минуту и идут вплотную к среднерыночному курсу. Следующие три
    /// обновляются раз в сутки и остаются запасными. Номер источника + 1 —
    /// значение настройки `source`, поэтому новые добавлять только в конец
    /// (или переносить сохранённый выбор, см. `migrateSource`).
    static let sources: [RateSource] = [
        RateSource(name: "Coinbase", short: "Coinbase", colorHex: "5E35B1",
                   site: "https://www.coinbase.com",
                   urls: ["https://api.coinbase.com/v2/exchange-rates?currency=EUR"],
                   parse: { data in
            guard let o = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let d = o["data"] as? [String: Any],
                  let rates = d["rates"] as? [String: Any] else { throw RatesError.allFailed }
            return numRates(rates)
        }),
        RateSource(name: "FXRatesAPI", short: "FXRates", colorHex: "00796B",
                   site: "https://fxratesapi.com",
                   urls: ["https://api.fxratesapi.com/latest?base=EUR"],
                   parse: { data in
            // отказ (лимит, сбой) приходит с кодом 200 и success=false —
            // это ошибка источника, а не пустой набор курсов
            guard let o = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  (o["success"] as? Bool) == true,
                  let rates = o["rates"] as? [String: Any] else { throw RatesError.allFailed }
            return numRates(rates)
        }),
        RateSource(name: "ExchangeRate-API", short: "er-api", colorHex: "1565C0",
                   site: "https://www.exchangerate-api.com",
                   urls: ["https://open.er-api.com/v6/latest/EUR"],
                   parse: { data in
            guard let o = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  (o["result"] as? String) == "success",
                  let rates = o["rates"] as? [String: Any] else { throw RatesError.allFailed }
            return rates.compactMapValues { ($0 as? NSNumber)?.doubleValue }
        }),
        RateSource(name: "F.A.", short: "F.A.", colorHex: "43A047",
                   site: "https://github.com/fawazahmed0/exchange-api",
                   urls: ["https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/eur.json",
                          "https://latest.currency-api.pages.dev/v1/currencies/eur.json"],
                   parse: { data in
            guard let o = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let eur = o["eur"] as? [String: Any] else { throw RatesError.allFailed }
            var out: [String: Double] = [:]
            for (k, v) in eur { if let d = (v as? NSNumber)?.doubleValue, d > 0 { out[k.uppercased()] = d } }
            return out
        }),
        RateSource(name: "Frankfurter (ECB)", short: "ECB", colorHex: "FB8C00",
                   site: "https://frankfurter.dev",
                   urls: ["https://api.frankfurter.dev/v1/latest?base=EUR"],
                   parse: { data in
            guard let o = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let rates = o["rates"] as? [String: Any] else { throw RatesError.allFailed }
            var out = rates.compactMapValues { ($0 as? NSNumber)?.doubleValue }
            out["EUR"] = 1.0
            return out
        }),
        RateSource(name: "Wise", short: "Wise", colorHex: "546E7A",
                   site: "https://wise.com",
                   manualOnly: true,
                   fetch: { codes in await wiseRates(codes) }),
    ]

    /// Coinbase и FXRatesAPI отдают курсы строками и вперемешку с мусором:
    /// «0.8899» → число; нули, отрицательные и нечисловые значения отбрасываем.
    static func numRates(_ o: [String: Any]) -> [String: Double] {
        var out: [String: Double] = [:]
        for (k, v) in o {
            let d = (v as? NSNumber)?.doubleValue ?? (v as? String).flatMap(Double.init)
            if let d = d, d > 0, d.isFinite { out[k.uppercased()] = d }
        }
        return out
    }

    /// Загрузка по адресу. Подменяется в тестах: источники проверяются без сети.
    static var loader: (String) async throws -> Data = { url in
        var req = URLRequest(url: URL(string: url)!)
        req.timeoutInterval = 8
        req.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw RatesError.allFailed }
        return data
    }

    /// В каком порядке пробовать источники. preferred: 0 — «Авто», 1…N —
    /// этот первым, остальные резервом. Источники «только вручную» в резерв
    /// не идут: они участвуют, лишь когда выбраны сами.
    static func order(preferred: Int) -> [RateSource] {
        let auto = sources.filter { !$0.manualOnly }
        guard preferred >= 1 && preferred <= sources.count else { return auto }
        let p = sources[preferred - 1]
        return [p] + auto.filter { $0.name != p.name }
    }

    /// До 1.65 источников было три: 1 — ExchangeRate-API, 2 — F.A., 3 —
    /// Frankfurter. Теперь перед ними встали Coinbase и FXRatesAPI, и
    /// сохранённый выбор сдвигается на два — один раз, иначе у выбравшего
    /// «F.A.» молча включился бы FXRatesAPI.
    static func migrateSource(_ mode: Int, version: Int) -> Int {
        (version < 2 && (1...3).contains(mode)) ? mode + 2 : mode
    }

    /// Пробует источники по очереди. codes — валюты на экране (нужны
    /// источникам, которые отдают курсы по одной паре).
    static func fetchRates(preferred: Int, codes: [String]) async throws -> (rates: [String: Double], source: String) {
        for src in order(preferred: preferred) {
            if let fetch = src.fetch {
                if let rates = await fetch(codes), rates.count >= 2 { return (rates, src.name) }
                continue
            }
            for url in src.urls {
                if let data = try? await loader(url),
                   let rates = try? src.parse(data), rates.count >= 2 {
                    return (rates, src.name)
                }
            }
        }
        throw RatesError.allFailed
    }

    /// Wise отдаёт одну пару за запрос — спрашиваем только валюты на экране.
    static func wiseRates(_ codes: [String]) async -> [String: Double]? {
        var out: [String: Double] = ["EUR": 1]
        let wanted = Set(codes.filter { $0 != "EUR" && $0.allSatisfy { $0.isLetter || $0.isNumber } })
        await withTaskGroup(of: (String, Double?).self) { group in
            for c in wanted {
                group.addTask {
                    let d = try? await loader("https://wise.com/rates/live?source=EUR&target=\(c)")
                    return (c, d.flatMap(wiseValue))
                }
            }
            for await (c, v) in group { if let v = v { out[c] = v } }
        }
        return out.count >= 2 ? out : nil
    }

    static func wiseValue(_ data: Data) -> Double? {
        guard let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let v = (o["value"] as? NSNumber)?.doubleValue, v > 0, v.isFinite else { return nil }
        return v
    }

    /// Какая валюта в каком источнике есть (для значков в поиске)
    static func fetchSourceCodes() async -> [String: Set<String>] {
        var out: [String: Set<String>] = [:]
        if let d = try? await loader("https://open.er-api.com/v6/latest/EUR"),
           let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
           (o["result"] as? String) == "success", let r = o["rates"] as? [String: Any] {
            out["ExchangeRate-API"] = Set(r.keys)
        }
        for u in ["https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies.json",
                  "https://latest.currency-api.pages.dev/v1/currencies.json"] {
            if let d = try? await loader(u),
               let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any] {
                out["F.A."] = Set(o.keys.map { $0.uppercased() }); break
            }
        }
        if let d = try? await loader("https://api.frankfurter.dev/v1/currencies"),
           let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any] {
            out["Frankfurter (ECB)"] = Set(o.keys).union(["EUR"])
        }
        // Coinbase отдаёт 600+ кодов, большей частью мелкие крипто-токены. В
        // списке «Добавить валюту» от живых источников остаётся только то,
        // что знают справочные три: список не разбухает втрое.
        let known = out.values.reduce(into: Set<String>()) { $0.formUnion($1) }
        for src in sources.prefix(2) {
            guard let url = src.urls.first, let d = try? await loader(url),
                  let rates = try? src.parse(d), !rates.isEmpty else { continue }
            let codes = Set(rates.keys)
            out[src.name] = known.isEmpty ? codes : codes.intersection(known)
        }
        return out
    }
}
