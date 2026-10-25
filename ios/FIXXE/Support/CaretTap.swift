import UIKit

/// Курсор в поле суммы — туда, куда ткнул палец.
///
/// Поле при фокусе выделяет число целиком, чтобы новую сумму можно было
/// набрать сразу (как android:selectAllOnFocus). Раньше выделение делалось
/// экшеном selectAll(_:) — тем же, что у пункта меню «Выбрать всё», — и он
/// заодно открывал меню «Вырезать / Скопировать». После этого любой тап по
/// цифрам попадал внутрь выделения, и iOS показывала-прятала меню, а курсор не
/// ставила: следующая цифра стирала всё число. Даже без выделения iOS ставит
/// курсор только в начало или конец числа — для неё это одно «слово».
///
/// Здесь: выделение ставится напрямую, без меню, а тап в уже редактируемое поле
/// ставит курсор между ближайшими к пальцу символами.
enum CaretTap {
    /// Выделить всё число без меню и подготовить поле к точной установке курсора.
    static func selectAllQuietly() {
        guard let tf = UIResponder.current as? UITextField else { return }
        tf.selectedTextRange = tf.textRange(from: tf.beginningOfDocument, to: tf.endOfDocument)
        Handler.shared.attach(to: tf)
    }

    private final class Handler: NSObject, UIGestureRecognizerDelegate {
        static let shared = Handler()
        private var wasEditing = false

        func attach(to tf: UITextField) {
            guard !(tf.gestureRecognizers ?? []).contains(where: { $0.delegate === self }) else { return }
            let tap = UITapGestureRecognizer(target: self, action: #selector(tapped(_:)))
            tap.cancelsTouchesInView = false        // собственные жесты поля работают как прежде
            tap.delegate = self
            tf.addGestureRecognizer(tap)
        }

        // было ли поле в редактировании ДО этого касания: первый тап (фокус)
        // курсор не трогает — он оставляет выделение всего числа
        func gestureRecognizer(_ g: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            wasEditing = (g.view as? UITextField)?.isEditing ?? false
            return true
        }
        func gestureRecognizer(_ g: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }

        @objc func tapped(_ g: UITapGestureRecognizer) {
            guard wasEditing, let tf = g.view as? UITextField else { return }
            let point = g.location(in: tf)
            // после собственной обработки тапа полем — иначе она перебьёт наш курсор
            DispatchQueue.main.async {
                guard let pos = tf.closestPosition(to: point) else { return }
                tf.selectedTextRange = tf.textRange(from: pos, to: pos)
                Self.hideEditMenu(in: tf)
            }
        }

        static func hideEditMenu(in tf: UITextField) {
            if #available(iOS 16.0, *) {
                tf.interactions.compactMap { $0 as? UIEditMenuInteraction }.forEach { $0.dismissMenu() }
            }
            UIMenuController.shared.hideMenu()
        }
    }
}

extension UIResponder {
    private static weak var found: UIResponder?
    /// Текущий first responder — без частного API: экшен уходит по цепочке
    /// ответчиков и первым ловит его тот, у кого сейчас фокус.
    static var current: UIResponder? {
        found = nil
        UIApplication.shared.sendAction(#selector(captureFirstResponder), to: nil, from: nil, for: nil)
        return found
    }
    @objc private func captureFirstResponder() { UIResponder.found = self }
}
