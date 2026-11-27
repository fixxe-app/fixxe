package com.example.currencyconverter

import android.app.Activity

/**
 * Сборка вне Google Play (APK с сайта, F-Droid) и отладочная: окна оценки нет.
 * Библиотека Google сюда не попадает — F-Droid не принимает закрытые зависимости,
 * а без Play оценку всё равно некуда поставить.
 */
object StoreReview {
    fun request(activity: Activity) = Unit
}
