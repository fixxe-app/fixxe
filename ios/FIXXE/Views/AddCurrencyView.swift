import SwiftUI

/// Поиск/добавление валюты: фильтр по источнику (чипы), цветные точки
/// доступности, предложение переключить источник для «чужих» валют.
struct AddCurrencyView: View {
    @ObservedObject var vm: ConverterViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var query = ScreenshotArgs.initialQuery
    @State private var filter: Int = ScreenshotArgs.initialFilter   // -1 = все, 0..2 — источник
    @State private var switchCandidate: (code: String, srcIdx: Int)?
    /// Отдельный флаг алерта. Раньше он открывался вычисляемым Binding от
    /// switchCandidate: при нажатии кнопки SwiftUI сначала закрывает алерт —
    /// и обнулял кандидата раньше, чем кнопка его читала. «Switch source and
    /// add» не делала ничего.
    @State private var showSwitch = false

    private var codes: [String] {
        var list = vm.allCodesUnion
        if filter >= 0 {
            let name = RatesService.sources[filter].name
            list = list.filter { vm.sourceCodes[name]?.contains($0) ?? false }
        }
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        if !q.isEmpty {
            list = list.filter { $0.lowercased().contains(q) || CurrencyData.name($0).lowercased().contains(q) }
        }
        return list
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                chips
                List(codes, id: \.self) { code in row(code) }
                    .listStyle(.plain)
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: L10n.t("search_hint"))
            .navigationTitle(L10n.t("add_currency_title", max(0, vm.allCodesUnion.count - vm.currencies.count)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button(L10n.t("cancel")) { dismiss() } }
            .task { await vm.loadSourceCodes() }
            .alert(L10n.t("switch_source_title"), isPresented: $showSwitch) {
                Button(L10n.t("switch_and_add")) {
                    guard let c = switchCandidate else { return }
                    Task { await vm.switchSourceAndAdd(c.code, sourceIdx: c.srcIdx); dismiss() }
                }
                Button(L10n.t("back"), role: .cancel) { }
            } message: {
                if let c = switchCandidate {
                    Text(L10n.t("switch_source_msg", c.code, RatesService.sources[c.srcIdx].name))
                }
            }
        }
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                chip(L10n.t("filter_all"), idx: -1, color: Color.chipOn)
                ForEach(Array(RatesService.sources.enumerated()), id: \.offset) { i, s in
                    chip(s.short, idx: i, color: Color(hex: s.colorHex))
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
        }
        .background(Color.surface)
    }

    private func chip(_ label: String, idx: Int, color: Color) -> some View {
        Button {
            filter = idx
        } label: {
            HStack(spacing: 5) {
                if idx >= 0 { Circle().fill(filter == idx ? Color.surface : color).frame(width: 8, height: 8) }
                Text(label).font(.caption)
            }
            .padding(.horizontal, 11).padding(.vertical, 5)
            .background(filter == idx ? color : Color.surface)
            .foregroundColor(filter == idx ? Color.onAccent : Color.chipText)
            .overlay(Capsule().stroke(Color.hairline, lineWidth: filter == idx ? 0 : 1))
            .clipShape(Capsule())
        }
    }

    private func row(_ code: String) -> some View {
        let added = vm.currencies.contains(code)
        let inActive = vm.rates[code] != nil
        return HStack(spacing: 10) {
            FlagView(code: code, size: 21)
            Text(code).font(.subheadline.bold()).frame(width: 54, alignment: .leading)
            Text(CurrencyData.displayName(code) ?? "")
                .font(.footnote).foregroundColor(.secondary)
                .lineLimit(1)
            Spacer()
            HStack(spacing: 4) {
                ForEach(vm.sourcesWith(code), id: \.self) { i in
                    Circle().fill(Color(hex: RatesService.sources[i].colorHex))
                        .frame(width: 9, height: 9)
                }
            }
            if added {
                Image(systemName: "checkmark").foregroundColor(Color.addedGreen).font(.footnote.bold())
            }
        }
        .opacity(added ? 0.4 : (inActive ? 1 : 0.72))
        .contentShape(Rectangle())
        .accessibilityIdentifier("add-\(code)")
        .onTapGesture {
            guard !added else { return }
            if inActive {
                vm.add(code); dismiss()
            } else if let first = vm.sourcesWith(code).first {
                switchCandidate = (code, first)
                showSwitch = true
            }
        }
    }
}
