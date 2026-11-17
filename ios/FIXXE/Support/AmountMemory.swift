import Foundation

/// Сколько помнить введённую сумму — выбор в настройках. Так же на Android и в вебе.
///
/// Сумма и строка, где её набрали, записываются, когда приложение уходит с
/// экрана. Срок считается от этого момента — как у поправки к курсу.
///   session — только пока приложение в памяти: выгрузили или закрыли — снова 1;
///   h12, h24 — после перерыва дольше срока снова 1, даже если приложение ещё в памяти;
///   forever — пока сумму не поменяют.
/// «Снова 1» — как при первом запуске: 1 в первой валюте списка.
enum AmountMemory {
    static let session = 0, h12 = 1, h24 = 2, forever = 3
    /// По умолчанию — 12 часов: день поездки помнит, к утру начинает заново.
    static let defaultMode = h12
    /// Подписи вариантов по номерам — ключи переводов.
    static let labelKeys = ["amount_memory_session", "amount_memory_12h", "amount_memory_24h", "amount_memory_forever"]

    private static func limit(_ mode: Int) -> TimeInterval? {
        switch mode {
        case h12: return 12 * 60 * 60
        case h24: return 24 * 60 * 60
        default: return nil
        }
    }

    /// Холодный запуск: вернуть ли сумму, записанную при уходе с экрана в `leftAt`.
    static func restoreOnLaunch(mode: Int, leftAt: TimeInterval, now: TimeInterval) -> Bool {
        switch mode {
        case forever: return true
        case h12, h24: return !expired(mode: mode, leftAt: leftAt, now: now)
        default: return false
        }
    }

    /// Возврат в приложение, которое было в памяти: вышел ли срок. У session и
    /// forever срока нет. Часы ушли назад — тоже сброс: так безопаснее.
    static func expired(mode: Int, leftAt: TimeInterval, now: TimeInterval) -> Bool {
        guard let l = limit(mode) else { return false }
        return now - leftAt > l || now < leftAt
    }
}
