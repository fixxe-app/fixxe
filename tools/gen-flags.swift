// Генерирует мапу FLAGS для CurrencyViewModel.kt — единого источника данных
// для Android, PWA и iOS.
//
// Вручную было прописано 68 флагов, остальные валюты показывали глобус.
// Здесь флаг выводится из кода валюты: первые две буквы ISO-4217 почти всегда
// совпадают с кодом страны ISO-3166 (RSD → RS, GEL → GE, AOA → AO).
//
// Три страховки от «мусорных» флагов:
//   1. только коды из ISO-4217 — крипта туда не входит, иначе BTC получил бы
//      флаг Бутана (BT), а ETH — Эфиопии (ET);
//   2. первые две буквы обязаны быть действующим регионом ISO-3166 — отсекает
//      XAU/XDR (золото, СПЗ) и упразднённые вроде ANG → AN;
//   3. пара regional indicator обязана давать ОДИН глиф в Apple Color Emoji —
//      то есть флаг реально существует, а не распадается на две буквы.
//
// Ручные записи имеют приоритет: EUR → 🇪🇺 таким способом не вывести.
//
// Запуск: swift tools/gen-flags.swift  (печатает готовый блок Kotlin)

import AppKit
import Foundation

// уже прописанные вручную — их не трогаем
let manual: [String: String] = {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    let url = root.appendingPathComponent("ios/FIXXE/Resources/currency-data.json")
    struct Raw: Decodable { let flags: [String: String] }
    guard let d = try? Data(contentsOf: url),
          let r = try? JSONDecoder().decode(Raw.self, from: d) else { return [:] }
    return r.flags
}()

let regions = Set(Locale.isoRegionCodes)
let font = CTFontCreateWithName("Apple Color Emoji" as CFString, 24, nil)

/// один ли глиф даёт эмодзи — значит флаг в шрифте есть
func isSingleGlyph(_ s: String) -> Bool {
    let attr = NSAttributedString(string: s, attributes: [.font: font])
    let line = CTLineCreateWithAttributedString(attr)
    let runs = CTLineGetGlyphRuns(line) as! [CTRun]
    guard runs.count == 1 else { return false }
    return CTRunGetGlyphCount(runs[0]) == 1
}

func flag(forRegion cc: String) -> String {
    String(String.UnicodeScalarView(cc.unicodeScalars.compactMap {
        UnicodeScalar(0x1F1E6 + ($0.value - UnicodeScalar("A").value))
    }))
}

var derived: [String: String] = [:]
for code in Locale.isoCurrencyCodes where manual[code] == nil {
    guard code.count == 3 else { continue }
    let cc = String(code.prefix(2)).uppercased()
    guard regions.contains(cc) else { continue }
    let emoji = flag(forRegion: cc)
    guard isSingleGlyph(emoji) else { continue }
    derived[code] = emoji
}

let all = manual.merging(derived) { a, _ in a }
print("// всего \(all.count) флагов: \(manual.count) вручную + \(derived.count) выведено из кода валюты")
print("        val FLAGS = mapOf(")
var line = "           "
var parts: [String] = []
for code in all.keys.sorted() { parts.append("\"\(code)\" to \"\(all[code]!)\"") }
for (i, p) in parts.enumerated() {
    let piece = p + (i == parts.count - 1 ? "" : ",")
    if line.count + piece.count > 92 { print(line); line = "           " }
    line += " " + piece
}
if !line.trimmingCharacters(in: .whitespaces).isEmpty { print(line) }
print("        )")
FileHandle.standardError.write("derived \(derived.count), total \(all.count)\n".data(using: .utf8)!)
