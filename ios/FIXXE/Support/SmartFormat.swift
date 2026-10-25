import Foundation

/// Умное округление вверх (как в Android/PWA): выбранная точность — минимум,
/// но если она искажает значение больше чем на 2%, добавляем знаки,
/// чтобы мелкие суммы не превращались в «1».
enum SmartFormat {
    /// Разделитель разрядов: 0 — нет, 1 — пробел, 2 — запятая.
    /// Применяется только к целой части; в поле, которое сейчас редактируют,
    /// группировки нет — она мешала бы набору.
    static func group(_ text: String, mode: Int) -> String {
        guard mode != 0 else { return text }
        let sep = mode == 1 ? "\u{00A0}" : ","      // неразрывный пробел, чтобы число не рвалось
        let parts = text.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        let intPart = String(parts[0])
        let rest = parts.count > 1 ? "." + parts[1] : ""
        guard intPart.count > 3 else { return text }
        var out = ""
        for (i, ch) in intPart.reversed().enumerated() {
            if i > 0 && i % 3 == 0 { out += sep }
            out.append(ch)
        }
        return String(out.reversed()) + rest
    }

    static func amount(_ v: Double, decimals n: Int, grouping g: Int = 0) -> String {
        // бесконечность и NaN (вставка «1e400») — не сумма
        if !v.isFinite || v <= 0 { return n == 0 ? "0" : String(format: "%.\(n)f", 0.0) }
        let tol = 0.02
        var d = n
        while d < 8 {
            let f = pow(10.0, Double(d))
            let ceiled = (v * f - 1e-9).rounded(.up) / f
            if ceiled - v <= tol * v { break }
            d += 1
        }
        let f = pow(10.0, Double(d))
        let ceiled = (v * f - 1e-9).rounded(.up) / f
        // Не Int(…): преобразование в Int аварийно завершает приложение, если
        // число больше 9,2·10¹⁸. С донгом в списке хватало ввести 16 цифр в EUR.
        let text = String(format: "%.\(d)f", ceiled)
        return group(text, mode: g)
    }

    static func rate(_ r: Double) -> String {
        if r >= 10000 { return String(format: "%.0f", r) }
        if r >= 100 { return String(format: "%.2f", r) }
        if r >= 1 { return String(format: "%.4f", r) }
        return String(format: "%.6f", r)
    }

    /// Разбор ввода. Те же правила на всех трёх платформах.
    ///
    /// Десятичный знак на цифровой клавиатуре зависит от региона: в России,
    /// Сербии, Германии это запятая. Поэтому запятую нельзя слепо считать
    /// разделителем разрядов, даже если он выбран в настройках, — иначе «1,5»
    /// молча становится 15.
    ///  - есть и точка, и запятая — десятичный знак тот, что правее;
    ///  - один знак встречается несколько раз — это разряды;
    ///  - одна запятая — десятичная, кроме случая, когда выбрана группировка
    ///    запятой и за ней ровно группы по три цифры («1,500» = 1500);
    ///  - пробелы и неразрывные пробелы — всегда разряды.
    static func parse(_ s: String, grouping g: Int = 0) -> Double {
        var t = s.filter { $0 != " " && $0 != "\u{00A0}" && $0 != "\u{202F}" }
        let dot = t.lastIndex(of: "."), comma = t.lastIndex(of: ",")
        if let dot = dot, let comma = comma {
            t = comma > dot ? t.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
                            : t.replacingOccurrences(of: ",", with: "")
        } else if comma != nil {
            let commas = t.filter { $0 == "," }.count
            let thousands = t.range(of: #"^\d{1,3}(,\d{3})+$"#, options: .regularExpression) != nil
            t = (commas > 1 || (g == 2 && thousands)) ? t.replacingOccurrences(of: ",", with: "")
                                                       : t.replacingOccurrences(of: ",", with: ".")
        } else if t.filter({ $0 == "." }).count > 1 {
            t = t.replacingOccurrences(of: ".", with: "")
        }
        guard let v = Double(t), v.isFinite else { return 0 }
        return v
    }
}
