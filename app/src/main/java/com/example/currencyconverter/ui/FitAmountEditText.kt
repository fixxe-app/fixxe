package com.example.currencyconverter.ui

import android.content.Context
import android.graphics.Paint
import android.util.AttributeSet
import android.util.TypedValue
import androidx.appcompat.widget.AppCompatEditText

/**
 * Поле суммы, в котором длинное число («150 000 000») уменьшается, а не
 * обрезается. Обычный размер — из разметки; меньше он становится, только когда
 * число не влезает (правило — [AmountFit]). Встроенный autoSizeText для полей
 * ввода Android не поддерживает.
 */
class FitAmountEditText @JvmOverloads constructor(
    context: Context, attrs: AttributeSet? = null, defStyleAttr: Int = android.R.attr.editTextStyle,
) : AppCompatEditText(context, attrs, defStyleAttr) {

    /** Обычный размер, px — из разметки, с учётом крупного шрифта в системе. */
    private val baseSize = textSize
    private val measurer = Paint()
    /** Запас под курсор: без него последняя цифра пряталась под ним. */
    private val caretRoom = 2 * resources.displayMetrics.density

    override fun onTextChanged(text: CharSequence?, start: Int, before: Int, after: Int) {
        super.onTextChanged(text, start, before, after)
        fit()
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        fit()
    }

    private fun fit() {
        if (width == 0) return              // ещё не разложено — подгоним в onSizeChanged
        measurer.set(paint)
        measurer.textSize = baseSize
        val text = text?.toString().orEmpty()
        val available = width - totalPaddingLeft - totalPaddingRight - caretRoom
        var size = AmountFit.size(baseSize, measurer.measureText(text), available)
        // ширина текста не строго пропорциональна размеру: добрать, если не влезло
        val min = baseSize * AmountFit.MIN_FACTOR
        for (i in 0 until 3) {
            measurer.textSize = size
            val wide = measurer.measureText(text)
            if (wide <= available || size <= min) break
            size = maxOf(min, size * available / wide)
        }
        if (kotlin.math.abs(size - textSize) < 0.5f) return
        setTextSize(TypedValue.COMPLEX_UNIT_PX, size)
    }
}
