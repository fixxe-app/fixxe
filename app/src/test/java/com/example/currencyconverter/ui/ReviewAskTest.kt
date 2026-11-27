package com.example.currencyconverter.ui

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** Просьба об оценке: не раньше 50-го открытия и 14 дней, второй раз — втрое позже, не больше двух. */
class ReviewAskTest {
    private val min = 60_000L
    private val day = 24 * 60 * min
    private val t0 = 1_800_000_000_000L

    /** [n] открытий раз в [every] начиная с [from]; между ними приложение уходит с экрана. */
    private fun visits(s0: ReviewAsk.State, n: Int, from: Long, every: Long): Pair<ReviewAsk.State, Long> {
        var s = s0; var now = from; var left = 0L
        repeat(n) { s = ReviewAsk.opened(s, now, left); left = now + min; now += every }
        return s to (now - every)
    }

    @Test fun firstOpenStartsTheClock() {
        val s = ReviewAsk.opened(ReviewAsk.State(), t0, 0)
        assertEquals(1, s.opens); assertEquals(t0, s.firstAt)
    }

    @Test fun quickSwitchIsNotANewOpen() {
        var s = ReviewAsk.opened(ReviewAsk.State(), t0, 0)
        s = ReviewAsk.opened(s, t0 + 10 * min, t0 + 5 * min)       // ушёл на 5 минут
        assertEquals(1, s.opens)
        s = ReviewAsk.opened(s, t0 + 60 * min, t0 + 20 * min)      // перерыв 40 минут
        assertEquals(2, s.opens)
    }

    @Test fun notBefore50Opens() {
        val (s, now) = visits(ReviewAsk.State(), 49, t0, day)      // 49 открытий за 48 дней
        assertFalse(ReviewAsk.due(s, now))
        assertTrue(ReviewAsk.due(ReviewAsk.opened(s, now + day, now + min), now + day))
    }

    @Test fun notBefore14Days() {
        val (s, now) = visits(ReviewAsk.State(), 60, t0, 4 * 60 * min)   // 60 открытий за 10 дней
        assertFalse(ReviewAsk.due(s, now))
        assertTrue(ReviewAsk.due(s, t0 + 14 * day))
    }

    @Test fun secondTimeOnlyThreeTimesLaterAndAfter100MoreOpens() {
        val (s1, now1) = visits(ReviewAsk.State(), 50, t0, day)
        assertTrue(ReviewAsk.due(s1, now1))
        val a = ReviewAsk.asked(s1, now1)
        assertFalse("сразу после просьбы — нет", ReviewAsk.due(a, now1))
        val (s2, _) = visits(a, 100, now1 + day, 6 * 60 * min)        // 100 открытий за 25 дней
        assertFalse("100 открытий есть, а 42 дней нет", ReviewAsk.due(s2, now1 + 41 * day))
        assertTrue(ReviewAsk.due(s2, now1 + 42 * day))
        val (s3, _) = visits(a, 99, now1 + day, day)                  // 99 открытий за 99 дней
        assertFalse("42 дня прошло, а 100 открытий нет", ReviewAsk.due(s3, now1 + 100 * day))
    }

    @Test fun neverMoreThanTwice() {
        var s = ReviewAsk.State(opens = 50, firstAt = t0)
        s = ReviewAsk.asked(s, t0 + 20 * day)
        s = ReviewAsk.asked(s.copy(opens = 200), t0 + 70 * day)
        assertFalse(ReviewAsk.due(s.copy(opens = 10_000), t0 + 3650 * day))
    }
}
