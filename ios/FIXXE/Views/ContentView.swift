import SwiftUI

struct ContentView: View {
    // модель создаётся в FIXXEApp — ей же нужен выбор оформления
    @ObservedObject var vm: ConverterViewModel
    @Environment(\.scenePhase) private var scenePhase
    // «Уменьшить движение» в Универсальном доступе: значок не крутим, а приглушаем
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focusedCode: String?
    @State private var showClearConfirm = false
    @State private var spin: Double = 0

    @State private var showAdd = false
    @State private var showSettings = false
    @State private var showInfo = false
    @State private var showAdjust = false
    @State private var deleteCandidate: String?
    /// Отдельный флаг для подтверждения удаления. Раньше алерт открывался
    /// вычисляемым Binding на deleteCandidate, которое тело экрана не читает, —
    /// на iOS 15 крестик ничего не показывал.
    @State private var showDeleteConfirm = false
    @State private var dragged: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            brandRow
            adjustStrip
            currencyList
            footer
        }
        .background(Color.bgGray)
        .environment(\.layoutDirection, L10n.isRTL ? .rightToLeft : .leftToRight)
        .id(vm.langVersion)   // смена языка → полная перерисовка
        .task {
            await vm.refresh()
            await vm.loadSourceCodes()
            if ScreenshotArgs.openAdd { showAdd = true }
            if ScreenshotArgs.openSettings { showSettings = true }
            if ScreenshotArgs.openInfo { showInfo = true }
        }
        // Курсы обновляются и пока приложение открыто: при возврате из фона
        // и раз в 30 минут — как на Android. Без этого на Mac, где окно может
        // висеть сутками, курсы так и оставались от момента запуска.
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                vm.resetAdjustIfExpired()      // давно не открывали — поправка снята
                vm.resetAmountIfExpired()      // и сумма снова 1, если так выбрано
                Task { await vm.refresh() }
            } else {
                vm.markUsed()                  // отсюда считаются 4 часа до сброса поправки
            }
        }
        // включение и сброс поправки экранный диктор произносит вслух
        .onChange(of: vm.adjusted) { on in
            UIAccessibility.post(notification: .announcement,
                                 argument: L10n.t(on ? "adjusted_rates" : "market_rate"))
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30 * 60 * 1_000_000_000)
                await vm.refresh()
            }
        }
        .sheet(isPresented: $showAdd) { AddCurrencyView(vm: vm) }
        .sheet(isPresented: $showSettings) { SettingsView(vm: vm) }
        .sheet(isPresented: $showInfo) {
            // процент в тексте справки изолирован слева направо (U+2066…U+2069): в арабском
            // и иврите знак «+» иначе уезжает за число
            SourceInfoView(adjustLabel: vm.adjusted ? "\u{2066}" + RateAdjust.label(vm.adjustPct) + "\u{2069}" : nil) {
                showInfo = false
                // второй лист можно открыть, только когда первый закрылся
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { showAdjust = true }
            }
        }
        .sheet(isPresented: $showAdjust) { AdjustSheet(vm: vm) }
        .alert(L10n.t("clear_confirm_title"), isPresented: $showClearConfirm) {
            Button(L10n.t("clear"), role: .destructive) { vm.clearAll() }
            Button(L10n.t("cancel"), role: .cancel) { }
        } message: {
            Text(L10n.t("clear_confirm_msg"))
        }
    }

    /// Короткое имя источника для строки статуса.
    /// В шапке мало места: полное «ExchangeRate-API» вытесняет дату, и строка
    /// обрывается многоточием — не видно ни источника, ни времени. В настройках,
    /// где источник выбирают, имена остаются полными. Дефис неразрывный, чтобы
    /// короткое имя не переносилось по нему на две строки.
    private func shortSource(_ s: String) -> String {
        switch s {
        case "FXRatesAPI":        return "FXR\u{2011}API"
        case "ExchangeRate-API":  return "ER\u{2011}API"
        case "Frankfurter (ECB)": return "Fra.ECB"
        default:                  return s      // «F.A.», «Coinbase», «Wise» уже короткие
        }
    }

    /// Подпись внизу — только у ExchangeRate-API: дословная и со ссылкой, это
    /// условие их бесплатного тарифа. Остальные источники названы вверху.
    private var showsAttribution: Bool { vm.currentSource == "ExchangeRate-API" }

    /// Источник для строки вверху. ExchangeRate-API там не называем никогда:
    /// у него своя подпись внизу.
    private var statusSource: String { showsAttribution ? "" : shortSource(vm.currentSource) }

    /// Строки «офлайн» и «устарели» кончаются на « · источник» — без источника
    /// хвост убираем.
    private func noSrc(_ s: String) -> String {
        guard statusSource.isEmpty else { return s }
        var t = s.trimmingCharacters(in: .whitespaces)
        if t.hasSuffix("·") { t.removeLast() }
        return t.trimmingCharacters(in: .whitespaces)
    }

    /// Строка не должна начинаться с разделителя «·» — привязываем его к слову слева.
    private func tidy(_ s: String) -> String {
        s.replacingOccurrences(of: " · ", with: "\u{00A0}· ")
    }

    /// Значок «i» в конце строки статуса: она нажимается.
    private var infoMark: Text { Text("\u{00A0}") + Text(Image(systemName: "info.circle")) }

    private var header: some View {
        HStack(spacing: 8) {
            Button { showSettings = true } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 21, weight: .regular))
                    .foregroundColor(.secondary)
                    .frame(width: 44, height: 44)   // зона нажатия под палец
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(L10n.t("settings"))   // без подписи VoiceOver читал имя символа
            .accessibilityIdentifier("settings")
            .padding(.trailing, 4)       // иначе значки стоят вплотную
            Button { Task { await vm.refresh() } } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 21, weight: .regular))
                    .foregroundColor(.secondary)
                    // идёт запрос — крутим сам значок, отдельного индикатора нет
                    .rotationEffect(.degrees(reduceMotion ? 0 : spin))
                    .opacity(reduceMotion && vm.isLoading ? 0.4 : 1)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityIdentifier("refresh")
            .accessibilityLabel(L10n.t("refresh"))
            .accessibilityValue("\(vm.fetchCount)")
            .onChange(of: vm.isLoading) { loading in
                if loading {
                    withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                        spin = 360
                    }
                } else {
                    withAnimation(.linear(duration: 0.2)) { spin = 0 }
                }
            }
            .padding(.trailing, 4)
            // «Рыночный курс · 13:11 · источник ⓘ». Нажатие — пояснение о курсах
            // (раньше это была отдельная ссылка внизу). Счётчика валют больше нет.
            Button { if !vm.lastUpdated.isEmpty { showInfo = true } } label: {
                Group {
                    if let e = vm.errorText { Text("⚠ \(e)").foregroundColor(.secondary) }
                    else if vm.lastUpdated.isEmpty { Text(L10n.t("loading")).foregroundColor(.secondary) }
                    else if vm.stale {
                        // кэшу больше суток — предупреждаем заметно
                        (Text(tidy(noSrc(L10n.t("rates_stale", vm.lastUpdated, statusSource)))) + infoMark)
                            .foregroundColor(Color.staleRed)
                    } else if vm.fromCache {
                        (Text(tidy(noSrc(L10n.t("rates_offline", vm.lastUpdated, statusSource)))) + infoMark)
                            .foregroundColor(Color.staleBrown)
                    } else {
                        // с поправкой курсы уже не рыночные — строка говорит правду
                        (Text(tidy([L10n.t(vm.adjusted ? "adjusted_rates" : "market_rate"), vm.lastUpdated, statusSource]
                                    .filter { !$0.isEmpty }.joined(separator: " · "))) + infoMark)
                            .fontWeight(vm.adjusted ? .semibold : .regular)
                            .foregroundColor(vm.adjusted ? Color.adjusted : .secondary)
                    }
                }
                .font(.caption)
                .multilineTextAlignment(.leading)
                // при самом крупном шрифте статус не расползается на пять строк
                .lineLimit(4).minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("rates-info")
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .readableWidth()
        .background(Color.surface)
    }

    /// Полоса под строкой бренда. Пока поправка включена, закрыть её нельзя:
    /// человек не должен принять пересчитанный курс за рыночный — ни сразу,
    /// ни вернувшись через час. Сам процент здесь не показывается. После
    /// автоматического сброса на этом месте — сообщение с «Вернуть»: менять
    /// цифры молча нельзя.
    @ViewBuilder private var adjustStrip: some View {
        if vm.adjusted {
            Button { focusedCode = nil; showAdjust = true } label: {
                HStack(spacing: 8) {
                    PercentBadge(size: 18)
                    Text(L10n.t("adjusted_rates"))
                        .font(.footnote.weight(.semibold))
                        .lineLimit(1).minimumScaleFactor(0.85)
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.forward").font(.footnote.weight(.semibold))
                }
                .foregroundColor(.adjusted)
                .padding(.horizontal, 14)
                .frame(minHeight: 40)
                .readableWidth()
                .background(Color.adjustedBg)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.t("adjusted_rates"))
            .accessibilityHint(L10n.t("adjust_title"))
            .accessibilityIdentifier("adjust-banner")
        } else if let old = vm.adjustResetFrom {
            HStack(spacing: 8) {
                Text(L10n.t("adjust_reset_notice"))
                    .font(.footnote).foregroundColor(.primary)
                    .lineLimit(2).minimumScaleFactor(0.85)
                Spacer(minLength: 4)
                Button(L10n.t("adjust_undo")) { vm.setAdjust(old) }
                    .font(.footnote.weight(.semibold)).foregroundColor(.brandBlue)
                    .accessibilityIdentifier("adjust-undo")
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 40)
            .readableWidth()
            .background(Color.surface)
            .accessibilityIdentifier("adjust-reset-notice")
            .task(id: old) {
                try? await Task.sleep(nanoseconds: 8_000_000_000)
                if vm.adjustResetFrom == old { vm.adjustResetFrom = nil }
            }
        }
    }

    private var brandRow: some View {
        ZStack {
            Image("LogoMini").resizable().scaledToFit().frame(height: 34)
            HStack {
                Text("FIXXE")
                    .font(.subheadline.bold()).kerning(1.5)
                    .foregroundColor(.brandGreen)
                Spacer()
                // На iOS 15 панель над клавиатурой (ToolbarItemGroup .keyboard) не
                // появляется без NavigationView, поэтому убрать цифровую клавиатуру
                // там было нечем. Своя кнопка в шапке работает на любой версии.
                if focusedCode != nil {
                    Button { focusedCode = nil } label: {
                        Image(systemName: "keyboard.chevron.compact.down")
                    }
                    .foregroundColor(.brandBlue)
                    .accessibilityLabel(L10n.t("close"))
                    .accessibilityIdentifier("dismiss-keyboard-header")
                    .padding(.trailing, 12)
                }
                Button(L10n.t("clear")) {
                    focusedCode = nil
                    showClearConfirm = true
                }
                .font(.subheadline).foregroundColor(.brandBlue)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 4)
        .readableWidth()
        .background(Color.surface)
    }

    private var currencyList: some View {
        // Не List: он перехватывает drag & drop и отдаёт перестановку только
        // своему .onMove, который работает лишь в режиме редактирования.
        // На VStack перетаскивание за ручку работает сразу, как в Android.
        //
        // Не LazyVStack: ленивый список на iOS 15 снимает с экрана строки,
        // которые накрыла выезжающая клавиатура, — вместе с полем ввода. Поле
        // теряло фокус, клавиатура тут же уезжала: в двух нижних строках ввод
        // не открывался вовсе. Валют на экране десятки, а не тысячи — держать
        // все строки живыми ничего не стоит.
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(vm.currencies, id: \.self) { code in
                        CurrencyRowView(vm: vm, code: code, focusedCode: $focusedCode,
                                        dragged: $dragged, onDelete: {
                                            focusedCode = nil        // клавиатура не мешает алерту
                                            deleteCandidate = code
                                            showDeleteConfirm = true
                                        })
                        .id(code)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                // после клавиатуры список встаёт туда, где был до неё
                .background(KeyboardScrollRestore().allowsHitTesting(false))
            }
            // Строку ввода — над клавиатурой. Новые iOS делают это сами,
            // iOS 15 — не всегда, и строка оставалась под клавиатурой.
            .onReceive(NotificationCenter.default.publisher(
                for: UIResponder.keyboardDidShowNotification)) { _ in
                guard let code = focusedCode else { return }
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { proxy.scrollTo(code) }
            }
        }
        .readableWidth()
        .alert(L10n.t("delete_currency_title"), isPresented: $showDeleteConfirm,
               presenting: deleteCandidate) { c in
            Button(L10n.t("delete"), role: .destructive) { vm.remove(c) }
            Button(L10n.t("cancel"), role: .cancel) { }
        } message: { c in
            Text(L10n.t("delete_currency_msg", c, CurrencyData.name(c)))
        }
        .background(
            // тап по фону — ещё один способ убрать клавиатуру
            Color.bgGray.onTapGesture { focusedCode = nil }
        )
    }

    /// Подвал — одна строка: «＋ Добавить валюту» и, только у ExchangeRate-API, их
    /// подпись со ссылкой. Номер версии — в настройках.
    private var footer: some View {
        HStack(spacing: 8) {
            Button { showAdd = true } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus").font(.subheadline)
                    Text(L10n.t("add_currency"))
                }
                .frame(minHeight: 44)
            }
            .font(.subheadline).foregroundColor(.brandBlue)
            Spacer(minLength: 4)
            if showsAttribution {
                Link(L10n.t("attribution"), destination: URL(string: "https://www.exchangerate-api.com")!)
                    .font(.caption2).foregroundColor(Color.muted)
                    .lineLimit(1)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("attribution")
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 4)
        .readableWidth()
        .background(Color.surface)
    }
}
