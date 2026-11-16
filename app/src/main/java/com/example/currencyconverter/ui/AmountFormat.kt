package com.example.currencyconverter.ui

import java.util.Locale

/** Как показать сумму в строке валюты. Без Android — проверяется обычными тестами. */
object AmountFormat {
    /** Насколько точность может исказить сумму, прежде чем добавятся знаки. */
    private const val TOL = 0.02

    /**
     * Выбранная точность — минимум знаков после точки. Если она искажает сумму
     * больше чем на 2%, знаки добавляются, чтобы у мелких сумм не терялся смысл
     * (0.0067 не станет «0» или «1»).
     *
     * [roundUp] — округление вверх: показанная сумма не меньше настоящей, денег
     * точно хватит. Иначе — к ближайшему, как в математике.
     *
     * Десятичный знак — точка при любом языке: на русском или немецком запятая
     * столкнулась бы с запятой-разделителем разрядов («1,,17»), а на арабском
     * цифры вышли бы восточные, и поле при правке разбиралось бы в 0.
     */
    fun format(v: Double, decimals: Int, grouping: Int, roundUp: Boolean): String {
        if (v <= 0.0) return if (decimals == 0) "0" else String.format(Locale.ROOT, "%.${decimals}f", 0.0)
        fun rounded(d: Int): Double {
            val f = Math.pow(10.0, d.toDouble())
            return if (roundUp) Math.ceil(v * f - 1e-9) / f else Math.round(v * f) / f
        }
        var d = decimals
        while (d < 8 && Math.abs(rounded(d) - v) > TOL * v) d++
        val r = rounded(d)
        val text = if (d == 0) r.toLong().toString() else String.format(Locale.ROOT, "%.${d}f", r)
        return groupDigits(text, grouping)
    }

    /** Разделитель разрядов: 0 — нет, 1 — неразрывный пробел, 2 — запятая.
     *  Только целая часть; в поле, которое сейчас редактируют, его не ставят. */
    fun groupDigits(text: String, grouping: Int): String {
        if (grouping == 0) return text
        val sep = if (grouping == 1) " " else ","
        val dot = text.indexOf('.')
        val intPart = if (dot >= 0) text.substring(0, dot) else text
        val rest = if (dot >= 0) text.substring(dot) else ""
        if (intPart.length <= 3) return text
        return intPart.reversed().chunked(3).joinToString(sep).reversed() + rest
    }
}
