import StoreKit
import UIKit

/// Когда попросить оценку в App Store: 1-й раз — от 50 открытий и 14 дней, 2-й — через 42 дня
/// и ещё 100 открытий, больше — никогда. Открытие — возврат после перерыва от 30 минут.
/// Оценил ли человек, App Store не сообщает; показать ли окно, решает сам. Копия — Android ReviewAsk.kt.
enum ReviewAsk {
    static let minOpens = 50, minDays = 14.0
    static let againOpens = 100, againDays = 42.0
    static let maxAsks = 2
    static let breakMinutes = 30.0
    /// Пауза после ввода суммы: не посреди набора.
    static let quiet: TimeInterval = 3

    struct State: Equatable {
        var opens = 0, firstAt: TimeInterval = 0, asks = 0
        var lastAskAt: TimeInterval = 0, opensAtAsk = 0
    }

    /// Приложение вышло на экран. `leftAt` — когда уходило с экрана в прошлый раз (0 — не уходило).
    static func opened(_ s: State, now: TimeInterval, leftAt: TimeInterval) -> State {
        var r = s
        if r.firstAt <= 0 { r.firstAt = now }
        if leftAt <= 0 || now < leftAt || now - leftAt >= breakMinutes * 60 { r.opens += 1 }
        return r
    }

    /// Пора ли просить.
    static func due(_ s: State, now: TimeInterval) -> Bool {
        if s.asks >= maxAsks || s.firstAt <= 0 { return false }
        if s.asks == 0 { return s.opens >= minOpens && now - s.firstAt >= minDays * 86400 }
        return s.opens - s.opensAtAsk >= againOpens && now - s.lastAskAt >= againDays * 86400
    }

    /// Попросили.
    static func asked(_ s: State, now: TimeInterval) -> State {
        var r = s; r.asks += 1; r.lastAskAt = now; r.opensAtAsk = s.opens; return r
    }

    // MARK: - Хранение и вызов окна

    private static let d = UserDefaults.standard
    static var state: State {
        get { State(opens: d.integer(forKey: "review_opens"), firstAt: d.double(forKey: "review_first_at"),
                    asks: d.integer(forKey: "review_asks"), lastAskAt: d.double(forKey: "review_last_ask_at"),
                    opensAtAsk: d.integer(forKey: "review_opens_at_ask")) }
        set { d.set(newValue.opens, forKey: "review_opens"); d.set(newValue.firstAt, forKey: "review_first_at")
              d.set(newValue.asks, forKey: "review_asks"); d.set(newValue.lastAskAt, forKey: "review_last_ask_at")
              d.set(newValue.opensAtAsk, forKey: "review_opens_at_ask") }
    }

    /// При запуске SwiftUI сообщает о появлении дважды (.task и scenePhase) — считаем один раз.
    private static var visitCounted = false
    private static var pending: DispatchWorkItem?

    /// Приложение вышло на экран. Уход с экрана записывает vm.markUsed.
    static func countOpen() {
        guard !visitCounted else { return }
        visitCounted = true
        state = opened(state, now: Date().timeIntervalSince1970, leftAt: d.double(forKey: "adjust_left_at"))
    }

    /// Приложение ушло с экрана.
    static func left() {
        visitCounted = false
        pending?.cancel(); pending = nil
    }

    /// Ввели сумму: если пора — попросить оценку, когда ввод затихнет.
    static func amountTyped() {
        pending?.cancel(); pending = nil
        guard due(state, now: Date().timeIntervalSince1970) else { return }
        let work = DispatchWorkItem {
            let now = Date().timeIntervalSince1970
            guard due(state, now: now),
                  let scene = UIApplication.shared.connectedScenes
                    .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
            else { return }
            state = asked(state, now: now)
            SKStoreReviewController.requestReview(in: scene)
        }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + quiet, execute: work)
    }
}
