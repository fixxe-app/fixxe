package com.example.currencyconverter

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import com.google.android.material.snackbar.Snackbar
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject
import java.util.concurrent.TimeUnit

/**
 * Сборка для раздачи вне Google Play.
 *
 * Приложение СЕБЯ НЕ ОБНОВЛЯЕТ: оно лишь сравнивает свою версию с той, что
 * указана на сайте, и предлагает открыть страницу загрузки. Скачивает и
 * устанавливает человек сам, через браузер. Поэтому не нужно разрешение
 * REQUEST_INSTALL_PACKAGES (Google выдаёт его только приложениям, чья основная
 * задача — установка пакетов) и нет самомодификации.
 *
 * В сборку для Play этот файл не попадает — там обновляет только магазин.
 */
object UpdateNotice {

    /** Последняя версия и ссылка на APK — на нашем сайте, рядом с самим файлом.
     *  Раздача идёт только со своего домена: где лежит исходный код, посетителя
     *  не касается. */
    private const val API = "https://telebimmer.com/fixxe/latest.json"
    private const val PAGE = "https://telebimmer.com/fixxe/about/"
    private const val PREFS = "axe_prefs"
    private const val LAST_CHECK = "update_last_check"
    private val INTERVAL_MS = TimeUnit.DAYS.toMillis(1)

    private val client = OkHttpClient.Builder()
        .connectTimeout(8, TimeUnit.SECONDS)
        .readTimeout(8, TimeUnit.SECONDS)
        .build()

    fun check(activity: Activity) {
        val prefs = activity.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val now = System.currentTimeMillis()
        // раз в сутки: чаще незачем, версия меняется не каждый день
        if (now - prefs.getLong(LAST_CHECK, 0L) < INTERVAL_MS) return

        CoroutineScope(Dispatchers.IO).launch {
            val latest = fetchLatest() ?: return@launch     // нет сети — молча выходим
            prefs.edit().putLong(LAST_CHECK, now).apply()
            if (latest.code <= currentVersionCode(activity)) return@launch
            withContext(Dispatchers.Main) {
                if (activity.isFinishing || activity.isDestroyed) return@withContext
                showBanner(activity, latest)
            }
        }
    }

    private data class Release(val code: Int, val name: String, val url: String)

    private fun fetchLatest(): Release? = try {
        val req = Request.Builder().url(API).build()
        client.newCall(req).execute().use { resp ->
            val body = resp.body?.string()
            if (!resp.isSuccessful || body.isNullOrEmpty()) null
            else JSONObject(body).let { o ->
                // latest.json кладёт release.sh рядом с APK
                val code = o.optInt("versionCode", 0)
                if (code == 0) return null
                // optString на JSON null возвращает строку "null" — отсекаем
                fun str(k: String) = if (o.isNull(k)) "" else o.optString(k)
                Release(code, str("versionName").ifEmpty { "1.$code" },
                        str("url").ifEmpty { PAGE })
            }
        }
    } catch (e: Exception) {
        null
    }

    private fun currentVersionCode(activity: Activity): Int = try {
        val info = activity.packageManager.getPackageInfo(activity.packageName, 0)
        @Suppress("DEPRECATION")
        info.versionCode
    } catch (e: Exception) {
        Int.MAX_VALUE   // не смогли определить — лучше промолчать, чем звать зря
    }

    private fun showBanner(activity: Activity, release: Release) {
        val root = activity.findViewById<android.view.View>(android.R.id.content) ?: return
        Snackbar.make(root, activity.getString(R.string.update_available, release.name),
                Snackbar.LENGTH_INDEFINITE)
            .setAction(R.string.update_open) {
                try {
                    activity.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(release.url)))
                } catch (e: Exception) {
                    // браузера нет — ничего не поделать, баннер просто закроется
                }
            }
            .show()
    }
}
