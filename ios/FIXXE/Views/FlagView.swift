import SwiftUI

/// Флаг валюты.
///
/// • есть флаг в справочнике → эмодзи-флаг (как в Android/PWA);
/// • нет (крипта, часть фиата) → нейтральный глобус SF Symbol: рисуется
///   одинаково на любой iOS и не зависит от состава эмодзи-шрифта;
/// • DEBUG + подложенные PNG → картинка из бандла (съёмка скриншотов
///   магазина: в симуляторе Apple Color Emoji идёт без глифов флагов).
struct FlagView: View {
    let code: String
    var size: CGFloat = 22

    var body: some View {
        if let png = FlagAssets.image(for: code) {
            Image(uiImage: png).resizable().scaledToFit()
                .frame(width: size, height: size)
        } else if let flag = CurrencyData.flagOrNil(code) {
            Text(flag).font(.system(size: size))
        } else {
            Image(systemName: "globe")
                .font(.system(size: size * 0.78))
                .foregroundColor(Color.muted)
                .frame(width: size, height: size)
        }
    }
}

/// Подстановка флагов картинками — только для съёмки скриншотов в симуляторе.
/// В релизной сборке всегда nil, файлов в бандле нет.
enum FlagAssets {
#if DEBUG
    private static var cache: [String: UIImage?] = [:]
    static func image(for code: String) -> UIImage? {
        if let c = cache[code] { return c }
        let img = Bundle.main.path(forResource: "flag_\(code)", ofType: "png")
            .flatMap { UIImage(contentsOfFile: $0) }
        cache[code] = img
        return img
    }
#else
    static func image(for code: String) -> UIImage? { nil }
#endif
}
