import Foundation

/// Справочник валют (символы/названия/флаги) — из currency-data.json,
/// сгенерированного из Android-версии.
enum CurrencyData {
    struct Raw: Decodable {
        let symbols: [String: String]
        let names: [String: String]
        let flags: [String: String]
        let defaults: [String]
        let languages: [[String]]
        let rtl: [String]
    }

    static let raw: Raw = {
        guard let url = Bundle.main.url(forResource: "currency-data", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let r = try? JSONDecoder().decode(Raw.self, from: data)
        else { return Raw(symbols: [:], names: [:], flags: [:], defaults: ["EUR", "USD"], languages: [], rtl: []) }
        return r
    }()

    static func name(_ code: String) -> String { raw.names[code] ?? code }
    /// Название для показа рядом с кодом: nil, если названия нет и вышел бы
    /// дубль вида «BTC  BTC».
    static func displayName(_ code: String) -> String? { raw.names[code] }
    static func flag(_ code: String) -> String { raw.flags[code] ?? "🌐" }
    /// Флаг-эмодзи, если он есть в справочнике (у крипты и части фиата — нет).
    static func flagOrNil(_ code: String) -> String? { raw.flags[code] }
    static func symbol(_ code: String) -> String { raw.symbols[code] ?? code }
    static var defaults: [String] { raw.defaults }
    /// [(тег, родное название)] — 40 языков
    static var languages: [(String, String)] { raw.languages.compactMap { $0.count == 2 ? ($0[0], $0[1]) : nil } }
}
