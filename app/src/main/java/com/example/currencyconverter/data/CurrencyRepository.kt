package com.example.currencyconverter.data

import com.google.gson.Gson
import com.google.gson.JsonObject
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import java.util.concurrent.TimeUnit

/** Нормализованный снимок курсов: всё приведено к базе EUR. */
data class RatesSnapshot(
    val rates: Map<String, Double>,
    val source: String
)

class CurrencyRepository {

    private val client = OkHttpClient.Builder()
        .connectTimeout(8, TimeUnit.SECONDS)
        .readTimeout(8, TimeUnit.SECONDS)
        // иначе медленный сервер, отдающий по байту, держит запрос сколь угодно
        // долго, а с четырьмя адресами по очереди — больше минуты
        .callTimeout(12, TimeUnit.SECONDS)
        .build()

    private val gson = Gson()

    private data class Source(
        val name: String,
        val urls: List<String>,       // несколько зеркал: пробуем по очереди
        val parse: (String) -> Map<String, Double>
    )

    // Порядок = приоритет. Основной первый, дальше фоллбэки.
    private val sources = listOf(
        Source(
            "ExchangeRate-API",
            listOf("https://open.er-api.com/v6/latest/EUR")
        ) { body ->
            val o = gson.fromJson(body, JsonObject::class.java)
            check(o.get("result")?.asString == "success") { "er-api: result != success" }
            parseRates(o.getAsJsonObject("rates"))
        },
        Source(
            "F.A.",
            // Рекомендация автора API: jsDelivr основной, pages.dev — зеркало
            listOf(
                "https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/eur.json",
                "https://latest.currency-api.pages.dev/v1/currencies/eur.json"
            )
        ) { body ->
            val o = gson.fromJson(body, JsonObject::class.java)
            // Коды в нижнем регистре → приводим к верхнему как у остальных источников
            parseRates(o.getAsJsonObject("eur")).mapKeys { it.key.uppercase() }
        },
        Source(
            "Frankfurter (ECB)",
            listOf("https://api.frankfurter.dev/v1/latest?base=EUR")
        ) { body ->
            val o = gson.fromJson(body, JsonObject::class.java)
            // Frankfurter не включает саму базу EUR — добавляем EUR=1
            parseRates(o.getAsJsonObject("rates")).toMutableMap().apply { put("EUR", 1.0) }
        }
    )

    /**
     * Пробует источники по очереди, возвращает первый успешный.
     * @param preferred 0 = авто (обычный порядок); 1..N = поставить этот источник первым,
     *   остальные остаются резервом (чтобы приложение не осталось без данных).
     */
    suspend fun getRates(preferred: Int = 0): Result<RatesSnapshot> = withContext(Dispatchers.IO) {
        val ordered = if (preferred in 1..sources.size) {
            val idx = preferred - 1
            listOf(sources[idx]) + sources.filterIndexed { i, _ -> i != idx }
        } else sources

        var lastError: Throwable? = null
        for (src in ordered) {
            for (url in src.urls) {
                try {
                    val req = Request.Builder().url(url).build()
                    client.newCall(req).execute().use { resp ->
                        check(resp.isSuccessful) { "HTTP ${resp.code}" }
                        val body = resp.body?.string() ?: error("пустой ответ")
                        val rates = src.parse(body)
                        check(rates.size >= 2) { "слишком мало курсов" }
                        return@withContext Result.success(RatesSnapshot(rates, src.name))
                    }
                } catch (e: Exception) {
                    lastError = e   // пробуем следующее зеркало / источник
                }
            }
        }
        Result.failure(lastError ?: Exception("Нет доступных источников"))
    }

    /** Списки кодов валют по каждому источнику (какая валюта где есть). Best-effort. */
    suspend fun fetchSourceCodes(): Map<String, Set<String>> = withContext(Dispatchers.IO) {
        val res = LinkedHashMap<String, Set<String>>()
        fetchCodes("https://open.er-api.com/v6/latest/EUR") { o ->
            if (o.get("result")?.asString == "success") o.getAsJsonObject("rates").keySet().toSet() else null
        }?.let { res["ExchangeRate-API"] = it }

        (fetchCodes("https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies.json") { o ->
            o.keySet().map { it.uppercase() }.toSet()
        } ?: fetchCodes("https://latest.currency-api.pages.dev/v1/currencies.json") { o ->
            o.keySet().map { it.uppercase() }.toSet()
        })?.let { res["F.A."] = it }

        fetchCodes("https://api.frankfurter.dev/v1/currencies") { o ->
            o.keySet().toMutableSet().apply { add("EUR") }
        }?.let { res["Frankfurter (ECB)"] = it }

        res
    }

    private fun fetchCodes(url: String, extract: (JsonObject) -> Set<String>?): Set<String>? = try {
        val req = Request.Builder().url(url).build()
        client.newCall(req).execute().use { resp ->
            if (!resp.isSuccessful) null
            else resp.body?.string()?.let { extract(gson.fromJson(it, JsonObject::class.java)) }
        }
    } catch (e: Exception) { null }

    private fun parseRates(obj: JsonObject?): Map<String, Double> {
        if (obj == null) return emptyMap()
        val map = HashMap<String, Double>(obj.size())
        for ((k, v) in obj.entrySet()) {
            try {
                val d = v.asDouble
                if (d > 0) map[k] = d
            } catch (_: Exception) { /* пропускаем нечисловые поля */ }
        }
        return map
    }
}
