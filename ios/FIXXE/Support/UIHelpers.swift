import SwiftUI

extension Color {
    init(hex: String) {
        var v: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&v)
        self.init(red: Double((v >> 16) & 0xFF) / 255,
                  green: Double((v >> 8) & 0xFF) / 255,
                  blue: Double(v & 0xFF) / 255)
    }

    /// Цвет, который сам меняется вместе с темой: первый — для светлой, второй — для тёмной.
    /// Фон в тёмной теме не чёрный, а тёмно-серый: на OLED чистый чёрный даёт резкие
    /// границы карточек. Синий и зелёный осветлены — исходные на тёмном не проходят
    /// по контрасту.
    static func adaptive(_ light: String, _ dark: String) -> Color {
        Color(UIColor { traits in
            UIColor(Color(hex: traits.userInterfaceStyle == .dark ? dark : light))
        })
    }

    // Вспомогательный текст не бледнее 4.5:1 к фону, значки — 3:1 (WCAG AA;
    // проверка — tools/check-contrast.py). Раньше строка курса была 2.3:1.
    static let brandBlue  = adaptive("1565C0", "64B5F6")
    static let brandGreen = adaptive("2E7D32", "81C784")
    static let bgGray     = adaptive("F2F3F5", "121212")   // фон экрана
    static let surface    = adaptive("FFFFFF", "1E1E1E")   // карточки и панели
    static let badgeBg    = adaptive("E8EEF9", "1B2A3A")   // плашка со счётчиком
    static let staleRed   = adaptive("C93E14", "FF8A65")   // предупреждение об устаревших курсах
    static let staleBrown = adaptive("86685E", "BCAAA4")
    static let faint      = adaptive("898D92", "696969")   // крестик и ручка перетаскивания
    static let muted      = adaptive("687074", "78909C")
    static let hairline   = adaptive("DDDDDD", "3A3A3A")   // рамка чипа
    static let onAccent   = adaptive("FFFFFF", "0B0B0B")   // текст на залитом чипе
    static let chipOn     = adaptive("455A64", "37474F")   // залитый чип «Все источники»
    static let addedGreen = adaptive("43A047", "81C784")   // галочка «уже добавлена»
    static let textFaint  = adaptive("6E6E6E", "8C8C8C")   // строка курса под суммой
    static let textDim    = adaptive("6E6E6E", "858585")   // подпись версии в подвале
    static let chipText   = adaptive("555555", "B4B4B4")   // текст незалитого чипа
}

enum AppInfo {
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
}

/// Аргументы запуска для автоматической съёмки скриншотов магазина.
/// Только в DEBUG — в релизной сборке всегда «пусто».
enum ScreenshotArgs {
#if DEBUG
    private static var args: [String] { ProcessInfo.processInfo.arguments }
    static var openAdd: Bool { args.contains("-screen-add") }
    static var openSettings: Bool { args.contains("-screen-settings") }
    static var openInfo: Bool { args.contains("-screen-info") }
    /// состарить кэш курсов, чтобы проверить предупреждение об устаревших данных
    static var staleCache: Bool { args.contains("-stale-cache") }
    static var initialQuery: String {
        guard let i = args.firstIndex(of: "-screen-query"), i + 1 < args.count else { return "" }
        return args[i + 1]
    }
    /// индекс источника для чипа-фильтра, -1 = «все»
    static var initialFilter: Int {
        guard let i = args.firstIndex(of: "-screen-filter"), i + 1 < args.count else { return -1 }
        return Int(args[i + 1]) ?? -1
    }
    /// состав списка для кадра: коды через запятую (иначе сохранённый/дефолтный)
    static var currencies: [String] {
        guard let i = args.firstIndex(of: "-screen-currencies"), i + 1 < args.count else { return [] }
        return args[i + 1].split(separator: ",").map(String.init)
    }
    /// язык интерфейса для кадра (код вроде "ru"); пусто — не трогать
    static var lang: String {
        guard let i = args.lastIndex(of: "-screen-lang"), i + 1 < args.count else { return "" }
        return args[i + 1]
    }
    /// оформление для кадра: 0 — как в системе, 1 — светлое, 2 — тёмное (-1 = не трогать)
    static var theme: Int {
        guard let i = args.firstIndex(of: "-screen-theme"), i + 1 < args.count else { return -1 }
        return Int(args[i + 1]) ?? -1
    }
    /// источник курсов: 0 — авто, 1..3 — конкретный (-1 = не трогать)
    static var sourceMode: Int {
        guard let i = args.firstIndex(of: "-screen-source"), i + 1 < args.count else { return -1 }
        return Int(args[i + 1]) ?? -1
    }
#else
    static var openAdd: Bool { false }
    static var openSettings: Bool { false }
    static var openInfo: Bool { false }
    static var staleCache: Bool { false }
    static var initialQuery: String { "" }
    static var initialFilter: Int { -1 }
    static var currencies: [String] { [] }
    static var sourceMode: Int { -1 }
    static var theme: Int { -1 }
    static var lang: String { "" }
#endif
}

extension View {
    /// Ограничивает содержимое читаемой шириной и центрирует его.
    /// На iPhone ничего не меняет (экран уже уже лимита), на iPad не даёт
    /// строкам растянуться через весь 13" экран.
    func readableWidth(_ limit: CGFloat = 640) -> some View {
        frame(maxWidth: limit).frame(maxWidth: .infinity)
    }
}

extension View {
    /// scrollContentBackground(.hidden) появился в iOS 16; на iOS 15 фон
    /// List чистится через UITableView.appearance() (см. FIXXEApp.init)
    @ViewBuilder func compatHideListBackground() -> some View {
        if #available(iOS 16.0, *) {
            self.scrollContentBackground(.hidden)
        } else {
            self
        }
    }
}
