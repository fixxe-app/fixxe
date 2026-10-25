import Foundation

/// Источники курсов: та же цепочка фоллбэка, что в Android/PWA.
/// er-api → F.A. (jsDelivr → pages.dev) → Frankfurter (ECB). База EUR.
struct RateSource {
    let name: String
    let short: String
    let colorHex: String
    let urls: [String]
    let parse: (Data) throws -> [String: Double]
}

enum RatesError: Error { case allFailed }

enum RatesService {
    static let sources: [RateSource] = [
        RateSource(name: "ExchangeRate-API", short: "er-api", colorHex: "1565C0",
                   urls: ["https://open.er-api.com/v6/latest/EUR"]) { data in
            guard let o = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  (o["result"] as? String) == "success",
                  let rates = o["rates"] as? [String: Any] else { throw RatesError.allFailed }
            return rates.compactMapValues { ($0 as? NSNumber)?.doubleValue }
        },
        RateSource(name: "F.A.", short: "F.A.", colorHex: "43A047",
                   urls: ["https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/eur.json",
                          "https://latest.currency-api.pages.dev/v1/currencies/eur.json"]) { data in
            guard let o = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let eur = o["eur"] as? [String: Any] else { throw RatesError.allFailed }
            var out: [String: Double] = [:]
            for (k, v) in eur { if let d = (v as? NSNumber)?.doubleValue, d > 0 { out[k.uppercased()] = d } }
            return out
        },
        RateSource(name: "Frankfurter (ECB)", short: "ECB", colorHex: "FB8C00",
                   urls: ["https://api.frankfurter.dev/v1/latest?base=EUR"]) { data in
            guard let o = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let rates = o["rates"] as? [String: Any] else { throw RatesError.allFailed }
            var out = rates.compactMapValues { ($0 as? NSNumber)?.doubleValue }
            out["EUR"] = 1.0
            return out
        },
    ]

    private static func get(_ url: String) async throws -> Data {
        var req = URLRequest(url: URL(string: url)!)
        req.timeoutInterval = 8
        req.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw RatesError.allFailed }
        return data
    }

    /// Пробует источники по очереди. preferred: 0=авто, 1..3 — этот первым (остальные резерв).
    static func fetchRates(preferred: Int) async throws -> (rates: [String: Double], source: String) {
        var ordered = sources
        if preferred >= 1 && preferred <= sources.count {
            let p = sources[preferred - 1]
            ordered = [p] + sources.enumerated().filter { $0.offset != preferred - 1 }.map { $0.element }
        }
        for src in ordered {
            for url in src.urls {
                if let data = try? await get(url),
                   let rates = try? src.parse(data), rates.count >= 2 {
                    return (rates, src.name)
                }
            }
        }
        throw RatesError.allFailed
    }

    /// Какая валюта в каком источнике есть (для значков в поиске)
    static func fetchSourceCodes() async -> [String: Set<String>] {
        var out: [String: Set<String>] = [:]
        if let d = try? await get("https://open.er-api.com/v6/latest/EUR"),
           let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
           (o["result"] as? String) == "success", let r = o["rates"] as? [String: Any] {
            out["ExchangeRate-API"] = Set(r.keys)
        }
        for u in ["https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies.json",
                  "https://latest.currency-api.pages.dev/v1/currencies.json"] {
            if let d = try? await get(u),
               let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any] {
                out["F.A."] = Set(o.keys.map { $0.uppercased() }); break
            }
        }
        if let d = try? await get("https://api.frankfurter.dev/v1/currencies"),
           let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any] {
            out["Frankfurter (ECB)"] = Set(o.keys).union(["EUR"])
        }
        return out
    }
}
