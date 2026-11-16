package com.example.currencyconverter.ui

import org.junit.Assert.assertEquals
import org.junit.Test

class AmountFormatTest {
    private fun up(v: Double, d: Int = 0, g: Int = 0) = AmountFormat.format(v, d, g, roundUp = true)
    private fun near(v: Double, d: Int = 0, g: Int = 0) = AmountFormat.format(v, d, g, roundUp = false)

    @Test fun upNeverShowsLess() {
        assertEquals("113", up(112.06))
        assertEquals("1.13", up(1.1206, 2))
        assertEquals("11.1", up(11.01))   // «12» исказило бы сумму больше чем на 2%
    }

    @Test fun nearestRoundsBothWays() {
        assertEquals("112", near(112.06))
        assertEquals("113", near(112.5))
        assertEquals("1.12", near(1.1206, 2))
        assertEquals("11", near(11.01))
    }

    @Test fun exactValuesStayExact() {
        assertEquals("100", up(100.0))
        assertEquals("100", near(100.0))
        assertEquals("117.40", up(117.4, 2))
    }

    @Test fun smallAmountsKeepMeaning() {
        // 0.0067 не превращается ни в 0, ни в 1: знаки добавляются, пока ошибка больше 2%
        assertEquals("0.0067", up(0.0067))
        assertEquals("0.0067", near(0.0067))
        assertEquals("0.34", near(0.3412))
        assertEquals("0.342", up(0.3412))
    }

    @Test fun zeroAndGrouping() {
        assertEquals("0", near(0.0))
        assertEquals("0.00", up(0.0, 2))
        assertEquals("11 742", up(11741.2, 0, 1))
        assertEquals("11 741", near(11741.2, 0, 1))
        assertEquals("1,234,568", near(1234567.6, 0, 2))
    }
}
