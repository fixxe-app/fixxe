package com.example.currencyconverter.ui

/**
 * Сколько помнить введённую сумму — выбор в настройках.
 *
 * Сумма и строка, где её набрали, записываются, когда приложение уходит с
 * экрана. Срок считается от этого момента — как у поправки к курсу.
 *   SESSION — только пока приложение в памяти: выгрузили или закрыли — снова 1;
 *   H12, H24 — после перерыва дольше срока снова 1, даже если приложение
 *              ещё в памяти;
 *   FOREVER — пока сумму не поменяют.
 * «Снова 1» — как при первом запуске: 1 в первой валюте списка.
 * Без Android — проверяется обычными тестами.
 */
object AmountMemory {
    const val SESSION = 0
    const val H12 = 1
    const val H24 = 2
    const val FOREVER = 3
    /** По умолчанию — 12 часов: день поездки помнит, к утру начинает заново. */
    const val DEFAULT = H12

    private const val HOUR = 60 * 60 * 1000L

    private fun limit(mode: Int): Long? = when (mode) {
        H12 -> 12 * HOUR
        H24 -> 24 * HOUR
        else -> null
    }

    /** Холодный запуск: вернуть ли сумму, записанную при уходе с экрана в [leftAt]. */
    fun restoreOnLaunch(mode: Int, leftAt: Long, now: Long): Boolean = when (mode) {
        FOREVER -> true
        H12, H24 -> !expired(mode, leftAt, now)
        else -> false
    }

    /** Возврат в приложение, которое было в памяти: вышел ли срок. У SESSION
     *  и FOREVER срока нет. Часы ушли назад — тоже сброс: так безопаснее. */
    fun expired(mode: Int, leftAt: Long, now: Long): Boolean {
        val l = limit(mode) ?: return false
        return now - leftAt > l || now < leftAt
    }
}
