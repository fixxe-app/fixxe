package com.example.currencyconverter.ui

/**
 * Размер шрифта суммы, чтобы число влезло в поле. Так же на iOS и в вебе.
 *
 * Пока число влезает — обычный размер. Не влезает — шрифт уменьшается ровно
 * настолько, чтобы влезло, но не меньше половины: дальше цифры не прочесть,
 * и поле лучше прокрутить.
 */
object AmountFit {
    const val MIN_FACTOR = 0.5f

    /** [widthAtBase] — ширина текста при обычном размере [base], [available] — место в поле. */
    fun size(base: Float, widthAtBase: Float, available: Float): Float {
        if (widthAtBase <= available || widthAtBase <= 0f || available <= 0f) return base
        return maxOf(base * MIN_FACTOR, base * available / widthAtBase)
    }
}
