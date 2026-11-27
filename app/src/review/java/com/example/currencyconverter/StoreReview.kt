package com.example.currencyconverter

import android.app.Activity
import com.google.android.play.core.review.ReviewManagerFactory

/**
 * Сборка для Google Play: системное окно оценки (In-App Review API) прямо в
 * приложении. Когда просить — решает ui/ReviewAsk; показать ли окно — Google.
 */
object StoreReview {
    fun request(activity: Activity) {
        val manager = ReviewManagerFactory.create(activity)
        manager.requestReviewFlow().addOnCompleteListener { task ->
            if (task.isSuccessful && !activity.isFinishing && !activity.isDestroyed)
                manager.launchReviewFlow(activity, task.result)
        }
    }
}
