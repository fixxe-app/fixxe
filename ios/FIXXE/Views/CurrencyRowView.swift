import SwiftUI
import UniformTypeIdentifiers

struct CurrencyRowView: View {
    @ObservedObject var vm: ConverterViewModel
    let code: String
    var focusedCode: FocusState<String?>.Binding
    @Binding var dragged: String?
    let onDelete: () -> Void

    private var isActive: Bool { vm.activeCode == code }
    private var isFocused: Bool { focusedCode.wrappedValue == code }

    /// Тап пришёл, а поля ввода ещё нет — фокус ставится, когда оно появится.
    @State private var wantsFocus = false

    /// Ввод в эту строку: тап по любому месту карточки, не только по числу.
    private func activate() {
        KeyboardScrollRestore.rememberPosition()   // как стоит список до клавиатуры
        guard !isFocused else { return }
        if isActive {
            focusField()                  // поле уже на месте
        } else {
            // Сейчас на месте поля ещё текст, а фокус на поле, которого нет,
            // iOS молча отбрасывает: первый тап только «дёргал» строку,
            // срабатывал второй. Угадывать задержку нельзя — ждём само поле.
            wantsFocus = true
            vm.setActive(code)
        }
    }

    /// Текущая попытка поставить фокус; nil — фокус уже встал.
    @State private var focusAttempt: UUID?

    private func focusField() {
        // Фокус — со следующего прохода, когда поле уже в иерархии, и с
        // повторами: при переходе из другой строки уходящее поле сбрасывает
        // фокус, и если это совпало с нашей установкой, она пропадает. На
        // старых iPhone (iOS 15) поле появляется ещё медленнее.
        let attempt = UUID()
        focusAttempt = attempt
        for delay in [0.05, 0.2, 0.4, 0.7] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard focusAttempt == attempt, vm.activeCode == code,
                      focusedCode.wrappedValue != code else { return }
                focusedCode.wrappedValue = code
            }
        }
    }

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 8) {
                // Не Button: системная кнопка притягивает к себе касания рядом
                // с собой, и тап по названию валюты под крестиком открывал
                // удаление. У жеста такого притяжения нет — крестик срабатывает
                // только в своей зоне, остальная карточка — ввод суммы.
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.faint)
                    // зона нажатия 44 pt (норма HIG), а место в строке прежнее:
                    // лишнее съедают отрицательные отступы. Зона сдвинута вверх,
                    // в поле карточки: снизу название валюты, и тап по нему
                    // доставался крестику — SwiftUI учитывает размер пальца.
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle().offset(y: -7))
                    .onTapGesture(perform: onDelete)
                    .padding(.horizontal, -9).padding(.vertical, -7)
                    .accessibilityElement()
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction { onDelete() }
                    .accessibilityIdentifier("delete-\(code)")
                    .accessibilityLabel(L10n.t("delete"))
                FlagView(code: code, size: 24).onTapGesture { activate() }
                // при крупном шрифте код не рвётся пополам («EU / R») — ужимается
                Text(code).font(.subheadline.bold()).lineLimit(1)
                    .fixedSize().layoutPriority(1)   // код важнее символа: ужимается символ, а не «R…»
                    .onTapGesture { activate() }
                Spacer()
                Text(CurrencyData.symbol(code))
                    .font(.footnote).foregroundColor(.secondary)   // системный цвет: .gray давал 3.3:1
                    .lineLimit(1).minimumScaleFactor(0.5)
                    .onTapGesture { activate() }
                amountField
                dragHandle
            }
            HStack {
                Text(CurrencyData.displayName(code) ?? "")
                    .font(.caption2).foregroundColor(.secondary)
                    .accessibilityIdentifier("name-\(code)")
                    .onTapGesture { activate() }
                Spacer()
                Text(vm.rateLine(code))
                    .font(.caption2).foregroundColor(Color.textFaint)
                    .onTapGesture { activate() }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(Color.surface)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10)
            .stroke(isActive ? Color.brandBlue : .clear, lineWidth: 2))
        .contentShape(Rectangle())
        // Вся карточка — зона нажатия: это тач-устройство, целиться в число
        // незачем. Подписи и число ловят тап сами, а не только через карточку:
        // SwiftUI отдаёт касание ближайшему жесту в пятне пальца, и без своего
        // жеста тап по названию доставался соседнему крестику. Карточка —
        // для пустых мест между ними.
        .onTapGesture { activate() }
        .onDrop(of: [UTType.text], delegate: RowDropDelegate(target: code, dragged: $dragged, vm: vm))
    }

    /// Ручка перетаскивания — отдельная зона, как в Android-версии.
    /// `.onMove` в SwiftUI требует режима редактирования, поэтому порядок
    /// меняем через drag & drop, а тащим строго за этот значок, чтобы жест
    /// не мешал ни вводу суммы, ни прокрутке списка.
    private var dragHandle: some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 15, weight: .regular))
            .foregroundColor(Color.faint)
            .frame(width: 44, height: 44)               // зона нажатия 44 pt
            .contentShape(Rectangle().offset(y: -5))    // вверх: снизу строка курса
            .padding(.horizontal, -8).padding(.vertical, -5)
            .accessibilityIdentifier("drag-\(code)")
            .accessibilityLabel(L10n.t("reorder"))
            .onDrag {
                dragged = code
                focusedCode.wrappedValue = nil      // клавиатура мешает перетаскиванию
                return NSItemProvider(object: code as NSString)
            }
    }

    @ViewBuilder private var amountField: some View {
        if isActive {
            TextField("0", text: Binding(
                get: { vm.inputText },
                // Пишем в модель, только пока эта строка активна: уходящее поле
                // может прислать свой старый текст уже после переключения, и он
                // применился бы к другой валюте.
                set: { if vm.activeCode == code { vm.inputChanged($0) } }))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.title3.bold())
                .frame(width: 130)
                .focused(focusedCode, equals: code)
                .accessibilityIdentifier("amount-\(code)")
                .onAppear {
                    guard wantsFocus else { return }
                    wantsFocus = false
                    focusField()
                }
                // Как на Android (android:selectAllOnFocus): когда поле получает
                // фокус, число выделяется целиком — новую сумму можно набрать
                // сразу, не стирая старую. Повторный тап ставит курсор точно в
                // место касания (см. CaretTap — почему не selectAll(_:)).
                .onChange(of: focusedCode.wrappedValue) { focused in
                    guard focused == code else { return }
                    focusAttempt = nil     // встал — повторы не нужны и не должны вернуть клавиатуру
                    // дать полю стать first responder, иначе выделять будет нечего
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        CaretTap.selectAllQuietly()
                    }
                }
                // на цифровой клавиатуре iOS нет кнопки «Готово» — добавляем свою,
                // иначе клавиатуру нечем убрать и она закрывает нижние строки
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button { focusedCode.wrappedValue = nil } label: {
                            Image(systemName: "keyboard.chevron.compact.down")
                        }
                        .accessibilityLabel(L10n.t("close"))
                        .accessibilityIdentifier("dismiss-keyboard")
                    }
                }
        } else {
            Text(SmartFormat.amount(vm.converted(code), decimals: vm.decimals, grouping: vm.grouping))
                .font(.title3.bold())
                .lineLimit(1).minimumScaleFactor(0.5)   // длинная сумма ужимается, а не обрезается
                .frame(width: 130, alignment: .trailing)
                .accessibilityIdentifier("amount-\(code)")
                .onTapGesture { activate() }
                .accessibilityAction { activate() }
        }
    }
}
