package com.example.currencyconverter.ui

import com.example.currencyconverter.ui.AmountMemory.FOREVER
import com.example.currencyconverter.ui.AmountMemory.H12
import com.example.currencyconverter.ui.AmountMemory.H24
import com.example.currencyconverter.ui.AmountMemory.SESSION
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** Сколько помнить введённую сумму: 4 варианта из настроек. */
class AmountMemoryTest {
    private val h = 60 * 60 * 1000L
    private val now = 1_000 * 24 * h

    @Test fun defaultIs12Hours() = assertEquals(H12, AmountMemory.DEFAULT)

    @Test fun sessionNeverRestoresAfterLaunchAndNeverExpiresInMemory() {
        assertFalse(AmountMemory.restoreOnLaunch(SESSION, now - 1000, now))
        assertFalse(AmountMemory.expired(SESSION, now - 100 * 24 * h, now))
    }

    @Test fun twelveHours() {
        assertTrue(AmountMemory.restoreOnLaunch(H12, now - 11 * h, now))
        assertFalse(AmountMemory.restoreOnLaunch(H12, now - 13 * h, now))
        assertFalse(AmountMemory.expired(H12, now - 11 * h, now))
        assertTrue(AmountMemory.expired(H12, now - 13 * h, now))
    }

    @Test fun twentyFourHours() {
        assertTrue(AmountMemory.restoreOnLaunch(H24, now - 13 * h, now))
        assertTrue(AmountMemory.restoreOnLaunch(H24, now - 23 * h, now))
        assertFalse(AmountMemory.restoreOnLaunch(H24, now - 25 * h, now))
        assertTrue(AmountMemory.expired(H24, now - 25 * h, now))
    }

    @Test fun foreverRestoresAfterMonthsAndNeverExpires() {
        assertTrue(AmountMemory.restoreOnLaunch(FOREVER, now - 90 * 24 * h, now))
        assertFalse(AmountMemory.expired(FOREVER, now - 90 * 24 * h, now))
    }

    @Test fun neverLeftOrClockWentBackMeansFreshStart() {
        assertFalse(AmountMemory.restoreOnLaunch(H12, 0L, now))          // ещё ни разу не уходили с экрана
        assertTrue(AmountMemory.expired(H24, now + h, now))              // часы ушли назад
        assertFalse(AmountMemory.restoreOnLaunch(H24, now + h, now))
    }
}
