import SwiftUI

struct SettingsView: View {
    @ObservedObject var vm: ConverterViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                // Оформление
                Section(L10n.t("theme_title")) {
                    ForEach(0..<3, id: \.self) { mode in
                        Button {
                            vm.theme = mode
                        } label: {
                            HStack {
                                Text(L10n.t(["theme_system", "theme_light", "theme_dark"][mode]))
                                    .foregroundColor(.primary)
                                Spacer()
                                if vm.theme == mode {
                                    Image(systemName: "checkmark").foregroundColor(.brandBlue)
                                }
                            }
                        }
                        .accessibilityIdentifier("theme-\(mode)")
                    }
                }
                // Точность
                Section(L10n.t("precision_title")) {
                    ForEach([0, 1, 2, 4], id: \.self) { n in
                        Button {
                            vm.decimals = n
                        } label: {
                            HStack {
                                Text(labelFor(n)).foregroundColor(.primary)
                                Spacer()
                                if vm.decimals == n { Image(systemName: "checkmark").foregroundColor(.brandBlue) }
                            }
                        }
                    }
                }
                // Разделитель разрядов
                Section(L10n.t("grouping_title")) {
                    ForEach(0..<3, id: \.self) { mode in
                        Button {
                            vm.grouping = mode
                        } label: {
                            HStack {
                                Text(L10n.t(["group_none", "group_space", "group_comma"][mode]))
                                    .foregroundColor(.primary)
                                Spacer()
                                if vm.grouping == mode {
                                    Image(systemName: "checkmark").foregroundColor(.brandBlue)
                                }
                            }
                        }
                        .accessibilityIdentifier("grouping-\(mode)")
                    }
                }
                // Источник
                Section(L10n.t("source_title")) {
                    ForEach(-1..<RatesService.sources.count, id: \.self) { i in
                        Button {
                            vm.sourceMode = i + 1
                            Task { await vm.refresh(force: true) }   // смена источника — сразу
                        } label: {
                            HStack {
                                if i >= 0 {
                                    Circle().fill(Color(hex: RatesService.sources[i].colorHex))
                                        .frame(width: 10, height: 10)
                                }
                                Text(i < 0 ? L10n.t("source_auto") : RatesService.sources[i].name)
                                    .foregroundColor(.primary)
                                Spacer()
                                if vm.sourceMode == i + 1 { Image(systemName: "checkmark").foregroundColor(.brandBlue) }
                            }
                        }
                    }
                }
                // Язык
                Section(L10n.t("language_title")) {
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
                                // ничего не выбрано → отмечен English (дефолт приложения)
                                if L10n.chosenLang == tag || (L10n.chosenLang == nil && tag == "en") {
                                    Image(systemName: "checkmark").foregroundColor(.brandBlue)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(L10n.t("settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button(L10n.t("close")) { dismiss() } }
        }
        .id(vm.langVersion)
    }

    private func labelFor(_ n: Int) -> String {
        switch n {
        case 0: return L10n.t("prec_0")
        case 1: return L10n.t("prec_1")
        case 2: return L10n.t("prec_2")
        default: return L10n.t("prec_4")
        }
    }
}

struct SourceInfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
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
