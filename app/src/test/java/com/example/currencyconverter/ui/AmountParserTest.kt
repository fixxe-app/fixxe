package com.example.currencyconverter.ui

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Разбор суммы. Главный случай — запятая как десятичный знак: на цифровой
 * клавиатуре в России, Сербии, Германии это запятая, и раньше при группировке
 * «запятая» «1,5» молча становилось 15.
 */
class AmountParserTest {
    private fun p(s: String, g: Int = 0) = AmountParser.parse(s, g)
    private val NONE = 0; private val SPACE = 1; private val COMMA = 2

    @Test fun decimalComma_isDecimal_inEveryGroupingMode() {
        assertEquals(1.5, p("1,5", NONE), 1e-12)
        assertEquals(1.5, p("1,5", SPACE), 1e-12)
        assertEquals(1.5, p("1,5", COMMA), 1e-12)   // было 15
    }
    @Test fun decimalDot() = assertEquals(2.5, p("2.5"), 1e-12)
    @Test fun bothSeparators_rightmostIsDecimal() {
        assertEquals(1234.56, p("1,234.56"), 1e-9)  // было 1.234
        assertEquals(1234.56, p("1.234,56"), 1e-9)
    }
    @Test fun spacesAreGrouping() {
        assertEquals(1234.56, p("1 234,56"), 1e-9)
        assertEquals(1234.56, p("1 234,56", COMMA), 1e-9)   // было 123456
    }
    @Test fun repeatedSeparatorIsGrouping() {
        assertEquals(1234567.0, p("1,234,567"), 1e-9)
        assertEquals(1234567.0, p("1.234.567"), 1e-9)
    }
    @Test fun commaThousands_onlyWhenChosenAndExactGroups() {
        assertEquals(1500.0, p("1,500", COMMA), 1e-9)
        assertEquals(1.5, p("1,500", NONE), 1e-9)
    }
    @Test fun garbageIsZero() {
        for (s in listOf("", ",", ".", "-", "abc")) assertEquals(0.0, p(s), 0.0)
        assertEquals(0.0, p("1e999"), 0.0)   // бесконечность — не сумма
    }
}
