import Foundation

/// Поправка к курсу: процент со знаком, на который изменены все пересчитанные
/// суммы и строки курса. Так сразу виден результат с учётом комиссии банка,
/// маржи обменника или потерь на переводе: +1.5 — «заплачу больше», −1.5 —
/// «получу меньше». 0 — выключено, курсы среднерыночные.
enum RateAdjust {
    /// Сколько поправка живёт без использования приложения. Привязка ко
    /// времени, а не к «следующему запуску»: iOS может держать приложение в
    /// памяти неделями, а может выгрузить его, пока человек на минуту вышел
    /// в банк. Забытая поправка — это неверное решение о деньгах.
    static let resetAfter: TimeInterval = 4 * 60 * 60

    static func factor(_ pct: Double) -> Double { 1 + pct / 100 }

    /// Два знака после запятой, не больше ±99.99; мусор — выключено.
    static func clamp(_ pct: Double) -> Double {
        guard pct.isFinite else { return 0 }
        return min(99.99, max(-99.99, (pct * 100).rounded() / 100))
    }

    /// «+1.5%», «−2%»: знак всегда явный, минус — настоящий (U+2212),
    /// разделитель — точка на любом языке, как и в остальных числах приложения.
    static func label(_ pct: Double) -> String {
        let v = clamp(pct)
        var s = String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), abs(v))
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return (v < 0 ? "\u{2212}" : "+") + s + "%"
    }

    /// Пора ли сбросить поправку: не закреплена и приложением не пользовались
    /// дольше `resetAfter`. Часы ушли назад — тоже сбрасываем: срок проверить
    /// нельзя, а безопасное состояние — рыночный курс.
    static func shouldReset(pct: Double, keep: Bool, leftAt: TimeInterval, now: TimeInterval) -> Bool {
        guard pct != 0, !keep else { return false }
        return now - leftAt > resetAfter || now < leftAt
    }
}
