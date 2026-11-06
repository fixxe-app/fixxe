import SwiftUI

/// Значок «%» в залитом квадрате — метка «число пересчитано с поправкой».
/// Дублирует цвет: при дальтонизме фиолетовый близок к синему, и одного
/// цвета как сигнала мало. Отдельный элемент, а не символ в строке курса:
/// внутри текста его переставил бы двунаправленный алгоритм (арабский, иврит).
struct PercentBadge: View {
    var size: CGFloat = 14
    var body: some View {
        Text("%")
            .font(.system(size: size * 0.74, weight: .bold))
            .foregroundColor(.onAdjusted)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: size * 0.26).fill(Color.adjusted))
            .accessibilityHidden(true)
    }
}

/// Раздел «Поправка к курсу»: выключить, знак, готовые значения, своё, закрепить.
/// Один и тот же в настройках и в листе, который открывает полоса на главном экране.
struct AdjustSection: View {
    @ObservedObject var vm: ConverterViewModel
    @State private var negative = false
    @State private var custom = ""
    @FocusState private var customFocused: Bool
    private let presets: [Double] = [0.5, 1, 1.5, 2, 3, 5]

    private func signed(_ v: Double) -> Double { negative ? -v : v }
    private func plain(_ v: Double) -> String { String(RateAdjust.label(v).dropFirst().dropLast()) }

    var body: some View {
        Section {
            Button { vm.setAdjust(0); custom = "" } label: {
                HStack {
                    Text(L10n.t("adjust_off")).foregroundColor(.primary)
                    Spacer()
                    if !vm.adjusted { Image(systemName: "checkmark").foregroundColor(.brandBlue) }
                }
            }
            .accessibilityIdentifier("adjust-off")
            // на цифровой клавиатуре iPhone минуса нет — знак выбирается отдельно
            Picker("", selection: Binding(get: { negative }, set: { neg in
                negative = neg
                if vm.adjusted { vm.setAdjust(neg ? -abs(vm.adjustPct) : abs(vm.adjustPct)) }
            })) {
                Text("+").tag(false)
                Text("\u{2212}").tag(true)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("adjust-sign")
            HStack(spacing: 6) {
                ForEach(presets, id: \.self) { p in
                    let on = abs(vm.adjustPct) == p
                    Button { vm.setAdjust(signed(p)); custom = "" } label: {
                        Text(plain(p))
                            .font(.subheadline.weight(on ? .bold : .regular))
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .background(on ? Color.adjusted : Color.surface)
                            .foregroundColor(on ? Color.onAdjusted : .primary)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.hairline, lineWidth: on ? 0 : 1))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(RateAdjust.label(signed(p)))
                    .accessibilityIdentifier("adjust-\(plain(p))")
                }
            }
            HStack {
                Text(L10n.t("adjust_custom"))
                Spacer()
                TextField("0.00", text: $custom)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                    .focused($customFocused)
                    .accessibilityIdentifier("adjust-custom")
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button { customFocused = false } label: {
                                Image(systemName: "keyboard.chevron.compact.down")
                            }
                            .accessibilityLabel(L10n.t("close"))
                        }
                    }
                    .onChange(of: custom) { text in
                        guard customFocused else { return }           // только настоящий ввод
                        let v = SmartFormat.parse(text)
                        if v > 0 { vm.setAdjust(signed(v)) }
                    }
                Text("%").foregroundColor(.secondary)
            }
            Toggle(L10n.t("adjust_keep"), isOn: $vm.adjustKeep)
                .accessibilityIdentifier("adjust-keep")
        } header: {
            HStack {
                Text(L10n.t("adjust_title"))
                Spacer()
                if vm.adjusted {
                    Text(RateAdjust.label(vm.adjustPct)).foregroundColor(.adjusted).bold()
                        .environment(\.layoutDirection, .leftToRight)   // «+1.5%» не разворачивается в RTL
                        .accessibilityIdentifier("adjust-value")
                }
            }
        } footer: {
            Text(L10n.t("adjust_keep_hint"))
        }
        .onAppear {
            negative = vm.adjustPct < 0
            let a = abs(vm.adjustPct)
            custom = (a != 0 && !presets.contains(a)) ? plain(a) : ""
        }
    }
}

/// Лист с одной настройкой — его открывает полоса «Курсы с поправкой».
struct AdjustSheet: View {
    @ObservedObject var vm: ConverterViewModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationView {
            List { AdjustSection(vm: vm) }
                .navigationTitle(L10n.t("adjust_title"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L10n.t("close")) { dismiss() }.accessibilityIdentifier("adjust-close")
                    }
                }
        }
        .environment(\.layoutDirection, L10n.isRTL ? .rightToLeft : .leftToRight)
    }
}
