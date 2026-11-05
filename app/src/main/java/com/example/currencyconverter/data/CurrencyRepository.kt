package com.example.currencyconverter.data

import com.google.gson.Gson
import com.google.gson.JsonObject
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import java.util.concurrent.TimeUnit

/** Нормализованный снимок курсов: всё приведено к базе EUR. */
data class RatesSnapshot(
    val rates: Map<String, Double>,
    val source: String
)

/** Источник курсов для интерфейса. Номер в [CurrencyRepository.SOURCES] + 1 — значение настройки. */
data class SourceInfo(
    val name: String,
    val short: String,          // подпись на чипе в списке валют
    val color: Int,
    val site: String,           // куда ведёт подпись в подвале
    /** Только по ручному выбору в настройках: ни в «Авто», ни в резерв не
     *  попадает, в списке валют не показывается. Так подключён Wise — его
     *  адрес недокументирован и может исчезнуть без предупреждения. */
    val manualOnly: Boolean = false
) {
    /** Название в настройках */
    val title: String get() = if (manualOnly) "$name (beta)" else name
}

class CurrencyRepository(
    /** Загрузка по адресу. Подменяется в тестах: источники проверяются без сети. */
    private val loader: ((String) -> String)? = null
) {

    companion object {
        /**
         * Порядок = приоритет в режиме «Авто». Первые два — живые: обновляются
         * раз в минуту и идут вплотную к среднерыночному курсу. Следующие три
         * обновляются раз в сутки и остаются запасными. Номер + 1 хранится в
         * настройках, поэтому новые источники добавлять только в конец (или
         * переносить сохранённый выбор, см. [migrateSource]).
         */
        val SOURCES = listOf(
            SourceInfo("Coinbase", "Coinbase", 0xFF5E35B1.toInt(), "https://www.coinbase.com"),
            SourceInfo("FXRatesAPI", "FXRates", 0xFF00796B.toInt(), "https://fxratesapi.com"),
            SourceInfo("ExchangeRate-API", "er-api", 0xFF1565C0.toInt(), "https://www.exchangerate-api.com"),
            SourceInfo("F.A.", "F.A.", 0xFF43A047.toInt(), "https://github.com/fawazahmed0/exchange-api"),
            SourceInfo("Frankfurter (ECB)", "ECB", 0xFFFB8C00.toInt(), "https://frankfurter.dev"),
            SourceInfo("Wise", "Wise", 0xFF546E7A.toInt(), "https://wise.com", manualOnly = true),
        )

        /**
         * В каком порядке пробовать источники (имена). preferred: 0 — «Авто»,
         * 1..N — этот первым, остальные резервом. Источники «только вручную»
         * в резерв не идут: они участвуют, лишь когда выбраны сами.
         */
        fun order(preferred: Int): List<String> {
            val auto = SOURCES.filter { !it.manualOnly }.map { it.name }
            if (preferred !in 1..SOURCES.size) return auto
            val p = SOURCES[preferred - 1].name
            return listOf(p) + auto.filter { it != p }
        }

        /**
         * До 1.65 источников было три: 1 — ExchangeRate-API, 2 — F.A., 3 —
         * Frankfurter. Теперь перед ними встали Coinbase и FXRatesAPI, и
         * сохранённый выбор сдвигается на два — один раз, иначе у выбравшего
         * «F.A.» молча включился бы FXRatesAPI.
         */
        fun migrateSource(mode: Int, version: Int): Int =
            if (version < 2 && mode in 1..3) mode + 2 else mode

        /**
         * Курсы из JSON-объекта. Coinbase и FXRatesAPI отдают их строками и
         * вперемешку с мусором: «0.8899» → число; нули, отрицательные и
         * нечисловые значения отбрасываем. Коды — в верхний регистр.
         */
        fun numRates(obj: JsonObject?): Map<String, Double> {
            if (obj == null) return emptyMap()
            val map = HashMap<String, Double>(obj.size())
            for ((k, v) in obj.entrySet()) {
                try {
                    val d = v.asDouble
                    if (d > 0 && !d.isInfinite() && !d.isNaN()) map[k.uppercase()] = d
                } catch (_: Exception) { /* пропускаем нечисловые поля */ }
            }
            return map
        }

        /** Ответ Wise на одну пару: {"value": 117.6, ...} */
        fun wiseValue(body: String): Double? = try {
            Gson().fromJson(body, JsonObject::class.java).get("value").asDouble
                .takeIf { it > 0 && !it.isInfinite() && !it.isNaN() }
        } catch (_: Exception) { null }
    }

    private val client by lazy {
        OkHttpClient.Builder()
            .connectTimeout(8, TimeUnit.SECONDS)
            .readTimeout(8, TimeUnit.SECONDS)
            // иначе медленный сервер, отдающий по байту, держит запрос сколь угодно
            // долго, а с несколькими адресами по очереди — больше минуты
            .callTimeout(12, TimeUnit.SECONDS)
            .build()
    }

    private val gson = Gson()

    private fun load(url: String): String {
        loader?.let { return it(url) }
        val req = Request.Builder().url(url).build()
        client.newCall(req).execute().use { resp ->
            check(resp.isSuccessful) { "HTTP ${resp.code}" }
            return resp.body?.string() ?: error("пустой ответ")
        }
    }

    private class Source(
        val urls: List<String> = emptyList(),      // несколько зеркал: пробуем по очереди
        val parse: (String) -> Map<String, Double> = { emptyMap() },
        /** свой способ загрузки вместо «адрес + разбор»: получает валюты на экране */
        val fetch: (suspend (List<String>) -> Map<String, Double>?)? = null
    )

    private fun obj(body: String) = gson.fromJson(body, JsonObject::class.java)

    private val sources: Map<String, Source> = mapOf(
        "Coinbase" to Source(listOf("https://api.coinbase.com/v2/exchange-rates?currency=EUR"), { body ->
            numRates(obj(body).getAsJsonObject("data").getAsJsonObject("rates"))
        }),
        "FXRatesAPI" to Source(listOf("https://api.fxratesapi.com/latest?base=EUR"), { body ->
            val o = obj(body)
            // отказ (лимит, сбой) приходит с кодом 200 и success=false —
            // это ошибка источника, а не пустой набор курсов
            check(o.get("success")?.asBoolean == true) { "fxratesapi: success != true" }
            numRates(o.getAsJsonObject("rates"))
        }),
        "ExchangeRate-API" to Source(listOf("https://open.er-api.com/v6/latest/EUR"), { body ->
            val o = obj(body)
            check(o.get("result")?.asString == "success") { "er-api: result != success" }
            numRates(o.getAsJsonObject("rates"))
        }),
        "F.A." to Source(
            // Рекомендация автора API: jsDelivr основной, pages.dev — зеркало
            listOf(
                "https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/eur.json",
                "https://latest.currency-api.pages.dev/v1/currencies/eur.json"
            ), { body -> numRates(obj(body).getAsJsonObject("eur")) }),
        "Frankfurter (ECB)" to Source(listOf("https://api.frankfurter.dev/v1/latest?base=EUR"), { body ->
            // Frankfurter не включает саму базу EUR — добавляем EUR=1
            numRates(obj(body).getAsJsonObject("rates")).toMutableMap().apply { put("EUR", 1.0) }
        }),
        "Wise" to Source(fetch = { codes -> wiseRates(codes) }),
    )

    /** Wise отдаёт одну пару за запрос — спрашиваем только валюты на экране. */
    private suspend fun wiseRates(codes: List<String>): Map<String, Double>? = coroutineScope {
        val wanted = codes.filter { it != "EUR" && it.all(Char::isLetterOrDigit) }.distinct()
        val got = wanted.map { c ->
            async(Dispatchers.IO) {
                c to try { wiseValue(load("https://wise.com/rates/live?source=EUR&target=$c")) } catch (_: Exception) { null }
            }
        }.awaitAll()
        val out = HashMap<String, Double>()
        out["EUR"] = 1.0
        for ((c, v) in got) if (v != null) out[c] = v
        if (out.size >= 2) out else null
    }

    /**
     * Пробует источники по очереди, возвращает первый успешный.
     * @param preferred 0 = авто; 1..N = поставить этот источник первым, остальные
     *   остаются резервом (чтобы приложение не осталось без данных).
     * @param codes валюты на экране — нужны источникам, которые отдают курсы по одной паре.
     */
    suspend fun getRates(preferred: Int = 0, codes: List<String> = emptyList()): Result<RatesSnapshot> =
        withContext(Dispatchers.IO) {
            var lastError: Throwable? = null
            for (name in order(preferred)) {
                val src = sources.getValue(name)
                if (src.fetch != null) {
                    try {
                        val rates = src.fetch.invoke(codes)
                        check(rates != null && rates.size >= 2) { "слишком мало курсов" }
                        return@withContext Result.success(RatesSnapshot(rates, name))
                    } catch (e: Exception) { lastError = e }
                    continue
                }
                for (url in src.urls) {
                    try {
                        val rates = src.parse(load(url))
                        check(rates.size >= 2) { "слишком мало курсов" }
                        return@withContext Result.success(RatesSnapshot(rates, name))
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

        // Coinbase отдаёт 600+ кодов, большей частью мелкие крипто-токены. В
        // списке «Добавить валюту» от живых источников остаётся только то,
        // что знают справочные три: список не разбухает втрое.
        val known = res.values.flatten().toSet()
        for (name in listOf("Coinbase", "FXRatesAPI")) {
            val src = sources.getValue(name)
            val codes = try { src.parse(load(src.urls.first())).keys } catch (_: Exception) { emptySet() }
            if (codes.isNotEmpty()) res[name] = if (known.isEmpty()) codes.toSet() else codes.intersect(known)
        }
        res
    }

    private fun fetchCodes(url: String, extract: (JsonObject) -> Set<String>?): Set<String>? = try {
        extract(obj(load(url)))
    } catch (e: Exception) { null }
}
