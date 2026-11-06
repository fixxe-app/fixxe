package com.example.currencyconverter.ui

import java.util.Locale
import kotlin.math.abs

/**
 * Поправка к курсу: процент со знаком, на который изменены все пересчитанные
 * суммы и строки курса. +1.5 — «заплачу больше», −1.5 — «получу меньше»,
 * 0 — выключено. Так сразу виден результат с учётом комиссии банка, маржи
 * или потерь на переводе, а не голый рыночный курс.
 */
object RateAdjust {
    /** Столько поправка живёт без использования приложения, если её не закрепили. */
    const val RESET_AFTER_MS = 4 * 60 * 60 * 1000L

    val PRESETS = doubleArrayOf(0.5, 1.0, 1.5, 2.0, 3.0, 5.0)

    fun factor(pct: Double) = 1 + pct / 100

    /** Два знака после запятой, не дальше ±99.99; мусор — ноль. */
    fun clamp(pct: Double): Double {
        if (pct.isNaN() || pct.isInfinite()) return 0.0
        return (Math.round(pct * 100) / 100.0).coerceIn(-99.99, 99.99)
    }

    /** «+1.5%», «−2%»: знак всегда явный, минус настоящий (U+2212), разделитель — точка. */
    fun label(pct: Double): String {
        val p = clamp(pct)
        val digits = String.format(Locale.ROOT, "%.2f", abs(p)).trimEnd('0').trimEnd('.')
        return (if (p < 0) "−" else "+") + digits + "%"
    }

    /**
     * Пора ли сбросить поправку: не закреплена и приложением не пользовались
     * дольше срока. Привязка ко времени, а не к «следующему запуску»: процесс
     * живёт в фоне сутками, и «запуск» для человека — это возврат к приложению.
     * Часы ушли назад — тоже сбрасываем: безопасное состояние — рыночный курс.
     */
    fun shouldReset(pct: Double, keep: Boolean, leftAt: Long, now: Long): Boolean {
        if (pct == 0.0 || keep) return false
        return now - leftAt > RESET_AFTER_MS || now < leftAt
    }
}

/**
 * Что введено и от какой строки считаются остальные. Без Android — проверяется
 * обычными тестами.
 *
 * Базовая строка — та, где последний раз набрали число: её сумма точная, все
 * остальные считаются от неё. Без поправки база — всегда строка с курсором,
 * как было раньше. С поправкой переход на другую строку базу не меняет: иначе
 * процент прибавлялся бы при каждом переходе и числа уползали бы сами.
 */
class AmountModel(first: String) {
    /** Строка, в которой последний раз ввели число. */
    var base = first; private set
    /** Строка с курсором. */
    var active = first; private set
    /** Сумма в базовой строке. */
    var amount = 1.0; private set
    var adjustPct = 0.0; private set

    val adjusted get() = adjustPct != 0.0

    /** Пересчитана ли строка с поправкой: все, кроме базовой. */
    fun isAdjusted(code: String) = adjusted && code != base

    /** Сумма в строке; null — курса этой валюты нет. */
    fun converted(code: String, rates: Map<String, Double>): Double? {
        if (code == base) return amount            // у базовой — ровно то, что ввели
        val to = rates[code] ?: return null
        val from = rates[base] ?: 1.0              // базы нет в таблице — считаем от EUR
        val inEur = if (from != 0.0) amount / from else 0.0
        return inEur * to * RateAdjust.factor(adjustPct)
    }

    /** От какой валюты подписаны курсы: от базовой, а если её нет в таблице — от EUR. */
    fun pivot(rates: Map<String, Double>) = if (rates.containsKey(base)) base else "EUR"

    /** «1 pivot = x code» с поправкой; null — для самой опорной строки. */
    fun rate(code: String, rates: Map<String, Double>): Double? {
        val pivot = pivot(rates)
        if (code == pivot) return null
        val to = rates[code] ?: return null
        return to / (rates[pivot] ?: 1.0) * RateAdjust.factor(adjustPct)
    }

    /** Курсор встал в строку, но ничего не введено. */
    fun focus(code: String, rates: Map<String, Double>) {
        if (!adjusted) {
            amount = converted(code, rates) ?: amount   // считаем ДО смены базы
            base = code
        }
        active = code
    }

    /** В строке набрали число — теперь она база. */
    fun type(code: String, value: Double) {
        base = code; active = code; amount = value
    }

    fun clear() {
        base = active; amount = 0.0
    }

    /** Строку убрали из списка; [first] — первая из оставшихся. */
    fun remove(code: String, first: String, rates: Map<String, Double>) {
        if (base == code) {
            // Базой становится первая строка — с той суммой, что в ней показана.
            // Сумму переводим, а не переносим как есть: иначе 5000 RSD после
            // удаления RSD становились 5000 EUR.
            amount = converted(first, rates) ?: amount
            base = first; active = first
        } else if (active == code) {
            active = base                      // удалили строку с курсором, база цела
        }
    }

    /** Сменить процент; true — он действительно изменился. */
    fun setAdjust(pct: Double): Boolean {
        val p = RateAdjust.clamp(pct)
        if (p == adjustPct) return false
        active = base                          // курсор — на базовую строку: её число не пересчитано
        adjustPct = p
        return true
    }
}
