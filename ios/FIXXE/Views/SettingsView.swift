import SwiftUI

/// Настройки — одно окно на всех платформах: название слева, значение справа,
/// каждый пункт открывает свой выбор. Поправка к курсу — отдельно, последней,
/// цветом сумм с поправкой. Внизу мелко — номер версии (нажатие копирует).
struct SettingsView: View {
    @ObservedObject var vm: ConverterViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    private var themeOptions: [String] { ["theme_system", "theme_light", "theme_dark"].map { L10n.t($0) } }
    private var precisionValues: [Int] { [0, 1, 2, 4] }
    private var groupingOptions: [String] { ["group_none", "group_space", "group_comma"].map { L10n.t($0) } }
    private var memoryOptions: [String] { AmountMemory.labelKeys.map { L10n.t($0) } }
    private var sourceLabel: String {
        vm.sourceMode == 0 ? L10n.t("source_auto")
            : RatesService.sources.indices.contains(vm.sourceMode - 1) ? RatesService.sources[vm.sourceMode - 1].title : L10n.t("source_auto")
    }
    private var languageLabel: String {
        if L10n.chosenLang == L10n.systemTag { return L10n.t("language_system") }
        let tag = L10n.chosenLang ?? "en"
        return CurrencyData.languages.first { $0.0 == tag }?.1 ?? tag
    }
    private var adjustLabel: String {
        vm.adjusted ? "\u{2066}" + RateAdjust.label(vm.adjustPct) + "\u{2069}" : L10n.t("adjust_off")
    }

    private func row<Page: View>(_ id: String, _ label: String, _ value: String, color: Color? = nil,
                                 @ViewBuilder page: @escaping () -> Page) -> some View {
        NavigationLink(destination: LazyView(page)) {
            HStack {
                Text(label).foregroundColor(color ?? .primary)
                Spacer(minLength: 12)
                Text(value).foregroundColor(color ?? .secondary).multilineTextAlignment(.trailing).lineLimit(2)
            }
        }
        .accessibilityIdentifier(id)
    }

    var body: some View {
        NavigationView {
            List {
                Section {
                    row("set-theme", L10n.t("theme_title"), themeOptions[min(max(vm.theme, 0), 2)]) {
                        ChoicePage(title: L10n.t("theme_title"), options: themeOptions, selected: vm.theme, idPrefix: "theme") { vm.theme = $0 }
                    }
                    row("set-precision", L10n.t("precision_title"), vm.decimals == 0 ? L10n.t("precision_value_int") : L10n.t("precision_value_n", vm.decimals)) {
                        ChoicePage(title: L10n.t("precision_title"), options: precisionValues.map(precisionLabel),
                                   selected: precisionValues.firstIndex(of: vm.decimals) ?? 0, idPrefix: "precision") { vm.decimals = precisionValues[$0] }
                    }
                    row("set-rounding", L10n.t("rounding_title"), L10n.t(vm.roundUp ? "rounding_up" : "rounding_nearest")) {
                        ChoicePage(title: L10n.t("rounding_title"), options: [L10n.t("rounding_up"), L10n.t("rounding_nearest")],
                                   selected: vm.roundUp ? 0 : 1, idPrefix: "rounding",
                                   details: roundingExamples, footer: L10n.t("rounding_hint")) { vm.roundUp = $0 == 0 }
                    }
                    row("set-grouping", L10n.t("grouping_title"), groupingOptions[min(max(vm.grouping, 0), 2)]) {
                        ChoicePage(title: L10n.t("grouping_title"), options: groupingOptions, selected: vm.grouping, idPrefix: "grouping") { vm.grouping = $0 }
                    }
                    row("set-memory", L10n.t("amount_memory_title"), memoryOptions[min(max(vm.amountMemory, 0), 3)]) {
                        ChoicePage(title: L10n.t("amount_memory_title"), options: memoryOptions, selected: vm.amountMemory,
                                   idPrefix: "memory", footer: L10n.t("amount_memory_hint")) { vm.amountMemory = $0 }
                    }
                    row("set-source", L10n.t("source_title"), sourceLabel) { SourcePage(vm: vm) }
                    row("set-language", L10n.t("language_title"), languageLabel) { LanguagePage(vm: vm) }
                }
                Section {
                    row("set-adjust", L10n.t("adjust_title"), adjustLabel, color: .adjusted) {
                        List { AdjustSection(vm: vm) }
                            .navigationTitle(L10n.t("adjust_title"))
                            .navigationBarTitleDisplayMode(.inline)
                    }
                } footer: {
                    Button {
                        UIPasteboard.general.string = "FIXXE " + AppInfo.version
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                    } label: {
                        Text(copied ? L10n.t("copied") : L10n.t("version_label", AppInfo.version))
                            .font(.caption2).foregroundColor(Color.textDim)
                            .frame(maxWidth: .infinity, minHeight: 36)
                    }
                    .accessibilityIdentifier("set-version")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(L10n.t("settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button(L10n.t("close")) { dismiss() }.accessibilityIdentifier("settings-close") }
        }
        .navigationViewStyle(.stack)
        .id(vm.langVersion)
    }

    /// Пример под каждым вариантом округления: сумма первой валюты во второй.
    private var roundingExamples: [String]? {
        let shown = vm.currencies.filter { vm.rates[$0] != nil }
        guard shown.count >= 2, let a = vm.rates[shown[0]], let b = vm.rates[shown[1]], a > 0 else { return nil }
        func fmt(_ v: Double, _ up: Bool) -> String { SmartFormat.amount(v, decimals: vm.decimals, grouping: vm.grouping, roundUp: up) }
        // первая сумма от 100, на которой способы дают разное: при «круглом»
        // курсе на 100 оба показали бы одно и то же число
        let base = (100..<200).first { n in let v = Double(n) * b / a; return fmt(v, true) != fmt(v, false) } ?? 100
        let exact = Double(base) * b / a
        return [true, false].map { up in
            "\u{2066}\(base) \(shown[0]) → " + fmt(exact, up) + " \(shown[1])\u{2069}"
        }
    }

    private func precisionLabel(_ n: Int) -> String {
        switch n {
        case 0: return L10n.t("prec_0")
        case 1: return L10n.t("prec_1")
        case 2: return L10n.t("prec_2")
        default: return L10n.t("prec_4")
        }
    }
}

/// Страница строится, только когда на неё перешли: иначе NavigationLink на
/// iOS 15 собирает все страницы сразу при открытии настроек.
struct LazyView<Content: View>: View {
    let build: () -> Content
    init(_ build: @escaping () -> Content) { self.build = build }
    var body: Content { build() }
}

/// Выбор одного варианта из списка. После выбора — назад к настройкам.
struct ChoicePage: View {
    let title: String
    let options: [String]
    let selected: Int
    var idPrefix: String = "choice"
    var details: [String]? = nil
    var footer: String? = nil
    let pick: (Int) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                ForEach(options.indices, id: \.self) { i in
                    Button { pick(i); dismiss() } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(options[i]).foregroundColor(.primary)
                                if let d = details, d.indices.contains(i) {
                                    Text(d[i]).font(.footnote).foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            if i == selected { Image(systemName: "checkmark").foregroundColor(.brandBlue) }
                        }
                    }
                    .accessibilityIdentifier("\(idPrefix)-\(i)")
                }
            } footer: {
                if let footer { Text(footer) }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SourcePage: View {
    @ObservedObject var vm: ConverterViewModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        List {
            ForEach(-1..<RatesService.sources.count, id: \.self) { i in
                Button {
                    vm.sourceMode = i + 1
                    Task { await vm.refresh(force: true) }   // смена источника — сразу
                    dismiss()
                } label: {
                    HStack {
                        if i >= 0 {
                            Circle().fill(Color(hex: RatesService.sources[i].colorHex))
                                .frame(width: 10, height: 10)
                        }
                        Text(i < 0 ? L10n.t("source_auto") : RatesService.sources[i].title)
                            .foregroundColor(.primary)
                        Spacer()
                        if vm.sourceMode == i + 1 { Image(systemName: "checkmark").foregroundColor(.brandBlue) }
                    }
                }
            }
        }
        .navigationTitle(L10n.t("source_title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct LanguagePage: View {
    @ObservedObject var vm: ConverterViewModel
    var body: some View {
        List {
            Button {
                L10n.chosenLang = L10n.systemTag; vm.langVersion += 1
            } label: {
                HStack {
                    Text(L10n.t("language_system")).foregroundColor(.primary)
                    Spacer()
                    if L10n.chosenLang == L10n.systemTag {
                        Image(systemName: "checkmark").foregroundColor(.brandBlue)
                    }
                }
            }
            ForEach(CurrencyData.languages, id: \.0) { tag, native in
                Button {
                    L10n.chosenLang = tag; vm.langVersion += 1
                } label: {
                    HStack {
                        Text(native).foregroundColor(.primary)
                        Spacer()
                        if L10n.chosenLang == tag || (L10n.chosenLang == nil && tag == "en") {
                            Image(systemName: "checkmark").foregroundColor(.brandBlue)
                        }
                    }
                }
            }
        }
        .navigationTitle(L10n.t("language_title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SourceInfoView: View {
    @Environment(\.dismiss) private var dismiss
    /// «+1.5%», если включена поправка: справка тогда начинается с предупреждения
    var adjustLabel: String? = nil
    var onChangeAdjust: (() -> Void)? = nil

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let adjustLabel = adjustLabel {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .top, spacing: 8) {
                                PercentBadge(size: 18)
                                Text(L10n.t("adjust_info", adjustLabel))
                                    .font(.callout).foregroundColor(.adjusted)
                            }
                            if let change = onChangeAdjust {
                                Button(L10n.t("adjust_title")) { change() }
                                    .font(.callout.weight(.semibold))
                                    .accessibilityIdentifier("info-change-adjust")
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.adjustedBg)
                        .cornerRadius(10)
                    }
                    Text(L10n.t("source_info_message"))
                        .font(.callout)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    // ссылка-атрибуция ExchangeRate-API (требование лицензии)
                    Link(L10n.t("attribution"), destination: URL(string: "https://www.exchangerate-api.com")!)
                        .font(.footnote)
                }
                .padding()
            }
            .navigationTitle(L10n.t("source_info_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.t("ok")) { dismiss() }
                }
            }
        }
    }
}
