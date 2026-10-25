import SwiftUI
import UniformTypeIdentifiers

/// Перетаскивание строк без режима редактирования.
///
/// `.onMove` в SwiftUI работает только когда список в EditMode, а там нельзя
/// вводить суммы. Поэтому порядок меняется через drag & drop: тащить можно за
/// левую часть строки (флаг и код), поле ввода жест не перехватывает.
struct RowDropDelegate: DropDelegate {
    let target: String
    @Binding var dragged: String?
    let vm: ConverterViewModel

    func dropEntered(info: DropInfo) {
        guard let dragged, dragged != target else { return }
        vm.move(dragged, before: target)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool {
        dragged = nil
        return true
    }
}
