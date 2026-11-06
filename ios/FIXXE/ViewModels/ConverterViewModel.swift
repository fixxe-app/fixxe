import Foundation
import SwiftUI

@MainActor
final class ConverterViewModel: ObservableObject {
    // Настройки (персист в UserDefaults)
    @Published var currencies: [String] { didSet { UserDefaults.standard.set(currencies, forKey: "currencies") } }
    @Published var decimals: Int { didSet { UserDefaults.standard.set(decimals, forKey: "decimals") } }
    @Published var sourceMode: Int { didSet { UserDefaults.standard.set(sourceMode, forKey: "source") } }
    /// разделитель разрядов: 0 — нет, 1 — пробел, 2 — запятая
    @Published var grouping: Int { didSet { UserDefaults.standard.set(grouping, forKey: "grouping") } }
    /// оформление: 0 — как в системе, 1 — светлое, 2 — тёмное
    @Published var theme: Int { didSet { UserDefaults.standard.set(theme, forKey: "theme") } }

    /// nil — отдаём решение системе
    var colorScheme: ColorScheme? {
        switch theme {
        case 1: return .light
        case 2: return .dark
        default: return nil
        }
    }
    @Published var langVersion = 0   // инкремент → перерисовка при смене языка

    // Состояние курсов
    @Published var rates: [String: Double] = [:]
    @Published var currentSource = ""
    @Published var lastUpdated = ""
    @Published var isLoading = false
    @Published var errorText: String?
    /// данные показаны из кэша (сеть недоступна)
    @Published var fromCache = false
    /// кэшу больше суток — курсы могли устареть
    @Published var stale = false

    // Активная валюта и ввод
    @Published var activeCode: String
    @Published var activeAmount: Double = 1
    @Published var inputText: String = "1"
    /// Базовая строка — та, в которой последний раз ввели число. Её сумма
    /// (`activeAmount`) ровно введённая, все остальные считаются от неё.
    /// Без поправки база и строка с курсором (`activeCode`) — одно и то же.
    /// С поправкой переход на другую строку базу не меняет: иначе процент
    /// прибавлялся бы при каждом переходе и числа уползали бы сами.
    @Published private(set) var baseCode: String = "EUR"

    // Поправка к курсу (см. RateAdjust)
    @Published private(set) var adjustPct: Double = 0
    /// «Действует постоянно»: иначе сбрасывается после 4 часов без использования
    @Published var adjustKeep: Bool = false { didSet { UserDefaults.standard.set(adjustKeep, forKey: "adjust_keep") } }
    /// Поправку только что сбросили автоматически: прежний процент — для «Вернуть»
    @Published var adjustResetFrom: Double?
    var adjusted: Bool { adjustPct != 0 }
    /// Сумма и курс этой строки пересчитаны с поправкой (все, кроме базовой)
    func isAdjusted(_ code: String) -> Bool { adjusted && code != baseCode }

    // Доступность валют по источникам
    @Published var sourceCodes: [String: Set<String>] = [:]

    init() {
        let saved = UserDefaults.standard.stringArray(forKey: "currencies")
        // для съёмки кадров магазина состав списка и источник задаются аргументами
        var list = ScreenshotArgs.currencies.isEmpty ? (saved ?? CurrencyData.defaults)
                                                     : ScreenshotArgs.currencies
        var seen = Set<String>(); list = list.filter { seen.insert($0).inserted }   // дедуп
        currencies = list
        decimals = UserDefaults.standard.integer(forKey: "decimals")
        grouping = UserDefaults.standard.integer(forKey: "grouping")
        theme = ScreenshotArgs.theme >= 0 ? ScreenshotArgs.theme
                                         : UserDefaults.standard.integer(forKey: "theme")
        // сохранённый выбор источника — один раз переносим на новую нумерацию
        var storedSource = UserDefaults.standard.integer(forKey: "source")
        let sourceVersion = UserDefaults.standard.integer(forKey: "source_v")   // 0 — до 1.65
        if sourceVersion < 2 {
            storedSource = RatesService.migrateSource(storedSource, version: sourceVersion)
            UserDefaults.standard.set(storedSource, forKey: "source")
            UserDefaults.standard.set(2, forKey: "source_v")
        }
        sourceMode = ScreenshotArgs.sourceMode >= 0 ? ScreenshotArgs.sourceMode : storedSource
        activeCode = list.first ?? "EUR"
        baseCode = activeCode
        adjustKeep = UserDefaults.standard.bool(forKey: "adjust_keep")
        adjustPct = ScreenshotArgs.adjust ?? RateAdjust.clamp(UserDefaults.standard.double(forKey: "adjust_pct"))
        resetAdjustIfExpired()   // давно не открывали — курсы снова рыночные
        if ScreenshotArgs.staleCache {
            UserDefaults.standard.set(Date().timeIntervalSince1970 - 3 * 24 * 60 * 60, forKey: "cached_at")
        }
        showCached()   // мгновенный старт с последними известными курсами
    }

    // MARK: кэш курсов
    //
    // Без сети приложение всё равно считает по последним известным курсам,
    // а если кэшу больше суток — интерфейс об этом предупреждает.

    private static let cacheAge: TimeInterval = 24 * 60 * 60

    private func cache(_ rates: [String: Double], source: String) {
        let d = UserDefaults.standard
        d.set(rates, forKey: "cached_rates")
        d.set(source, forKey: "cached_source")
        d.set(Date().timeIntervalSince1970, forKey: "cached_at")
    }

    private func showCached() {
        let d = UserDefaults.standard
        guard let cached = d.dictionary(forKey: "cached_rates") as? [String: Double],
              !cached.isEmpty else { return }
        let at = d.double(forKey: "cached_at")
        guard at > 0 else { return }
        rates = cached
        currentSource = d.string(forKey: "cached_source") ?? ""
        lastUpdated = Self.format(Date(timeIntervalSince1970: at))
        fromCache = true
        stale = Date().timeIntervalSince1970 - at > Self.cacheAge
    }

    private static func format(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "dd MMM yyyy HH:mm"
        return df.string(from: date)
    }

    // MARK: курсы

    /// Момент последнего запроса — чтобы частые нажатия «обновить» не
    /// превращались в поток обращений к источникам.
    private var lastFetchAt = Date.distantPast
    /// Курсы обновляются раз в сутки, чаще раза в 10 секунд дёргать API незачем.
    private static let minFetchInterval: TimeInterval = 10

    /// Пока шёл запрос, попросили принудительный (сменили источник) —
    /// выполним сразу после, иначе галочка новая, а курсы от старого.
    private var pendingForce = false
    /// Сколько запросов к источникам реально ушло. Видно UI-тестам через
    /// accessibilityValue кнопки «обновить» — по нему они проверяют, что
    /// нажатие действительно что-то делает.
    @Published private(set) var fetchCount = 0

    func refresh(force: Bool = false) async {
        if ScreenshotArgs.staleCache { return }   // проверяем именно состояние «кэш устарел»
        if isLoading { if force { pendingForce = true }; return }   // запрос уже идёт
        if !force, Date().timeIntervalSince(lastFetchAt) < Self.minFetchInterval { return }
        lastFetchAt = Date()
        isLoading = true; errorText = nil
        fetchCount += 1
        defer {
            isLoading = false
            if pendingForce { pendingForce = false; Task { await refresh(force: true) } }
        }
        do {
            let r = try await RatesService.fetchRates(preferred: sourceMode, codes: currencies)
            rates = r.rates; currentSource = r.source
            lastUpdated = Self.format(Date())
            fromCache = false; stale = false
            cache(r.rates, source: r.source)
        } catch {
            // сеть недоступна — остаёмся на кэше, а не показываем пустоту
            showCached()
            if rates.isEmpty { errorText = L10n.t("network_error") }
        }
    }

    func loadSourceCodes() async {
        if sourceCodes.isEmpty { sourceCodes = await RatesService.fetchSourceCodes() }
    }

    // MARK: расчёты (кросс-курс через EUR, динамическая база)

    var amountInEur: Double {
        let r = rates[baseCode] ?? 1
        return r != 0 ? activeAmount / r : 0
    }

    /// Сумма в строке: у базовой — ровно введённая, у остальных — пересчёт
    /// по курсу, умноженный на поправку.
    func converted(_ code: String) -> Double {
        if code == baseCode { return activeAmount }
        return amountInEur * (rates[code] ?? 0) * RateAdjust.factor(adjustPct)
    }

    var pivot: String { rates[baseCode] != nil ? baseCode : "EUR" }

    func rateLine(_ code: String) -> String {
        // У активной строки подписи нет: курс валюты к себе самой равен
        // единице и ничего не сообщает, а что в ней вводят — видно по рамке.
        if code == pivot { return "" }
        guard let r = rates[code], let p = rates[pivot], p != 0 else { return "" }
        return "1 \(pivot) = \(SmartFormat.rate(r / p * RateAdjust.factor(adjustPct))) \(code)"
    }

    // MARK: действия

    func setActive(_ code: String) {
        guard code != activeCode else { return }
        let shown = converted(code)
        activeCode = code
        // Без поправки строка с курсором сразу становится базой — как было
        // всегда. С поправкой база остаётся прежней, пока в новой строке не
        // наберут число: суммы при переходах не меняются.
        if !adjusted { activeAmount = shown; baseCode = code }
        inputText = SmartFormat.amount(shown, decimals: decimals)   // в поле ввода без группировки
    }

    func inputChanged(_ text: String) {
        // TextField сообщает об изменении и тогда, когда текст подставили мы
        // сами — при переключении строки. На Mac это происходит всегда, и если
        // принять такой «ввод» за настоящий, точная сумма заменится показанной,
        // округлённой: 1,1239 станет 1,13. Переключился туда-обратно пару раз —
        // и числа уползли, хотя ничего не вводили.
        guard text != inputText else { return }
        inputText = text
        baseCode = activeCode             // настоящий ввод: эта строка теперь база
        activeAmount = SmartFormat.parse(text, grouping: grouping)
    }

    func clearAll() {
        baseCode = activeCode
        activeAmount = 0
        inputText = "0"
    }

    // MARK: поправка к курсу

    func setAdjust(_ pct: Double) {
        let v = RateAdjust.clamp(pct)
        adjustResetFrom = nil
        guard v != adjustPct else { return }
        returnCursorToBase()
        adjustPct = v
        UserDefaults.standard.set(v, forKey: "adjust_pct")
        markUsed()        // 4 часа считаются от последнего использования, включая саму настройку
    }

    /// Курсор — на базовую строку: её число не пересчитано, и смена процента
    /// не должна менять то, что человек сейчас редактирует.
    private func returnCursorToBase() {
        guard activeCode != baseCode else { return }
        activeCode = baseCode
        inputText = SmartFormat.amount(activeAmount, decimals: decimals)
    }

    /// Приложение ушло с экрана (или им только что пользовались)
    func markUsed() { UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "adjust_left_at") }

    /// Вызывается при запуске и при возврате на экран
    func resetAdjustIfExpired(now: TimeInterval = Date().timeIntervalSince1970) {
        // поправка, заданная параметром запуска (тесты, кадры), отметки времени не имеет
        guard ScreenshotArgs.adjust == nil else { return }
        let left = UserDefaults.standard.double(forKey: "adjust_left_at")
        guard RateAdjust.shouldReset(pct: adjustPct, keep: adjustKeep, leftAt: left, now: now) else { return }
        let old = adjustPct
        returnCursorToBase()
        adjustPct = 0
        UserDefaults.standard.set(0.0, forKey: "adjust_pct")
        adjustResetFrom = old             // сброс не молчаливый: сообщение с «Вернуть»
    }

    /// Выбран источник, который отдаёт курсы только для валют на экране (Wise).
    private var activeIsOnDemand: Bool {
        (1...RatesService.sources.count).contains(sourceMode) && RatesService.sources[sourceMode - 1].fetch != nil
    }

    /// Можно ли добавить валюту, не меняя источник. У источника «по запросу»
    /// курса новой валюты ещё нет — он появится после добавления; такие
    /// источники знают обычные валюты (список — как у ExchangeRate-API).
    func isAvailableNow(_ code: String) -> Bool {
        rates[code] != nil || (activeIsOnDemand && (sourceCodes["ExchangeRate-API"]?.contains(code) ?? false))
    }

    func add(_ code: String) {
        guard !currencies.contains(code) else { return }
        currencies.append(code)
        // источник «по запросу» курса этой валюты ещё не спрашивал
        if activeIsOnDemand, rates[code] == nil { Task { await refresh(force: true) } }
    }

    func remove(_ code: String) {
        guard currencies.count > 2 else { return }
        currencies.removeAll { $0 == code }
        if baseCode == code, let f = currencies.first {
            // Удалили базовую строку: базой становится первая — с той суммой,
            // что в ней показана. Сначала перевод, потом смена базы:
            // converted() считает от baseCode, и в обратном порядке пересчёт
            // превращался в пустой — 100 USD после удаления USD становились 100 EUR.
            let amount = converted(f)
            baseCode = f
            activeCode = f
            activeAmount = amount
            inputText = SmartFormat.amount(amount, decimals: decimals)
        } else if activeCode == code {
            // удалили строку с курсором, база цела — курсор возвращается на неё
            returnCursorToBase()
        }
    }

    func move(from: IndexSet, to: Int) { currencies.move(fromOffsets: from, toOffset: to) }

    /// Перестановка перетаскиванием: код `dragged` встаёт на место кода `target`.
    func move(_ dragged: String, before target: String) {
        guard dragged != target,
              let from = currencies.firstIndex(of: dragged),
              let to = currencies.firstIndex(of: target) else { return }
        withAnimation {
            currencies.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        }
    }

    // Какие источники (номера в RatesService.sources) содержат код.
    // Источники «только вручную» сюда не входят: ни значка, ни предложения
    // переключиться на них в списке валют нет.
    func sourcesWith(_ code: String) -> [Int] {
        RatesService.sources.enumerated().compactMap { i, s in
            (!s.manualOnly && (sourceCodes[s.name]?.contains(code) ?? false)) ? i : nil
        }
    }

    /// Что можно добавить. Курсы живых источников содержат сотни кодов сверх
    /// списков (Coinbase — 600+ крипто-токенов), поэтому в перечень идут сами
    /// списки; пока они не загрузились — то, что есть в текущих курсах.
    var allCodesUnion: [String] {
        if sourceCodes.isEmpty { return rates.keys.sorted() }
        return sourceCodes.values.reduce(into: Set<String>()) { $0.formUnion($1) }.sorted()
    }

    func switchSourceAndAdd(_ code: String, sourceIdx: Int) async {
        sourceMode = sourceIdx + 1
        add(code)
        await refresh(force: true)
    }
}
