package com.example.currencyconverter.ui

import android.app.Application
import android.content.Context
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.example.currencyconverter.data.CurrencyRepository
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

data class UiState(
    val currencyItems: List<CurrencyItem> = emptyList(),
    val activeCurrency: String = "EUR",
    val isLoading: Boolean = true,
    val lastUpdated: String = "",
    val source: String = "",
    val totalCurrencies: Int = 0,
    val error: String? = null,
    /** данные показаны из кэша (сеть недоступна) */
    val fromCache: Boolean = false,
    /** кэшу больше суток — курсы могли устареть */
    val stale: Boolean = false,
    val decimalPlaces: Int = 0,
    /** разделитель разрядов: 0 — нет, 1 — пробел, 2 — запятая */
    val grouping: Int = 0
)

class CurrencyViewModel(app: Application) : AndroidViewModel(app) {

    private val prefs = app.getSharedPreferences("axe_prefs", Context.MODE_PRIVATE)
    private val repository = CurrencyRepository()

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    private var allRates: Map<String, Double> = emptyMap()
    private val displayCurrencies = loadCurrencies()
    private var activeCurrency = displayCurrencies.firstOrNull() ?: "EUR"
    private var activeAmount = 1.0
    private var refreshJob: Job? = null

    private fun loadCurrencies(): MutableList<String> {
        val saved = prefs.getString("currencies", null)
        return if (saved != null) saved.split(",").toMutableList()
        else mutableListOf("EUR", "USD", "RSD", "GEL", "ILS", "TJS", "CHF")
    }

    private fun saveCurrencies() {
        prefs.edit().putString("currencies", displayCurrencies.joinToString(",")).apply()
    }

    fun getDecimalPlaces(): Int = prefs.getInt("decimal_places", 0)

    fun setDecimalPlaces(n: Int) {
        prefs.edit().putInt("decimal_places", n).apply()
        _state.value = _state.value.copy(decimalPlaces = n)
    }

    // Разделитель разрядов: 0 — нет, 1 — пробел, 2 — запятая
    fun getGrouping(): Int = prefs.getInt("grouping", 0)

    fun setGrouping(mode: Int) {
        prefs.edit().putInt("grouping", mode).apply()
        _state.value = _state.value.copy(grouping = mode)
    }

    // 0 = Авто (цепочка с резервом), 1..3 = принудительно конкретный источник
    fun getSourceMode(): Int = prefs.getInt("rate_source", 0)

    fun setSourceMode(mode: Int) {
        prefs.edit().putInt("rate_source", mode).apply()
        refresh(force = true)  // сразу перезапрашиваем с новым источником
    }

    init {
        _state.value = _state.value.copy(decimalPlaces = getDecimalPlaces(), grouping = getGrouping())
        showCached()   // мгновенный старт с последними известными курсами
        refresh()
        // автообновление включает и выключает экран: см. resumeAutoRefresh()
    }

    /** Курсы держим в кэше: без сети приложение всё равно считает,
     *  а если кэшу больше суток — интерфейс об этом предупреждает. */
    private fun cacheRates(rates: Map<String, Double>, source: String) {
        val payload = rates.entries.joinToString(",") { "${it.key}=${it.value}" }
        prefs.edit()
            .putString("cached_rates", payload)
            .putString("cached_source", source)
            .putLong("cached_at", System.currentTimeMillis())
            .apply()
    }

    private fun loadCachedRates(): Triple<Map<String, Double>, String, Long>? {
        val payload = prefs.getString("cached_rates", null) ?: return null
        val at = prefs.getLong("cached_at", 0L)
        if (at == 0L) return null
        val rates = payload.split(",").mapNotNull {
            val parts = it.split("=")
            val v = parts.getOrNull(1)?.toDoubleOrNull()
            if (parts.size == 2 && v != null) parts[0] to v else null
        }.toMap()
        if (rates.isEmpty()) return null
        return Triple(rates, prefs.getString("cached_source", "") ?: "", at)
    }

    private fun isStale(at: Long) = System.currentTimeMillis() - at > 24 * 60 * 60 * 1000L

    private fun formatTime(at: Long) =
        SimpleDateFormat("dd MMM yyyy HH:mm", Locale.getDefault()).format(Date(at))

    /** Показать кэш, пока идёт (или не удался) сетевой запрос. */
    private fun showCached() {
        val cached = loadCachedRates() ?: return
        val (rates, source, at) = cached
        allRates = rates
        _state.value = _state.value.copy(
            lastUpdated = formatTime(at),
            source = source,
            totalCurrencies = rates.size,
            fromCache = true,
            stale = isStale(at),
            currencyItems = buildItems()
        )
    }

    /** Момент последнего запроса к API — чтобы частые нажатия «обновить»
     *  не превращались в поток обращений к источникам. */
    private var lastFetchAt = 0L

    /** Пока шёл запрос, попросили принудительное обновление (сменили источник,
     *  добавили валюту из другого источника) — выполним его сразу после. */
    private var pendingForce = false

    /** Идёт ли сейчас запрос. Отдельно от UiState.isLoading: тот взводится
     *  ещё до первого запроса (экран сразу показывает «загрузка»), и если
     *  проверять его, самый первый refresh отсечёт сам себя и курсы
     *  никогда не загрузятся. */
    private var fetching = false

    fun refresh(force: Boolean = false) {
        // пока запрос идёт, повторные нажатия игнорируем — но принудительный
        // запрос не выбрасываем: его ответ нужен с новым источником
        if (fetching) { if (force) pendingForce = true; return }
        // монотонные часы: перевод системного времени назад не должен
        // запирать кнопку «обновить» на сутки
        val now = android.os.SystemClock.elapsedRealtime()
        if (!force && now - lastFetchAt < MIN_FETCH_INTERVAL_MS) return
        fetching = true
        lastFetchAt = now
        viewModelScope.launch {
            // Метка для smoke-теста: по ней он считает, сколько запросов реально
            // ушло (холодный старт — ровно один, частые нажатия — ни одного лишнего).
            android.util.Log.d(FETCH_TAG, "rates fetch")
            _state.value = _state.value.copy(isLoading = true, error = null)
            try {
            repository.getRates(getSourceMode()).fold(
                onSuccess = { snap ->
                    allRates = snap.rates
                    cacheRates(snap.rates, snap.source)
                    // Показываем ВРЕМЯ НАШЕГО запроса — чтобы refresh был виден
                    val fetchTime = SimpleDateFormat("dd MMM yyyy HH:mm", Locale.getDefault())
                        .format(Date())
                    _state.value = _state.value.copy(
                        isLoading = false,
                        lastUpdated = fetchTime,
                        source = snap.source,
                        totalCurrencies = snap.rates.size,
                        fromCache = false,
                        stale = false,
                        currencyItems = buildItems()
                    )
                },
                onFailure = { e ->
                    val cached = loadCachedRates()
                    if (cached != null) {
                        // сеть недоступна — считаем по последним известным курсам
                        val (rates, source, at) = cached
                        allRates = rates
                        _state.value = _state.value.copy(
                            isLoading = false,
                            error = null,
                            lastUpdated = formatTime(at),
                            source = source,
                            totalCurrencies = rates.size,
                            fromCache = true,
                            stale = isStale(at),
                            currencyItems = buildItems()
                        )
                    } else {
                        _state.value = _state.value.copy(
                            isLoading = false,
                            error = e.message ?: "Network error"
                        )
                    }
                }
            )
            } finally {
                // что бы ни случилось — запрос больше не «идёт», кнопка жива
                fetching = false
                if (pendingForce) { pendingForce = false; refresh(force = true) }
            }
        }
    }

    fun setActiveAmount(currency: String, amount: Double) {
        activeCurrency = currency
        activeAmount = amount
        if (allRates.isEmpty()) return
        _state.value = _state.value.copy(
            activeCurrency = currency,
            currencyItems = buildItems()
        )
    }

    fun clearAll() {
        activeAmount = 0.0
        // Пустой activeCurrency → адаптер вызовет notifyDataSetChanged() → все EditText обнулятся
        _state.value = _state.value.copy(
            activeCurrency = "",
            currencyItems = buildItems()
        )
        // Восстанавливаем activeCurrency без emit — пользователь выберет поле сам
        activeCurrency = displayCurrencies.firstOrNull() ?: "EUR"
    }

    fun addCurrency(code: String) {
        if (!displayCurrencies.contains(code)) {
            displayCurrencies.add(code)
            saveCurrencies()
            _state.value = _state.value.copy(currencyItems = buildItems())
        }
    }

    fun removeCurrency(code: String) {
        if (displayCurrencies.size <= 2) return
        displayCurrencies.remove(code)
        if (activeCurrency == code) {
            // Сумму переводим в новую валюту, а не переносим как есть:
            // иначе 5000 RSD после удаления RSD становились 5000 EUR.
            val next = displayCurrencies.first()
            val from = allRates[code]; val to = allRates[next]
            if (from != null && to != null && from != 0.0) activeAmount = activeAmount / from * to
            activeCurrency = next
        }
        saveCurrencies()
        _state.value = _state.value.copy(activeCurrency = activeCurrency, currencyItems = buildItems())
    }

    fun reorderCurrencies(newOrder: List<String>) {
        displayCurrencies.clear()
        displayCurrencies.addAll(newOrder)
        saveCurrencies()
        // Пока строку тащили, список не принимал обновлений; если за это время
        // пришли курсы, без этой строки суммы остались бы старыми.
        _state.value = _state.value.copy(currencyItems = buildItems())
    }

    fun getAvailableCurrencies(): List<CurrencyInfo> =
        allRates.keys
            .filter { it !in displayCurrencies }
            .sorted()
            .map { CurrencyInfo(it, currencyDisplayName(it)) }

    // Все валюты (для окна добавления) — уже добавленные показываем серыми
    fun getAllCurrencies(): List<CurrencyInfo> =
        allRates.keys.sorted().map { CurrencyInfo(it, currencyDisplayName(it)) }

    fun isAdded(code: String): Boolean = displayCurrencies.contains(code)

    // --- Источники: какая валюта где доступна ---
    private var sourceCodes: Map<String, Set<String>> = emptyMap()
    private val sourceNames = listOf("ExchangeRate-API", "F.A.", "Frankfurter (ECB)")

    fun sourceCodesLoaded() = sourceCodes.isNotEmpty()

    fun loadSourceCodes(onDone: () -> Unit) {
        // @Suppress: поле инициализируется ниже по файлу, вызов до этого момента дал бы NPE
        @Suppress("SENSELESS_COMPARISON")
        if (sourceCodes != null && sourceCodes.isNotEmpty()) { onDone(); return }
        viewModelScope.launch {
            sourceCodes = repository.fetchSourceCodes()
            onDone()
        }
    }

    // Индексы источников (0=er-api,1=F.A.,2=Frankfurter), где есть код
    fun sourcesWith(code: String): List<Int> =
        sourceNames.mapIndexedNotNull { i, n -> if (sourceCodes[n]?.contains(code) == true) i else null }

    fun codesForSource(idx: Int): Set<String> = sourceCodes[sourceNames.getOrNull(idx)] ?: emptySet()

    // Объединение всех валют (активный источник + все списки)
    fun allCurrencyCodesUnion(): List<String> {
        val u = HashSet(allRates.keys)
        sourceCodes.values.forEach { u.addAll(it) }
        return u.sorted().map { it }
    }

    fun isInActiveSource(code: String) = allRates.containsKey(code)

    /** Сколько валют можно добавить: объединение всех источников минус уже добавленные. */
    fun addableCount(): Int =
        (allCurrencyCodesUnion().size - displayCurrencies.size).coerceAtLeast(0)

    // Принудительно переключить источник и добавить валюту
    fun switchSourceAndAdd(code: String, srcIdx: Int) {
        prefs.edit().putInt("rate_source", srcIdx + 1).apply()
        if (!displayCurrencies.contains(code)) { displayCurrencies.add(code); saveCurrencies() }
        refresh(force = true)
    }

    private fun buildItems(): List<CurrencyItem> {
        if (allRates.isEmpty()) return emptyList()
        val activeRateInEur = allRates[activeCurrency] ?: 1.0
        val amountInEur = if (activeRateInEur != 0.0) activeAmount / activeRateInEur else 0.0

        // Динамическая база отображения = активная валюта (та, что вводишь/меняешь).
        // Если активной нет в таблице (напр. кадр во время CLEAR) — показываем от EUR.
        val pivot = if (allRates.containsKey(activeCurrency)) activeCurrency else "EUR"
        val pivotRate = allRates[pivot] ?: 1.0

        return displayCurrencies.mapNotNull { code ->
            val rateInEur = allRates[code] ?: return@mapNotNull null
            val converted = amountInEur * rateInEur
            // Кросс-курс относительно активной валюты: rate[code] / rate[pivot].
            // У самой активной строки подписи нет: курс валюты к себе самой
            // равен единице и ничего не сообщает, а что в ней вводят — видно
            // по рамке и клавиатуре.
            val rateText = if (code == pivot) ""
                          else "1 $pivot = ${fmtRate(rateInEur / pivotRate)} $code"
            CurrencyItem(
                code = code,
                name = currencyDisplayName(code),
                flag = currencyFlag(code),
                symbol = currencySymbol(code),
                amount = converted,
                rateText = rateText
            )
        }
    }

    private fun fmtRate(rate: Double): String = when {
        rate >= 10000 -> String.format(Locale.ROOT, "%.0f", rate)
        rate >= 100   -> String.format(Locale.ROOT, "%.2f", rate)
        rate >= 1     -> String.format(Locale.ROOT, "%.4f", rate)
        else          -> String.format(Locale.ROOT, "%.6f", rate)
    }

    private fun formatDate(utc: String): String = try {
        val inFmt = SimpleDateFormat("EEE, dd MMM yyyy HH:mm:ss Z", Locale.ENGLISH)
        val outFmt = SimpleDateFormat("dd MMM yyyy HH:mm", Locale.getDefault())
        outFmt.format(inFmt.parse(utc)!!)
    } catch (_: Exception) { utc }

    /** Обновление раз в 30 минут — только пока приложение на экране.
     *
     *  Раньше цикл жил, пока жив процесс, в том числе в фоне: свёрнутый FIXXE
     *  продолжал ходить за курсами, хотя на экран никто не смотрел, а курсы у
     *  источников меняются раз в сутки. При возврате приложение всё равно
     *  обновляется сразу (onResume), так что в фоне цикл ничего не даёт —
     *  только трафик и заряд. Отсчёт идёт от момента, когда экран показан,
     *  поэтому запросы разных людей сами разнесены во времени. */
    fun resumeAutoRefresh() {
        if (refreshJob?.isActive == true) return
        android.util.Log.d(FETCH_TAG, "auto-refresh on")
        refreshJob = viewModelScope.launch {
            while (true) {
                delay(30 * 60 * 1000L)
                refresh()
            }
        }
    }

    fun pauseAutoRefresh() {
        if (refreshJob?.isActive != true) return
        android.util.Log.d(FETCH_TAG, "auto-refresh off")
        refreshJob?.cancel()
        refreshJob = null
    }

    override fun onCleared() {
        super.onCleared()
        refreshJob?.cancel()
    }

    companion object {
        /** Курсы обновляются раз в сутки, чаще раза в 10 секунд дёргать API незачем. */
        private const val MIN_FETCH_INTERVAL_MS = 10_000L
        /** Тег строки в logcat, по которой smoke-тест считает запросы к источникам. */
        const val FETCH_TAG = "FIXXE_FETCH"
        fun currencyName(code: String) = NAMES[code] ?: code
        /** Название для показа рядом с кодом: пусто, если названия нет
         *  и вышел бы дубль вида «BTC  BTC». */
        fun currencyDisplayName(code: String) = NAMES[code] ?: ""
        fun currencyFlag(code: String) = FLAGS[code] ?: "🌐"
        fun currencySymbol(code: String) = SYMBOLS[code] ?: code

        val SYMBOLS = mapOf(
            "EUR" to "€",  "USD" to "$",  "GBP" to "£",  "JPY" to "¥",
            "CHF" to "Fr", "CAD" to "C$", "AUD" to "A$", "NZD" to "NZ$",
            "CNY" to "¥",  "HKD" to "HK$","SGD" to "S$", "RSD" to "din.",
            "GEL" to "₾",  "ILS" to "₪",  "TJS" to "SM", "RUB" to "₽",
            "UAH" to "₴",  "TRY" to "₺",  "PLN" to "zł", "CZK" to "Kč",
            "HUF" to "Ft", "RON" to "lei","SEK" to "kr", "NOK" to "kr",
            "DKK" to "kr", "ISK" to "kr", "MXN" to "MX$","BRL" to "R$",
            "ARS" to "AR$","KRW" to "₩",  "KPW" to "₩",  "THB" to "฿",
            "IDR" to "Rp",
            "MYR" to "RM", "PHP" to "₱",  "VND" to "₫",  "INR" to "₹",
            "PKR" to "₨",  "EGP" to "E£", "ZAR" to "R",  "NGN" to "₦",
            "SAR" to "SR", "AED" to "AED","QAR" to "QR", "KWD" to "KD",
            "BHD" to "BD", "OMR" to "RO", "JOD" to "JD", "AMD" to "֏",
            "AZN" to "₼",  "KZT" to "₸",  "UZS" to "soʻm","MDL" to "L",
            "BGN" to "лв", "MKD" to "ден","ALL" to "L",  "BYN" to "Br",
            "CLP" to "CL$","COP" to "CO$","PEN" to "S/", "TWD" to "NT$",
            "GHS" to "GH₵","MAD" to "MAD","DZD" to "DA", "TND" to "DT",
            "ETB" to "Br", "TZS" to "TSh","KGS" to "с",  "GEL" to "₾"
        )

        val NAMES = mapOf(
            "EUR" to "Euro", "USD" to "US Dollar", "GBP" to "British Pound",
            "JPY" to "Japanese Yen", "CHF" to "Swiss Franc", "CAD" to "Canadian Dollar",
            "AUD" to "Australian Dollar", "NZD" to "New Zealand Dollar",
            "CNY" to "Chinese Yuan", "HKD" to "Hong Kong Dollar",
            "SGD" to "Singapore Dollar", "RSD" to "Serbian Dinar",
            "GEL" to "Georgian Lari", "ILS" to "Israeli Shekel",
            "TJS" to "Tajikistani Somoni", "RUB" to "Russian Ruble",
            "UAH" to "Ukrainian Hryvnia", "TRY" to "Turkish Lira",
            "PLN" to "Polish Zloty", "CZK" to "Czech Koruna",
            "HUF" to "Hungarian Forint", "RON" to "Romanian Leu",
            "SEK" to "Swedish Krona", "NOK" to "Norwegian Krone",
            "DKK" to "Danish Krone", "ISK" to "Icelandic Krona",
            "MXN" to "Mexican Peso", "BRL" to "Brazilian Real",
            "ARS" to "Argentine Peso", "KRW" to "South Korean Won",
            "KPW" to "North Korean Won",
            "THB" to "Thai Baht", "IDR" to "Indonesian Rupiah",
            "MYR" to "Malaysian Ringgit", "PHP" to "Philippine Peso",
            "VND" to "Vietnamese Dong", "INR" to "Indian Rupee",
            "PKR" to "Pakistani Rupee", "EGP" to "Egyptian Pound",
            "ZAR" to "South African Rand", "NGN" to "Nigerian Naira",
            "SAR" to "Saudi Riyal", "AED" to "UAE Dirham",
            "QAR" to "Qatari Riyal", "KWD" to "Kuwaiti Dinar",
            "BHD" to "Bahraini Dinar", "OMR" to "Omani Rial",
            "JOD" to "Jordanian Dinar", "AMD" to "Armenian Dram",
            "AZN" to "Azerbaijani Manat", "KZT" to "Kazakhstani Tenge",
            "UZS" to "Uzbekistani Som", "MDL" to "Moldovan Leu",
            "BGN" to "Bulgarian Lev", "MKD" to "North Macedonian Denar",
            "ALL" to "Albanian Lek", "BYN" to "Belarusian Ruble",
            "CLP" to "Chilean Peso", "COP" to "Colombian Peso",
            "PEN" to "Peruvian Sol", "TWD" to "Taiwan Dollar",
            "GHS" to "Ghanaian Cedi", "MAD" to "Moroccan Dirham",
            "DZD" to "Algerian Dinar", "TND" to "Tunisian Dinar",
            "ETB" to "Ethiopian Birr", "TZS" to "Tanzanian Shilling",
            "KGS" to "Kyrgyz Som", "AFN" to "Afghan Afghani"
        )

        // всего 271 флагов: 68 вручную + 203 выведено из кода валюты
        val FLAGS = mapOf(
            "ADP" to "🇦🇩", "AED" to "🇦🇪", "AFA" to "🇦🇫", "AFN" to "🇦🇫", "ALK" to "🇦🇱",
            "ALL" to "🇦🇱", "AMD" to "🇦🇲", "AOA" to "🇦🇴", "AOK" to "🇦🇴", "AON" to "🇦🇴",
            "AOR" to "🇦🇴", "ARA" to "🇦🇷", "ARL" to "🇦🇷", "ARM" to "🇦🇷", "ARP" to "🇦🇷",
            "ARS" to "🇦🇷", "ATS" to "🇦🇹", "AUD" to "🇦🇺", "AWG" to "🇦🇼", "AZM" to "🇦🇿",
            "AZN" to "🇦🇿", "BAD" to "🇧🇦", "BAM" to "🇧🇦", "BAN" to "🇧🇦", "BBD" to "🇧🇧",
            "BDT" to "🇧🇩", "BEC" to "🇧🇪", "BEF" to "🇧🇪", "BEL" to "🇧🇪", "BGL" to "🇧🇬",
            "BGM" to "🇧🇬", "BGN" to "🇧🇬", "BGO" to "🇧🇬", "BHD" to "🇧🇭", "BIF" to "🇧🇮",
            "BMD" to "🇧🇲", "BND" to "🇧🇳", "BOB" to "🇧🇴", "BOL" to "🇧🇴", "BOP" to "🇧🇴",
            "BOV" to "🇧🇴", "BRB" to "🇧🇷", "BRC" to "🇧🇷", "BRE" to "🇧🇷", "BRL" to "🇧🇷",
            "BRN" to "🇧🇷", "BRR" to "🇧🇷", "BRZ" to "🇧🇷", "BSD" to "🇧🇸", "BTN" to "🇧🇹",
            "BWP" to "🇧🇼", "BYB" to "🇧🇾", "BYN" to "🇧🇾", "BYR" to "🇧🇾", "BZD" to "🇧🇿",
            "CAD" to "🇨🇦", "CDF" to "🇨🇩", "CHE" to "🇨🇭", "CHF" to "🇨🇭", "CHW" to "🇨🇭",
            "CLE" to "🇨🇱", "CLF" to "🇨🇱", "CLP" to "🇨🇱", "CNH" to "🇨🇳", "CNX" to "🇨🇳",
            "CNY" to "🇨🇳", "COP" to "🇨🇴", "COU" to "🇨🇴", "CRC" to "🇨🇷", "CUC" to "🇨🇺",
            "CUP" to "🇨🇺", "CVE" to "🇨🇻", "CYP" to "🇨🇾", "CZK" to "🇨🇿", "DEM" to "🇩🇪",
            "DJF" to "🇩🇯", "DKK" to "🇩🇰", "DOP" to "🇩🇴", "DZD" to "🇩🇿", "ECS" to "🇪🇨",
            "ECV" to "🇪🇨", "EEK" to "🇪🇪", "EGP" to "🇪🇬", "ERN" to "🇪🇷", "ESA" to "🇪🇸",
            "ESB" to "🇪🇸", "ESP" to "🇪🇸", "ETB" to "🇪🇹", "EUR" to "🇪🇺", "FIM" to "🇫🇮",
            "FJD" to "🇫🇯", "FKP" to "🇫🇰", "FRF" to "🇫🇷", "GBP" to "🇬🇧", "GEK" to "🇬🇪",
            "GEL" to "🇬🇪", "GHC" to "🇬🇭", "GHS" to "🇬🇭", "GIP" to "🇬🇮", "GMD" to "🇬🇲",
            "GNF" to "🇬🇳", "GNS" to "🇬🇳", "GQE" to "🇬🇶", "GRD" to "🇬🇷", "GTQ" to "🇬🇹",
            "GWE" to "🇬🇼", "GWP" to "🇬🇼", "GYD" to "🇬🇾", "HKD" to "🇭🇰", "HNL" to "🇭🇳",
            "HRD" to "🇭🇷", "HRK" to "🇭🇷", "HTG" to "🇭🇹", "HUF" to "🇭🇺", "IDR" to "🇮🇩",
            "IEP" to "🇮🇪", "ILP" to "🇮🇱", "ILR" to "🇮🇱", "ILS" to "🇮🇱", "INR" to "🇮🇳",
            "IQD" to "🇮🇶", "IRR" to "🇮🇷", "ISJ" to "🇮🇸", "ISK" to "🇮🇸", "ITL" to "🇮🇹",
            "JMD" to "🇯🇲", "JOD" to "🇯🇴", "JPY" to "🇯🇵", "KES" to "🇰🇪", "KGS" to "🇰🇬",
            "KHR" to "🇰🇭", "KMF" to "🇰🇲", "KPW" to "🇰🇵", "KRH" to "🇰🇷", "KRO" to "🇰🇷",
            "KRW" to "🇰🇷", "KWD" to "🇰🇼", "KYD" to "🇰🇾", "KZT" to "🇰🇿", "LAK" to "🇱🇦",
            "LBP" to "🇱🇧", "LKR" to "🇱🇰", "LRD" to "🇱🇷", "LSL" to "🇱🇸", "LSM" to "🇱🇸",
            "LTL" to "🇱🇹", "LTT" to "🇱🇹", "LUC" to "🇱🇺", "LUF" to "🇱🇺", "LUL" to "🇱🇺",
            "LVL" to "🇱🇻", "LVR" to "🇱🇻", "LYD" to "🇱🇾", "MAD" to "🇲🇦", "MAF" to "🇲🇦",
            "MCF" to "🇲🇨", "MDC" to "🇲🇩", "MDL" to "🇲🇩", "MGA" to "🇲🇬", "MGF" to "🇲🇬",
            "MKD" to "🇲🇰", "MKN" to "🇲🇰", "MLF" to "🇲🇱", "MMK" to "🇲🇲", "MNT" to "🇲🇳",
            "MOP" to "🇲🇴", "MRO" to "🇲🇷", "MRU" to "🇲🇷", "MTL" to "🇲🇹", "MTP" to "🇲🇹",
            "MUR" to "🇲🇺", "MVP" to "🇲🇻", "MVR" to "🇲🇻", "MWK" to "🇲🇼", "MXN" to "🇲🇽",
            "MXP" to "🇲🇽", "MXV" to "🇲🇽", "MYR" to "🇲🇾", "MZE" to "🇲🇿", "MZM" to "🇲🇿",
            "MZN" to "🇲🇿", "NAD" to "🇳🇦", "NGN" to "🇳🇬", "NIC" to "🇳🇮", "NIO" to "🇳🇮",
            "NLG" to "🇳🇱", "NOK" to "🇳🇴", "NPR" to "🇳🇵", "NZD" to "🇳🇿", "OMR" to "🇴🇲",
            "PAB" to "🇵🇦", "PEI" to "🇵🇪", "PEN" to "🇵🇪", "PES" to "🇵🇪", "PGK" to "🇵🇬",
            "PHP" to "🇵🇭", "PKR" to "🇵🇰", "PLN" to "🇵🇱", "PLZ" to "🇵🇱", "PTE" to "🇵🇹",
            "PYG" to "🇵🇾", "QAR" to "🇶🇦", "ROL" to "🇷🇴", "RON" to "🇷🇴", "RSD" to "🇷🇸",
            "RUB" to "🇷🇺", "RUR" to "🇷🇺", "RWF" to "🇷🇼", "SAR" to "🇸🇦", "SBD" to "🇸🇧",
            "SCR" to "🇸🇨", "SDD" to "🇸🇩", "SDG" to "🇸🇩", "SDP" to "🇸🇩", "SEK" to "🇸🇪",
            "SGD" to "🇸🇬", "SHP" to "🇸🇭", "SIT" to "🇸🇮", "SKK" to "🇸🇰", "SLE" to "🇸🇱",
            "SLL" to "🇸🇱", "SOS" to "🇸🇴", "SRD" to "🇸🇷", "SRG" to "🇸🇷", "SSP" to "🇸🇸",
            "STD" to "🇸🇹", "STN" to "🇸🇹", "SVC" to "🇸🇻", "SYP" to "🇸🇾", "SZL" to "🇸🇿",
            "THB" to "🇹🇭", "TJR" to "🇹🇯", "TJS" to "🇹🇯", "TMM" to "🇹🇲", "TMT" to "🇹🇲",
            "TND" to "🇹🇳", "TOP" to "🇹🇴", "TRL" to "🇹🇷", "TRY" to "🇹🇷", "TTD" to "🇹🇹",
            "TWD" to "🇹🇼", "TZS" to "🇹🇿", "UAH" to "🇺🇦", "UAK" to "🇺🇦", "UGS" to "🇺🇬",
            "UGX" to "🇺🇬", "USD" to "🇺🇸", "USN" to "🇺🇸", "USS" to "🇺🇸", "UYI" to "🇺🇾",
            "UYP" to "🇺🇾", "UYU" to "🇺🇾", "UYW" to "🇺🇾", "UZS" to "🇺🇿", "VEB" to "🇻🇪",
            "VED" to "🇻🇪", "VEF" to "🇻🇪", "VES" to "🇻🇪", "VND" to "🇻🇳", "VNN" to "🇻🇳",
            "VUV" to "🇻🇺", "WST" to "🇼🇸", "YER" to "🇾🇪", "ZAL" to "🇿🇦", "ZAR" to "🇿🇦",
            "ZMK" to "🇿🇲", "ZMW" to "🇿🇲", "ZWD" to "🇿🇼", "ZWG" to "🇿🇼", "ZWL" to "🇿🇼",
            "ZWR" to "🇿🇼"
        )
    }
}
