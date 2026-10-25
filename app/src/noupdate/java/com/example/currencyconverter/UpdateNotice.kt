package com.example.currencyconverter

import android.app.Activity

/**
 * Сборка для Google Play: приложение обновляется только магазином.
 * Любая собственная проверка обновлений здесь была бы нарушением
 * Device and Network Abuse policy, поэтому вариант пустой.
 */
object UpdateNotice {
    fun check(activity: Activity) = Unit
}
