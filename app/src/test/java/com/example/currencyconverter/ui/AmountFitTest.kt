package com.example.currencyconverter.ui

import org.junit.Assert.assertEquals
import org.junit.Test

/** Длинная сумма уменьшается, только когда не влезает, и не меньше половины. */
class AmountFitTest {
    @Test fun fitsKeepsNormalSize() {
        assertEquals(22f, AmountFit.size(22f, 100f, 130f), 0f)
        assertEquals(22f, AmountFit.size(22f, 130f, 130f), 0f)
    }

    @Test fun tooWideShrinksJustEnough() {
        val size = AmountFit.size(22f, 200f, 130f)
        assertEquals(22f * 130f / 200f, size, 0.001f)
        assertEquals(130f, 200f * size / 22f, 0.001f)     // при этом размере ровно влезает
    }

    @Test fun neverBelowHalf() = assertEquals(11f, AmountFit.size(22f, 1000f, 130f), 0f)

    @Test fun emptyOrUnlaidKeepsNormalSize() {
        assertEquals(22f, AmountFit.size(22f, 0f, 130f), 0f)
        assertEquals(22f, AmountFit.size(22f, 200f, 0f), 0f)
    }
}
