import UIKit

/// Размер шрифта суммы, чтобы число влезло в поле. Так же на Android и в вебе.
///
/// Пока число влезает — обычный размер. Не влезает — шрифт уменьшается ровно
/// настолько, чтобы влезло, но не меньше половины: дальше цифры не прочесть.
/// Строкам без ввода хватает `minimumScaleFactor`, а полю ввода SwiftUI его
/// не применяет — поэтому размер для поля считаем сами.
enum AmountFit {
    static let minFactor: CGFloat = 0.5

    /// `widthAtBase` — ширина текста при обычном размере `base`, `available` — место в поле.
    static func size(base: CGFloat, widthAtBase: CGFloat, available: CGFloat) -> CGFloat {
        if widthAtBase <= available || widthAtBase <= 0 || available <= 0 { return base }
        return max(base * minFactor, base * available / widthAtBase)
    }

    /// Ширина текста жирным шрифтом с цифрами одной ширины — как в поле суммы.
    static func width(_ text: String, size: CGFloat) -> CGFloat {
        let font = UIFont.monospacedDigitSystemFont(ofSize: size, weight: .bold)
        return ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }

    /// Размер шрифта для `text` в поле шириной `width` при обычном размере `base`.
    static func fontSize(for text: String, base: CGFloat, width available: CGFloat) -> CGFloat {
        var size = self.size(base: base, widthAtBase: width(text, size: base), available: available)
        // ширина текста не строго пропорциональна размеру: добрать, если не влезло
        for _ in 0..<3 {
            let wide = width(text, size: size)
            if wide <= available || size <= base * minFactor { break }
            size = max(base * minFactor, size * available / wide)
        }
        return size
    }
}
