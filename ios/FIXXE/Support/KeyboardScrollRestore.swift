import SwiftUI
import UIKit

/// Возвращает список на место, когда клавиатуру убрали.
///
/// Клавиатура поднимает список к строке ввода. Когда её закрывают, SwiftUI
/// прокрутку не откатывает, и список остаётся сдвинутым вверх. В SwiftUI для
/// iOS 15 нет доступа к положению прокрутки, поэтому берём его у UIKit:
/// невидимая вставка внутри ScrollView находит свой UIScrollView, запоминает
/// положение до клавиатуры и возвращает его, когда она уходит.
///
/// Запоминать — в момент касания строки (`rememberPosition()`), а не по
/// уведомлению о клавиатуре: на то же уведомление SwiftUI сам начинает
/// двигать список, и на iPhone 6S кто успевал первым — каждый раз по-разному:
/// после закрытия список вставал в одно из трёх разных мест. По той же причине
/// положение возвращается дважды: сразу, вместе с уходящей клавиатурой, и ещё
/// раз, когда она ушла совсем и SwiftUI закончил свою перекладку.
struct KeyboardScrollRestore: UIViewRepresentable {
    /// Запомнить, как стоит список, — пока клавиатуры нет. Зовётся при тапе.
    static func rememberPosition() { Probe.active?.rememberIfIdle() }

    func makeUIView(context: Context) -> Probe { Probe() }
    func updateUIView(_ uiView: Probe, context: Context) {}

    final class Probe: UIView {
        fileprivate static weak var active: Probe?
        private weak var scroll: UIScrollView?
        private var saved: CGPoint?
        private var restoring: CGPoint?
        private var keyboardShown = false
        private var observing = false

        fileprivate func rememberIfIdle() {
            guard !keyboardShown, let sv = scroll else { return }
            saved = sv.contentOffset
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil else { return }
            Probe.active = self
            scroll = sequence(first: superview, next: { $0?.superview })
                .lazy.compactMap { $0 as? UIScrollView }.first
            guard !observing else { return }
            observing = true
            let nc = NotificationCenter.default
            nc.addObserver(self, selector: #selector(willShow),
                           name: UIResponder.keyboardWillShowNotification, object: nil)
            nc.addObserver(self, selector: #selector(willHide),
                           name: UIResponder.keyboardWillHideNotification, object: nil)
            nc.addObserver(self, selector: #selector(didHide),
                           name: UIResponder.keyboardDidHideNotification, object: nil)
        }

        // Запасной случай, если тап не дошёл до rememberPosition (например,
        // фокус поставили программно). При переходе между строками клавиатура
        // «появляется» снова — тогда ничего не трогаем.
        @objc private func willShow() {
            if !keyboardShown && saved == nil { saved = scroll?.contentOffset }
            keyboardShown = true
        }

        @objc private func willHide() {
            keyboardShown = false
            guard let target = saved else { return }
            saved = nil
            restoring = target
            // вместе с уходящей клавиатурой — после того как SwiftUI начнёт
            // свою перекладку
            DispatchQueue.main.async { self.scrollTo(target, animated: true) }
        }

        // Клавиатура ушла, высота списка окончательная — если SwiftUI сдвинул
        // список поверх нашего возврата, ставим его на место ещё раз.
        @objc private func didHide() {
            guard let target = restoring else { return }
            restoring = nil
            DispatchQueue.main.async { self.scrollTo(target, animated: true) }
        }

        private func scrollTo(_ target: CGPoint, animated: Bool) {
            guard let sv = scroll else { return }
            let inset = sv.adjustedContentInset
            let minY = -inset.top
            let maxY = max(minY, sv.contentSize.height - sv.bounds.height + inset.bottom)
            let y = min(max(target.y, minY), maxY)
            guard abs(sv.contentOffset.y - y) > 0.5 else { return }
            sv.setContentOffset(CGPoint(x: sv.contentOffset.x, y: y), animated: animated)
        }
    }
}
