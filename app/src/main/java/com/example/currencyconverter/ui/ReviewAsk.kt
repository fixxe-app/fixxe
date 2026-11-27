package com.example.currencyconverter.ui

import java.util.concurrent.TimeUnit

/**
 * Когда попросить оценку в магазине: 1-й раз — от 50 открытий и 14 дней, 2-й — через 42 дня
 * и ещё 100 открытий, больше — никогда. Открытие — возврат после перерыва от 30 минут.
 * Оценил ли человек, магазины не сообщают; показать ли окно, решают сами. Копия — iOS ReviewAsk.swift.
 */
object ReviewAsk {
    const val MIN_OPENS = 50
    const val MIN_DAYS = 14L
    const val AGAIN_OPENS = 100
    const val AGAIN_DAYS = 42L
    const val MAX_ASKS = 2
    const val BREAK_MIN = 30L
    /** Пауза после ввода суммы: не посреди набора. */
    const val QUIET_MS = 3_000L

    data class State(
        val opens: Int = 0,
        val firstAt: Long = 0,
        val asks: Int = 0,
        val lastAskAt: Long = 0,
        val opensAtAsk: Int = 0,
    )

    /** Приложение вышло на экран. [leftAt] — когда уходило с экрана в прошлый раз (0 — не уходило). */
    fun opened(s: State, now: Long, leftAt: Long): State {
        val first = if (s.firstAt > 0) s.firstAt else now
        val isNewVisit = leftAt <= 0 || now < leftAt || now - leftAt >= TimeUnit.MINUTES.toMillis(BREAK_MIN)
        return s.copy(opens = if (isNewVisit) s.opens + 1 else s.opens, firstAt = first)
    }

    /** Пора ли просить. */
    fun due(s: State, now: Long): Boolean = when {
        s.asks >= MAX_ASKS || s.firstAt <= 0 -> false
        s.asks == 0 -> s.opens >= MIN_OPENS && now - s.firstAt >= TimeUnit.DAYS.toMillis(MIN_DAYS)
        else -> s.opens - s.opensAtAsk >= AGAIN_OPENS && now - s.lastAskAt >= TimeUnit.DAYS.toMillis(AGAIN_DAYS)
    }

    /** Попросили. */
    fun asked(s: State, now: Long): State = s.copy(asks = s.asks + 1, lastAskAt = now, opensAtAsk = s.opens)
}
