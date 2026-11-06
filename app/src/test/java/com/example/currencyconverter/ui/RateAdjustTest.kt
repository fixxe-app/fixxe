package com.example.currencyconverter.ui

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Поправка к курсу. Главное, что здесь проверяется: процент применяется один
 * раз — от строки, где последний раз ввели число, — и переходы между строками
 * без ввода не меняют ни одной суммы. Без этого каждое касание другой строки
 * прибавляло бы процент ещё раз.
 */
class RateAdjustTest {
    // курсы к EUR
    private val rates = mapOf("EUR" to 1.0, "USD" to 1.2, "RSD" to 120.0, "GEL" to 3.0)
    private val codes = listOf("EUR", "USD", "RSD", "GEL")
    private fun model(pct: Double = 0.0) = AmountModel("EUR").apply { setAdjust(pct) }
    private fun AmountModel.all() = codes.associateWith { converted(it, rates)!! }
    private fun near(exp: Double, got: Double?) = assertEquals(exp, got!!, 1e-9 * maxOf(1.0, exp))

    @Test fun percentIsAppliedToEveryRowExceptBase() {
        val m = model(1.5)
        m.type("EUR", 100.0)
        assertEquals(100.0, m.converted("EUR", rates)!!, 0.0)       // база — ровно введённое
        near(100 * 1.2 * 1.015, m.converted("USD", rates))
        near(100 * 120 * 1.015, m.converted("RSD", rates))
        assertFalse(m.isAdjusted("EUR")); assertTrue(m.isAdjusted("USD")); assertTrue(m.isAdjusted("RSD"))
        // строка курса тоже с поправкой; у базовой её нет
        assertNull(m.rate("EUR", rates))
        near(1.2 * 1.015, m.rate("USD", rates))
        assertEquals("EUR", m.pivot(rates))
    }

    @Test fun negativePercentReduces() {
        val m = model(-2.0)
        m.type("USD", 60.0)
        near(60 / 1.2 * 0.98, m.converted("EUR", rates))
        near(1 / 1.2 * 0.98, m.rate("EUR", rates))
    }

    @Test fun movingBetweenRowsNeverChangesAmounts() {
        val m = model(1.5)
        m.type("EUR", 100.0)
        val before = m.all()
        repeat(6) { m.focus("USD", rates); m.focus("RSD", rates); m.focus("GEL", rates); m.focus("EUR", rates) }
        m.focus("USD", rates)
        assertEquals(before, m.all())
        assertEquals("EUR", m.base)          // база на месте…
        assertEquals("USD", m.active)        // …а курсор перешёл
        assertTrue(m.isAdjusted("USD"))
    }

    @Test fun typingMakesRowTheBase() {
        val m = model(1.5)
        m.type("EUR", 100.0)
        m.focus("USD", rates)
        m.type("USD", 50.0)
        assertEquals("USD", m.base)
        assertEquals(50.0, m.converted("USD", rates)!!, 0.0)
        near(50 / 1.2 * 1.015, m.converted("EUR", rates))
        assertFalse(m.isAdjusted("USD")); assertTrue(m.isAdjusted("EUR"))
        near(1 / 1.2 * 1.015, m.rate("EUR", rates))
    }

    @Test fun withoutAdjustmentBehavesAsBefore() {
        val m = model()
        m.type("EUR", 100.0)
        assertFalse(m.adjusted)
        codes.forEach { assertFalse(m.isAdjusted(it)) }
        near(120.0, m.converted("USD", rates))
        near(1.2, m.rate("USD", rates))
        // переход сразу делает строку базой — с точной суммой, без накопления ошибки
        m.focus("USD", rates)
        assertEquals("USD", m.base); assertEquals("USD", m.active)
        near(120.0, m.amount)
        val before = m.all()
        repeat(20) { m.focus("RSD", rates); m.focus("GEL", rates); m.focus("USD", rates) }
        m.all().forEach { (c, v) -> near(before[c]!!, v) }
        near(1 / 1.2, m.rate("EUR", rates))
    }

    @Test fun removingRows() {
        val m = model(1.5)
        m.type("USD", 60.0)
        // удалили строку с курсором — база цела, суммы те же
        m.focus("RSD", rates)
        val before = m.all()
        m.remove("RSD", "EUR", rates)
        assertEquals("USD", m.base); assertEquals("USD", m.active)
        assertEquals(before, m.all())
        // удалили базовую — базой становится первая, с той суммой, что в ней показана
        val shown = m.converted("EUR", rates)!!
        m.remove("USD", "EUR", rates)
        assertEquals("EUR", m.base); assertEquals("EUR", m.active)
        assertEquals(shown, m.amount, 0.0)
        near(60 / 1.2 * 1.015, m.amount)
    }

    @Test fun removingBaseWithoutAdjustmentConvertsAmount() {
        val m = model()
        m.type("RSD", 5000.0)
        m.remove("RSD", "EUR", rates)
        near(5000 / 120.0, m.amount)      // а не 5000 EUR
        assertEquals("EUR", m.base)
    }

    @Test fun changingPercentKeepsBaseAndReturnsCursor() {
        val m = model(1.5)
        m.type("EUR", 100.0)
        m.focus("USD", rates)
        assertTrue(m.setAdjust(3.0))
        assertEquals("EUR", m.active)
        assertEquals(100.0, m.converted("EUR", rates)!!, 0.0)
        near(120 * 1.03, m.converted("USD", rates))
        assertFalse(m.setAdjust(3.0))                 // тот же процент — ничего не меняется
        assertTrue(m.setAdjust(0.0))
        near(120.0, m.converted("USD", rates))
        assertFalse(m.adjusted)
    }

    @Test fun clearMakesCursorRowTheBase() {
        val m = model(1.5)
        m.type("EUR", 100.0)
        m.focus("USD", rates)
        m.clear()
        assertEquals("USD", m.base)
        m.all().values.forEach { assertEquals(0.0, it, 0.0) }
    }

    @Test fun unknownCurrencyHasNoAmount() {
        val m = model(1.5)
        assertNull(m.converted("XXX", rates))
        assertNull(m.rate("XXX", rates))
    }

    @Test fun resetRule() {
        val h = 3_600_000L; val now = 1_800_000_000_000L
        assertTrue(RateAdjust.shouldReset(1.5, false, now, now + 5 * h))
        assertTrue(RateAdjust.shouldReset(-2.0, false, now, now + 4 * h + 1))
        assertFalse(RateAdjust.shouldReset(1.5, false, now, now + 4 * h))        // ровно 4 часа — ещё нет
        assertFalse(RateAdjust.shouldReset(1.5, false, now, now + 3 * h))
        assertFalse(RateAdjust.shouldReset(1.5, true, now, now + 500 * h))       // «Действует постоянно»
        assertFalse(RateAdjust.shouldReset(0.0, false, now, now + 500 * h))      // сбрасывать нечего
        assertTrue(RateAdjust.shouldReset(1.5, false, now, now - 60_000))        // часы ушли назад
        assertTrue(RateAdjust.shouldReset(1.5, false, 0L, now))                  // время ухода не записано
    }

    @Test fun labelAndClamp() {
        assertEquals("+1.5%", RateAdjust.label(1.5))
        assertEquals("−2%", RateAdjust.label(-2.0))
        assertEquals("+0.25%", RateAdjust.label(0.25))
        assertEquals("+5%", RateAdjust.label(5.0))
        assertEquals("+10%", RateAdjust.label(10.0))
        assertEquals("−0.5%", RateAdjust.label(-0.5))
        assertEquals(1.23, RateAdjust.clamp(1.234), 0.0)
        assertEquals(1.24, RateAdjust.clamp(1.235), 0.0)
        assertEquals(99.99, RateAdjust.clamp(500.0), 0.0)
        assertEquals(-99.99, RateAdjust.clamp(-500.0), 0.0)
        assertEquals(0.0, RateAdjust.clamp(Double.NaN), 0.0)
        assertEquals(0.0, RateAdjust.clamp(Double.POSITIVE_INFINITY), 0.0)
        assertEquals(1.015, RateAdjust.factor(1.5), 1e-12)
    }
}
