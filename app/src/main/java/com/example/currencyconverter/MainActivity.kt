package com.example.currencyconverter

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.text.Editable
import android.text.TextWatcher
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.BaseAdapter
import android.widget.EditText
import android.widget.ListView
import android.widget.TextView
import androidx.activity.viewModels
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.appcompat.app.AppCompatDelegate
import androidx.core.os.LocaleListCompat
import androidx.core.view.ViewCompat
import android.graphics.Rect
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.updatePadding
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.ItemTouchHelper
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.example.currencyconverter.data.CurrencyRepository
import com.example.currencyconverter.databinding.ActivityMainBinding
import com.example.currencyconverter.ui.AmountFormat
import com.example.currencyconverter.ui.CurrencyAdapter
import com.example.currencyconverter.ui.CurrencyInfo
import com.example.currencyconverter.ui.CurrencyViewModel
import com.example.currencyconverter.ui.RateAdjust
import com.example.currencyconverter.ui.CurrencyViewModel.Companion.currencyFlag
import kotlinx.coroutines.launch
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class MainActivity : AppCompatActivity() {

    private lateinit var binding: ActivityMainBinding
    private val vm: CurrencyViewModel by viewModels()
    private lateinit var adapter: CurrencyAdapter

    override fun onCreate(savedInstanceState: Bundle?) {
        AppCompatDelegate.setDefaultNightMode(AppCompatDelegate.MODE_NIGHT_NO)
        applyTheme()          // до super.onCreate(): иначе окно моргнёт прежней темой
        super.onCreate(savedInstanceState)
        applyDefaultLanguage()
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        // targetSdk 36 → принудительный edge-to-edge: разводим контент из-под
        // системных панелей (шапка под статус-бар, подвал над навигацией).
        ViewCompat.setOnApplyWindowInsetsListener(binding.root) { _, insets ->
            val bars = insets.getInsets(
                WindowInsetsCompat.Type.systemBars() or WindowInsetsCompat.Type.displayCutout()
            )
            // При edge-to-edge (targetSdk 35+) окно под клавиатуру больше не
            // ужимается само — adjustResize в манифесте на это уже не влияет.
            // Поэтому поднимаем низ окна сами, иначе клавиатура накрывает ту
            // самую строку, в которую сейчас вводят сумму, и ввод идёт вслепую.
            val ime = insets.getInsets(WindowInsetsCompat.Type.ime()).bottom
            // Клавиатура прокручивает список, чтобы строка ввода осталась видна.
            // Когда её убирают, список снова растёт, а прокрутка остаётся — весь
            // список висел сдвинутым вверх. Возвращаем его так, как он стоял до
            // клавиатуры, чем бы её ни закрыли. Само положение запоминается
            // ещё при касании (см. ниже): поле подтягивает свою строку целиком
            // в видимую область раньше, чем клавиатура начнёт выезжать.
            val imeNowOpen = ime > 0
            if (imeNowOpen && !imeOpen && listBeforeIme == null) listBeforeIme = listPosition()
            if (!imeNowOpen && imeOpen) {
                listBeforeIme?.let { restoreListPosition(it) }
                listBeforeIme = null
            }
            imeOpen = imeNowOpen
            binding.headerBar.updatePadding(top = bars.top)
            // Отступ под системную навигацию нужен, только когда её видно:
            // клавиатура её закрывает, и второй отступ дал бы пустую полосу.
            binding.footerBar.updatePadding(bottom = if (ime > 0) 0 else bars.bottom)
            binding.root.updatePadding(left = bars.left, right = bars.right, bottom = ime)
            // ЭКСПЕРИМЕНТ: значок «спрятать клавиатуру» в шапке — пока она открыта
            binding.btnHideKeyboard.visibility = if (ime > 0) android.view.View.VISIBLE else android.view.View.GONE
            // Список стал ниже — подтягиваем к нему строку с фокусом, иначе она
            // так и останется за пределами ужавшейся области.
            if (ime > 0) binding.root.post {
                currentFocus?.let { f ->
                    f.requestRectangleOnScreen(Rect(0, 0, f.width, f.height), false)
                }
            }
            insets
        }

        adapter = CurrencyAdapter(
            onAmountChanged = { code, amount -> vm.setActiveAmount(code, amount) },
            onFocused       = { code -> vm.focusRow(code) },
            onDeleteClick   = { code -> confirmDelete(code) },
            onDone          = { dismissKeyboard() }
        )
        // Фокус, снятый с поля, должен уйти в сам экран. Иначе Android отдаёт
        // его первому полю сверху — строка EUR сама становилась бы активной.
        binding.root.isFocusable = true
        binding.root.isFocusableInTouchMode = true
        // Тап по пустому месту под списком закрывает клавиатуру — как на iPhone
        binding.recyclerView.setOnTouchListener { rv, e ->
            if (e.actionMasked == android.view.MotionEvent.ACTION_UP &&
                (rv as RecyclerView).findChildViewUnder(e.x, e.y) == null) dismissKeyboard()
            false   // прокрутку и перетаскивание не трогаем
        }
        binding.btnHideKeyboard.setOnClickListener { dismissKeyboard() }
        // Касание при закрытой клавиатуре — положение списка «до клавиатуры».
        // Слушатель элементов видит касание раньше полей, в отличие от
        // setOnTouchListener, до которого тап по полю не доходит.
        binding.recyclerView.addOnItemTouchListener(object : RecyclerView.SimpleOnItemTouchListener() {
            override fun onInterceptTouchEvent(rv: RecyclerView, e: android.view.MotionEvent): Boolean {
                if (e.actionMasked == android.view.MotionEvent.ACTION_DOWN && !imeOpen)
                    listBeforeIme = listPosition()
                return false
            }
        })

        val dragCallback = object : ItemTouchHelper.SimpleCallback(
            ItemTouchHelper.UP or ItemTouchHelper.DOWN, 0
        ) {
            override fun isLongPressDragEnabled() = false

            override fun onMove(
                rv: RecyclerView,
                viewHolder: RecyclerView.ViewHolder,
                target: RecyclerView.ViewHolder
            ): Boolean {
                adapter.onItemMove(viewHolder.bindingAdapterPosition, target.bindingAdapterPosition)
                return true
            }

            override fun onSwiped(viewHolder: RecyclerView.ViewHolder, direction: Int) {}

            override fun clearView(rv: RecyclerView, viewHolder: RecyclerView.ViewHolder) {
                super.clearView(rv, viewHolder)
                (viewHolder as? CurrencyAdapter.ViewHolder)?.onDragEnd()
            }
        }

        val touchHelper = ItemTouchHelper(dragCallback)
        touchHelper.attachToRecyclerView(binding.recyclerView)

        adapter.startDragListener = { vh -> touchHelper.startDrag(vh) }
        adapter.onOrderChanged = { order -> vm.reorderCurrencies(order) }

        binding.recyclerView.layoutManager = LinearLayoutManager(this)
        binding.recyclerView.adapter = adapter
        limitListWidth()
        binding.recyclerView.itemAnimator = null

        lifecycleScope.launch {
            vm.state.collect { s ->
                // идёт запрос — крутим сам значок, отдельного индикатора нет
                setRefreshSpinning(s.isLoading)
                // ExchangeRate-API вверху не называем никогда: у него своя дословная
                // подпись внизу, она нужна по условиям их бесплатного тарифа.
                // Остальные источники — коротким именем рядом со временем.
                val erApi = s.source == "ExchangeRate-API"
                val src = if (erApi) "" else shortSource(s.source)
                binding.btnAttribution.visibility = if (erApi) View.VISIBLE else View.GONE
                // Перенос не должен начинать строку с разделителя «·»
                fun tidy(t: String) = t.replace(" · ", "\u00A0· ")
                // у строк «офлайн» и «устарели» источник — последним, после « · »
                fun noSrc(t: String) = if (src.isEmpty()) t.trimEnd().removeSuffix("·").trimEnd() else t
                val ready = s.error == null && s.lastUpdated.isNotEmpty()
                val status = when {
                    s.error != null         -> getString(R.string.error_prefix, s.error)
                    s.lastUpdated.isEmpty() -> getString(R.string.loading)
                    // кэшу больше суток — предупреждаем заметно
                    s.stale                 -> noSrc(getString(R.string.rates_stale, s.lastUpdated, src))
                    s.fromCache             -> noSrc(getString(R.string.rates_offline, s.lastUpdated, src))
                    // с поправкой курсы уже не рыночные — строка говорит правду
                    else -> listOf(getString(if (s.adjusted) R.string.adjusted_rates else R.string.market_rate),
                                   s.lastUpdated, src).filter { it.isNotEmpty() }.joinToString(" · ")
                }
                // цвета из ресурсов, у каждой темы свой
                val statusColor = getColor(when {
                    s.stale     -> R.color.status_stale      // устаревшие курсы
                    s.fromCache -> R.color.status_offline    // офлайн, но свежие
                    s.adjusted && ready -> R.color.adjusted
                    else        -> R.color.text_secondary
                })
                binding.tvStatus.setTextColor(statusColor)
                binding.tvStatus.text = if (ready) withInfoIcon(tidy(status), statusColor) else tidy(status)
                // Поправка к курсу: полоса под шапкой говорит, что курсы пересчитаны;
                // сразу после сброса по сроку — сообщение с «Вернуть»
                binding.adjustBanner.visibility = if (s.adjusted) View.VISIBLE else View.GONE
                binding.adjustNotice.visibility =
                    if (!s.adjusted && s.adjustResetFrom != null) View.VISIBLE else View.GONE
                binding.btnAdjustUndo.setOnClickListener { s.adjustResetFrom?.let { vm.setAdjust(it) } }
                adapter.roundUp = s.roundUp
                adapter.decimalPlaces = s.decimalPlaces
                adapter.grouping = s.grouping
                adapter.submitList(s.currencyItems, s.activeCurrency)
            }
        }

        binding.tvStatus.setOnClickListener { showSourceInfoDialog() }
        binding.adjustBanner.setOnClickListener { showAdjustDialog() }
        binding.btnAttribution.setOnClickListener { openUrl("https://www.exchangerate-api.com") }

        binding.btnRefresh.setOnClickListener { vm.refresh() }
        binding.btnClear.setOnClickListener {
            // Снимаем фокус, иначе поле с курсором пропускается при ребинде и не обнуляется
            currentFocus?.clearFocus()
            AlertDialog.Builder(this)
                .setTitle(getString(R.string.clear_confirm_title))
                .setMessage(getString(R.string.clear_confirm_msg))
                .setPositiveButton(getString(R.string.clear)) { _, _ -> vm.clearAll() }
                .setNegativeButton(getString(R.string.cancel), null)
                .show()
        }
        // списки источников тянем заранее: иначе в диалоге добавления сначала
        // видно только валюты активного источника (159 вместо 335)
        if (!vm.sourceCodesLoaded()) vm.loadSourceCodes { }

        // В сборке для Play это пустышка: оттуда обновляет только магазин.
        // В сборке для раздачи вне Play — подскажет, что вышла новая версия.
        UpdateNotice.check(this)
        binding.btnAddCurrency.setOnClickListener { showAddDialog() }
        binding.btnSettings.setOnClickListener { showSettingsDialog() }

    }

    override fun onStart() {
        super.onStart()
        vm.resetAdjustIfExpired()   // давно не открывали — курсы снова рыночные
        vm.resetAmountIfExpired(beforeReset = ::dismissKeyboard)   // и сумма снова 1, если так выбрано
        vm.resumeAutoRefresh()
    }

    override fun onResume() {
        super.onResume()
        vm.refresh()
    }

    // приложение ушло с экрана — свёрнуто, заблокирован телефон, открыто другое
    override fun onStop() {
        super.onStop()
        vm.markUsed()               // отсюда считаются 4 часа до сброса поправки
        vm.pauseAutoRefresh()
    }

    /** На планшетах строка во всю ширину экрана выглядит пустой: код слева,
     *  сумма у правого края. Держим список в читаемой ширине по центру. */
    private fun limitListWidth() {
        val dm = resources.displayMetrics
        val widthDp = dm.widthPixels / dm.density
        val maxContentDp = 640f
        if (widthDp <= maxContentDp) return
        val padPx = ((widthDp - maxContentDp) / 2f * dm.density).toInt()
        binding.recyclerView.setPadding(
            padPx, binding.recyclerView.paddingTop, padPx, binding.recyclerView.paddingBottom
        )
    }

    private fun confirmDelete(code: String) {
        val name = CurrencyViewModel.currencyName(code)
        AlertDialog.Builder(this)
            .setTitle(getString(R.string.delete_currency_title))
            .setMessage(getString(R.string.delete_currency_msg, code, name))
            .setPositiveButton(getString(R.string.delete)) { _, _ -> vm.removeCurrency(code) }
            .setNegativeButton(getString(R.string.cancel), null)
            .show()
    }

    private fun openUrl(url: String) {
        try {
            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
        } catch (_: Exception) { /* нет браузера — игнорируем */ }
    }

    private fun showSourceInfoDialog() {
        val b = AlertDialog.Builder(this)
            .setTitle(getString(R.string.source_info_title))
            .setNeutralButton("exchangerate-api.com") { _, _ ->
                openUrl("https://www.exchangerate-api.com")
            }
            .setPositiveButton(getString(R.string.ok), null)
        val pct = vm.getAdjustPct()
        if (pct == 0.0) {
            b.setMessage(getString(R.string.source_info_message))
        } else {
            // С поправкой справка начинается с предупреждения — здесь процент
            // уместен — и кнопки, которая ведёт к его настройке.
            val warn = getString(R.string.adjust_info, pctLabel(pct))
            val text = android.text.SpannableString(warn + "\n\n" + getString(R.string.source_info_message))
            text.setSpan(android.text.style.ForegroundColorSpan(getColor(R.color.adjusted)), 0, warn.length, 0)
            text.setSpan(android.text.style.StyleSpan(android.graphics.Typeface.BOLD), 0, warn.length, 0)
            b.setMessage(text)
            b.setNegativeButton(getString(R.string.adjust_title)) { _, _ -> showAdjustDialog() }
        }
        b.show()
    }

    /** «+1.5%» для показа в тексте. В арабском, иврите и персидском знак без
     *  этой обёртки уезжает за число: «+» и «%» там не имеют своего направления. */
    private fun pctLabel(pct: Double): String =
        androidx.core.text.BidiFormatter
            .getInstance(resources.configuration.layoutDirection == View.LAYOUT_DIRECTION_RTL)
            .unicodeWrap(RateAdjust.label(pct), androidx.core.text.TextDirectionHeuristicsCompat.LTR)

    /** Поправка к курсу. В отличие от остальных настроек окно не закрывается
     *  по выбору строки: иначе до галочки «Действует постоянно» было бы
     *  не добраться. */
    private fun showAdjustDialog(fromSettings: Boolean = false) {
        dismissKeyboard()   // курсор уйдёт на базовую строку — поле ввода отпускаем
        val view = layoutInflater.inflate(R.layout.dialog_adjust, null)
        val plus = view.findViewById<TextView>(R.id.btnSignPlus)
        val minus = view.findViewById<TextView>(R.id.btnSignMinus)
        val group = view.findViewById<android.widget.RadioGroup>(R.id.adjustGroup)
        val custom = view.findViewById<EditText>(R.id.etAdjustCustom)
        val keep = view.findViewById<android.widget.CheckBox>(R.id.cbAdjustKeep)
        val density = resources.displayMetrics.density

        var negative = vm.getAdjustPct() < 0
        var drawing = false     // строки отмечает код, а не человек

        // «Выкл.» и готовые значения
        val radios = (listOf(0.0) + RateAdjust.PRESETS.toList()).map { p ->
            val rb = android.widget.RadioButton(this)
            rb.id = View.generateViewId()
            rb.textSize = 16f
            rb.minHeight = (48 * density).toInt()
            rb.layoutParams = android.widget.RadioGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)
            group.addView(rb)
            p to rb
        }

        fun styleSign(tv: TextView, on: Boolean) {
            val bg = android.graphics.drawable.GradientDrawable()
            bg.cornerRadius = 8 * density
            if (on) {
                bg.setColor(getColor(R.color.adjusted))
                tv.setTextColor(getColor(R.color.on_adjusted))
            } else {
                bg.setColor(getColor(R.color.surface))
                bg.setStroke((1 * density).toInt(), getColor(R.color.icon_faint))
                tv.setTextColor(getColor(R.color.text_primary))
            }
            tv.background = bg
            tv.isSelected = on
        }

        // syncCustom = false — когда значение только что набрали в самом поле:
        // переписывать его под пальцами незачем
        fun draw(syncCustom: Boolean = true) {
            drawing = true
            val a = kotlin.math.abs(vm.getAdjustPct())
            styleSign(plus, !negative); styleSign(minus, negative)
            for ((p, rb) in radios)
                rb.text = if (p == 0.0) getString(R.string.adjust_off) else pctLabel(if (negative) -p else p)
            val hit = radios.firstOrNull { it.first == a }
            if (hit != null) group.check(hit.second.id) else group.clearCheck()
            // своё значение показываем в поле, готовое — нет
            val own = if (hit == null) RateAdjust.label(a).drop(1).dropLast(1) else ""
            if (syncCustom && custom.text.toString() != own) custom.setText(own)
            drawing = false
        }

        fun applyCustom() {
            val v = com.example.currencyconverter.ui.AmountParser.parse(custom.text.toString(), 0)
            if (v > 0) { vm.setAdjust(if (negative) -v else v); draw(syncCustom = false) }
        }

        plus.setOnClickListener {
            negative = false
            if (vm.getAdjustPct() != 0.0) vm.setAdjust(kotlin.math.abs(vm.getAdjustPct()))
            draw()
        }
        minus.setOnClickListener {
            negative = true
            if (vm.getAdjustPct() != 0.0) vm.setAdjust(-kotlin.math.abs(vm.getAdjustPct()))
            draw()
        }
        group.setOnCheckedChangeListener { _, id ->
            if (drawing || id == -1) return@setOnCheckedChangeListener
            val p = radios.firstOrNull { it.second.id == id }?.first ?: return@setOnCheckedChangeListener
            custom.clearFocus()
            vm.setAdjust(if (negative) -p else p)
            draw()
        }
        custom.setOnEditorActionListener { v, actionId, _ ->
            if (actionId == android.view.inputmethod.EditorInfo.IME_ACTION_DONE) {
                applyCustom()
                (getSystemService(INPUT_METHOD_SERVICE) as android.view.inputmethod.InputMethodManager)
                    .hideSoftInputFromWindow(v.windowToken, 0)
                true
            } else false
        }
        keep.isChecked = vm.getAdjustKeep()
        keep.setOnCheckedChangeListener { _, on -> vm.setAdjustKeep(on) }
        draw()

        AlertDialog.Builder(this)
            .setTitle(getString(R.string.adjust_title))
            .setView(view)
            // набранное своё значение не теряется, если клавиатуру не закрывали
            .setPositiveButton(getString(R.string.close)) { _, _ -> if (custom.hasFocus()) applyCustom() }
            .show().backToSettings(fromSettings)
    }

    // Названия источников: индекс 0 = Авто (локализуется), дальше — бренды (не переводятся)

    private fun sourceOptions(): Array<String> =
        arrayOf(getString(R.string.source_auto)) + CurrencyRepository.SOURCES.map { it.title }

    /** Значок «i» в конце строки статуса: она нажимается и открывает пояснение. */
    private fun withInfoIcon(text: String, color: Int): CharSequence {
        val d = androidx.appcompat.content.res.AppCompatResources.getDrawable(this, R.drawable.ic_info)
            ?.mutate() ?: return text
        val size = (binding.tvStatus.textSize * 1.1f).toInt()
        d.setBounds(0, 0, size, size)
        d.setTint(color)
        val sb = android.text.SpannableStringBuilder(text).append("\u00A0 ")
        sb.setSpan(android.text.style.ImageSpan(d, android.text.style.ImageSpan.ALIGN_BOTTOM),
            sb.length - 1, sb.length, android.text.Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        return sb
    }

    /** Настройки — одно окно на всех платформах: название слева, значение справа.
     *  Поправка к курсу — отдельно, под линией, последней и фиолетовым цветом:
     *  тем же, каким помечены суммы с поправкой. Внизу мелко — номер версии. */
    private fun showSettingsDialog() {
        val decimals = vm.getDecimalPlaces()
        val decimalLabel = if (decimals == 0) getString(R.string.precision_value_int)
                           else getString(R.string.precision_value_n, decimals)
        val srcName = sourceOptions()[vm.getSourceMode().coerceIn(0, CurrencyRepository.SOURCES.size)]
        val groupingLabel = groupingOptions()[vm.getGrouping().coerceIn(0, 2)]
        val themeLabel = themeOptions()[getSharedPreferences("axe_prefs", MODE_PRIVATE)
            .getInt("theme", 0).coerceIn(0, 2)]
        val adjustLabel = vm.getAdjustPct().let {
            if (it == 0.0) getString(R.string.adjust_off) else pctLabel(it)
        }
        val roundLabel = getString(if (vm.getRoundUp()) R.string.rounding_up else R.string.rounding_nearest)

        val density = resources.displayMetrics.density
        val box = android.widget.LinearLayout(this).apply {
            orientation = android.widget.LinearLayout.VERTICAL
            setPadding(0, (4 * density).toInt(), 0, 0)
        }
        var dialog: AlertDialog? = null
        fun row(label: String, value: String, tag: String, adjusted: Boolean = false, open: () -> Unit) {
            val v = layoutInflater.inflate(R.layout.item_setting_row, box, false)
            val tvLabel = v.findViewById<TextView>(R.id.tvLabel)
            val tvValue = v.findViewById<TextView>(R.id.tvValue)
            tvLabel.text = label
            tvValue.text = value
            if (adjusted) {
                tvLabel.setTextColor(getColor(R.color.adjusted))
                tvValue.setTextColor(getColor(R.color.adjusted))
                v.findViewById<android.widget.ImageView>(R.id.ivChevron)
                    .setColorFilter(getColor(R.color.adjusted))
            }
            v.tag = tag        // по нему находят строку тесты
            v.setOnClickListener { dialog?.dismiss(); open() }
            box.addView(v)
        }
        row(getString(R.string.theme_title), themeLabel, "set-theme") { showThemeDialog(true) }
        row(getString(R.string.precision_title), decimalLabel, "set-precision") { showDecimalDialog(true) }
        row(getString(R.string.rounding_title), roundLabel, "set-rounding") { showRoundingDialog(true) }
        row(getString(R.string.grouping_title), groupingLabel, "set-grouping") { showGroupingDialog(true) }
        row(getString(R.string.amount_memory_title), getString(memoryLabels[vm.getAmountMemory()]), "set-memory") {
            showAmountMemoryDialog(true)
        }
        row(getString(R.string.source_title), srcName, "set-source") { showSourceDialog(true) }
        row(getString(R.string.language_title), currentLanguageLabel(), "set-language") { showLanguageDialog(true) }
        box.addView(View(this).apply {
            layoutParams = android.widget.LinearLayout.LayoutParams(
                android.widget.LinearLayout.LayoutParams.MATCH_PARENT, (1 * density).toInt()
            ).apply { setMargins((24 * density).toInt(), (6 * density).toInt(), (16 * density).toInt(), (6 * density).toInt()) }
            setBackgroundColor(getColor(R.color.divider))
        })
        row(getString(R.string.adjust_title), adjustLabel, "set-adjust", adjusted = true) { showAdjustDialog(true) }
        // номер версии — мелко; нажатие копирует его для сообщения об ошибке
        val version = getString(R.string.version_label, BuildConfig.VERSION_NAME)
        box.addView(TextView(this).apply {
            text = version
            textSize = 11f
            setTextColor(getColor(R.color.hint))
            gravity = android.view.Gravity.CENTER
            minHeight = (44 * density).toInt()
            setPadding(0, (8 * density).toInt(), 0, 0)
            tag = "set-version"
            setOnClickListener {
                (getSystemService(CLIPBOARD_SERVICE) as android.content.ClipboardManager)
                    .setPrimaryClip(android.content.ClipData.newPlainText("FIXXE", "FIXXE " + BuildConfig.VERSION_NAME))
                android.widget.Toast.makeText(this@MainActivity, R.string.copied, android.widget.Toast.LENGTH_SHORT).show()
            }
        })

        dialog = AlertDialog.Builder(this)
            .setTitle(getString(R.string.settings))
            .setView(android.widget.ScrollView(this).apply { addView(box) })
            .setNegativeButton(getString(R.string.close), null)
            .show()
    }

    /** Экран сейчас пересоздаётся (сменили тему или язык) — окно настроек
     *  поверх уходящего экрана не открываем. */
    private var leavingScreen = false

    /** Окно выбора, открытое из настроек: «Назад», выбор значения, системная
     *  «Назад» и тап мимо окна возвращают в настройки, а не на главный экран.
     *  Раньше окно настроек закрывалось при переходе, и возвращаться было некуда. */
    private fun AlertDialog.backToSettings(fromSettings: Boolean): AlertDialog {
        if (fromSettings) setOnDismissListener {
            if (!isFinishing && !isDestroyed && !leavingScreen) showSettingsDialog()
        }
        return this
    }

    /** Подписи вариантов «Помнить сумму» — по номерам из AmountMemory. */
    private val memoryLabels = intArrayOf(
        R.string.amount_memory_session, R.string.amount_memory_12h,
        R.string.amount_memory_24h, R.string.amount_memory_forever
    )

    /** Сколько помнить введённую сумму после ухода из приложения. */
    private fun showAmountMemoryDialog(fromSettings: Boolean = false) {
        val density = resources.displayMetrics.density
        val hint = TextView(this).apply {
            text = getString(R.string.amount_memory_hint)
            textSize = 13f
            setTextColor(getColor(R.color.text_secondary))
            setPadding((24 * density).toInt(), (4 * density).toInt(), (24 * density).toInt(), 0)
        }
        AlertDialog.Builder(this)
            .setTitle(getString(R.string.amount_memory_title))
            .setSingleChoiceItems(memoryLabels.map { getString(it) }.toTypedArray(), vm.getAmountMemory()) { dialog, which ->
                vm.setAmountMemory(which)
                dialog.dismiss()
            }
            .setView(hint)
            .setNegativeButton(getString(R.string.back), null)
            .show().backToSettings(fromSettings)
    }

    /** Округление сумм: вверх (как было всегда) или к ближайшему. Под каждым
     *  вариантом — пример на текущем курсе двух первых валют списка. */
    private fun showRoundingDialog(fromSettings: Boolean = false) {
        val codes = vm.shownCodes()
        val from = codes.getOrNull(0) ?: "EUR"
        val to = codes.getOrNull(1) ?: "USD"
        // Пример — первая сумма от 100, на которой способы дают разное: при
        // «круглом» курсе на 100 оба показали бы одно и то же число.
        fun fmt(v: Double, up: Boolean) = AmountFormat.format(v, vm.getDecimalPlaces(), vm.getGrouping(), up)
        val base = (100..199).firstOrNull { a ->
            vm.convertPlain(a.toDouble(), from, to)?.let { fmt(it, true) != fmt(it, false) } == true
        } ?: 100
        val exact = vm.convertPlain(base.toDouble(), from, to)
        val ltr = androidx.core.text.BidiFormatter.getInstance(
            resources.configuration.layoutDirection == View.LAYOUT_DIRECTION_RTL)
        val items = listOf(true to R.string.rounding_up, false to R.string.rounding_nearest).map { (up, res) ->
            val sb = android.text.SpannableStringBuilder(getString(res))
            if (exact != null) {
                val ex = "$base $from → " + fmt(exact, up) + " $to"
                val start = sb.length + 1
                sb.append("\n").append(ltr.unicodeWrap(ex, androidx.core.text.TextDirectionHeuristicsCompat.LTR))
                sb.setSpan(android.text.style.RelativeSizeSpan(0.85f), start, sb.length, 0)
                sb.setSpan(android.text.style.ForegroundColorSpan(getColor(R.color.text_secondary)), start, sb.length, 0)
            }
            sb as CharSequence
        }.toTypedArray()
        val density = resources.displayMetrics.density
        val hint = TextView(this).apply {
            text = getString(R.string.rounding_hint)
            textSize = 13f
            setTextColor(getColor(R.color.text_secondary))
            setPadding((24 * density).toInt(), (4 * density).toInt(), (24 * density).toInt(), 0)
        }
        AlertDialog.Builder(this)
            .setTitle(getString(R.string.rounding_title))
            .setSingleChoiceItems(items, if (vm.getRoundUp()) 0 else 1) { dialog, which ->
                vm.setRoundUp(which == 0)
                dialog.dismiss()
            }
            .setView(hint)
            .setNegativeButton(getString(R.string.back), null)
            .show().backToSettings(fromSettings)
    }

    private fun showDecimalDialog(fromSettings: Boolean = false) {
        val options = arrayOf(
            getString(R.string.prec_0), getString(R.string.prec_1),
            getString(R.string.prec_2), getString(R.string.prec_4)
        )
        val values  = intArrayOf(0, 1, 2, 4)
        val checked = values.indexOfFirst { it == vm.getDecimalPlaces() }.coerceAtLeast(0)

        AlertDialog.Builder(this)
            .setTitle(getString(R.string.precision_title))
            .setSingleChoiceItems(options, checked) { dialog, which ->
                vm.setDecimalPlaces(values[which])
                dialog.dismiss()
            }
            .setNegativeButton(getString(R.string.back), null)
            .show().backToSettings(fromSettings)
    }

    private fun groupingOptions() = arrayOf(
        getString(R.string.group_none), getString(R.string.group_space), getString(R.string.group_comma)
    )

    private fun showGroupingDialog(fromSettings: Boolean = false) {
        AlertDialog.Builder(this)
            .setTitle(getString(R.string.grouping_title))
            .setSingleChoiceItems(groupingOptions(), vm.getGrouping().coerceIn(0, 2)) { dialog, which ->
                vm.setGrouping(which)
                dialog.dismiss()
            }
            .setNegativeButton(getString(R.string.back), null)
            .show().backToSettings(fromSettings)
    }

    private fun showSourceDialog(fromSettings: Boolean = false) {
        val checked = vm.getSourceMode().coerceIn(0, CurrencyRepository.SOURCES.size)

        AlertDialog.Builder(this)
            .setTitle(getString(R.string.source_title))
            .setSingleChoiceItems(sourceOptions(), checked) { dialog, which ->
                vm.setSourceMode(which)
                dialog.dismiss()
            }
            .setNegativeButton(getString(R.string.back), null)
            .show().backToSettings(fromSettings)
    }

    /** По умолчанию приложение на английском, а не на языке устройства
     *  (Android иначе сам подхватил бы values-<язык системы>). Язык системы
     *  включается только явным выбором «Системный» в настройках. */
    /** 0 — как в системе, 1 — всегда светлая, 2 — всегда тёмная */
    /** Закрыть клавиатуру, не сделав активной другую строку. */
    private var imeOpen = false
    private var listBeforeIme: Pair<Int, Int>? = null

    /** Первая видимая строка и её сдвиг от верха списка. */
    private fun listPosition(): Pair<Int, Int>? {
        val lm = binding.recyclerView.layoutManager as? LinearLayoutManager ?: return null
        val pos = lm.findFirstVisibleItemPosition()
        if (pos == RecyclerView.NO_POSITION) return null
        val v = lm.findViewByPosition(pos) ?: return null
        val helper = androidx.recyclerview.widget.OrientationHelper.createVerticalHelper(lm)
        return pos to (helper.getDecoratedStart(v) - helper.startAfterPadding)
    }

    private fun restoreListPosition(saved: Pair<Int, Int>) {
        val rv = binding.recyclerView
        // после того как список заново разложится на выросшей высоте
        rv.post {
            val lm = rv.layoutManager as? LinearLayoutManager ?: return@post
            val count = rv.adapter?.itemCount ?: 0
            if (count == 0) return@post
            lm.scrollToPositionWithOffset(saved.first.coerceAtMost(count - 1), saved.second)
        }
    }

    private fun dismissKeyboard() {
        val focused = currentFocus ?: return
        (getSystemService(INPUT_METHOD_SERVICE) as android.view.inputmethod.InputMethodManager)
            .hideSoftInputFromWindow(focused.windowToken, 0)
        binding.root.requestFocus()
    }

    /** Короткое имя источника для строки статуса.
     *  В шапке мало места: полное «ExchangeRate-API» вытесняет дату, и строка
     *  обрывается многоточием — не видно ни источника, ни времени. В настройках,
     *  где источник выбирают, имена остаются полными. Дефис неразрывный, чтобы
     *  короткое имя не переносилось по нему на две строки. */
    private fun shortSource(name: String) = when (name) {
        "FXRatesAPI"        -> "FXR\u2011API"
        "ExchangeRate-API"  -> "ER\u2011API"
        "Frankfurter (ECB)" -> "Fra.ECB"
        else                -> name           // «F.A.», «Coinbase», «Wise» уже короткие
    }

    /** Вращение значка «обновить» на время запроса — вместо отдельной крутилки. */
    private fun setRefreshSpinning(on: Boolean) {
        // Включено «Убрать анимацию» (Специальные возможности) — не крутим,
        // а приглушаем значок: загрузку всё равно видно, но без движения.
        val noMotion = android.provider.Settings.Global.getFloat(
            contentResolver, android.provider.Settings.Global.ANIMATOR_DURATION_SCALE, 1f) == 0f
        if (noMotion) {
            binding.btnRefresh.clearAnimation()
            binding.btnRefresh.alpha = if (on) 0.4f else 1f
            return
        }
        if (on) {
            if (binding.btnRefresh.animation == null) {
                val spin = android.view.animation.RotateAnimation(
                    0f, 360f,
                    android.view.animation.Animation.RELATIVE_TO_SELF, 0.5f,
                    android.view.animation.Animation.RELATIVE_TO_SELF, 0.5f
                ).apply {
                    duration = 900
                    repeatCount = android.view.animation.Animation.INFINITE
                    interpolator = android.view.animation.LinearInterpolator()
                }
                binding.btnRefresh.startAnimation(spin)
            }
        } else {
            binding.btnRefresh.clearAnimation()
        }
    }

    private fun applyTheme() {
        AppCompatDelegate.setDefaultNightMode(
            when (getSharedPreferences("axe_prefs", MODE_PRIVATE).getInt("theme", 0)) {
                1 -> AppCompatDelegate.MODE_NIGHT_NO
                2 -> AppCompatDelegate.MODE_NIGHT_YES
                else -> AppCompatDelegate.MODE_NIGHT_FOLLOW_SYSTEM
            }
        )
    }

    private fun themeOptions() = arrayOf(
        getString(R.string.theme_system), getString(R.string.theme_light), getString(R.string.theme_dark)
    )

    private fun showThemeDialog(fromSettings: Boolean = false) {
        val prefs = getSharedPreferences("axe_prefs", MODE_PRIVATE)
        AlertDialog.Builder(this)
            .setTitle(getString(R.string.theme_title))
            .setSingleChoiceItems(themeOptions(), prefs.getInt("theme", 0).coerceIn(0, 2)) { dialog, which ->
                if (which != prefs.getInt("theme", 0)) leavingScreen = true   // экран пересоздастся
                prefs.edit().putInt("theme", which).apply()
                dialog.dismiss()
                applyTheme()      // setDefaultNightMode сам пересоздаст экран
            }
            .setNegativeButton(getString(R.string.back), null)
            .show().backToSettings(fromSettings)
    }

    private fun applyDefaultLanguage() {
        val prefs = getSharedPreferences("axe_prefs", Context.MODE_PRIVATE)
        if (prefs.getBoolean(KEY_LANG_INITIALIZED, false)) return
        if (AppCompatDelegate.getApplicationLocales().isEmpty) {
            // вызывать строго ПОСЛЕ super.onCreate(): раньше AppCompat ещё не
            // готов и локаль молча не применяется
            AppCompatDelegate.setApplicationLocales(LocaleListCompat.forLanguageTags("en"))
        }
        // флаг ставим только после фактической установки, иначе при сбое
        // приложение навсегда осталось бы на языке устройства
        prefs.edit().putBoolean(KEY_LANG_INITIALIZED, true).apply()
    }

    private fun currentLanguageLabel(): String {
        val locales = AppCompatDelegate.getApplicationLocales()
        if (locales.isEmpty) return getString(R.string.language_system)
        val tag = locales[0]?.language ?: return getString(R.string.language_system)
        return LANGUAGES.firstOrNull { it.first == tag }?.second ?: tag
    }

    private fun showLanguageDialog(fromSettings: Boolean = false) {
        // Первый пункт — «системный», далее 40 языков в их родном написании
        val labels = arrayOf(getString(R.string.language_system)) + LANGUAGES.map { it.second }
        val current = AppCompatDelegate.getApplicationLocales()
        val currentTag = if (current.isEmpty) null else current[0]?.language
        val checked = if (currentTag == null) 0
                      else (LANGUAGES.indexOfFirst { it.first == currentTag }.let { if (it >= 0) it + 1 else 0 })

        AlertDialog.Builder(this)
            .setTitle(getString(R.string.language_title))
            .setSingleChoiceItems(labels, checked) { dialog, which ->
                val tag = if (which == 0) null else LANGUAGES[which - 1].first
                val locales = if (tag == null) LocaleListCompat.getEmptyLocaleList()
                              else LocaleListCompat.forLanguageTags(tag)
                if (which != checked) leavingScreen = true   // экран пересоздастся на новом языке
                AppCompatDelegate.setApplicationLocales(locales)  // применяется + сохраняется автоматически
                dialog.dismiss()
            }
            .setNegativeButton(getString(R.string.back), null)
            .show().backToSettings(fromSettings)
    }


    private fun showAddDialog() {
        val dialogView = LayoutInflater.from(this).inflate(R.layout.dialog_add_currency, null)
        val etSearch = dialogView.findViewById<EditText>(R.id.etSearch)
        val listView = dialogView.findViewById<ListView>(R.id.listView)
        val chipRow  = dialogView.findViewById<android.widget.LinearLayout>(R.id.chipRow)
        val density  = resources.displayMetrics.density

        var filter = -1                       // -1 = все, иначе индекс источника
        var filtered = mutableListOf<CurrencyInfo>()
        var dialog: AlertDialog? = null

        fun applyFilter() {
            val q = etSearch.text.toString().trim().lowercase()
            var list = vm.allCurrencyCodesUnion()
            if (filter >= 0) { val set = vm.codesForSource(filter); list = list.filter { set.contains(it) } }
            if (q.isNotEmpty()) list = list.filter {
                it.lowercase().contains(q) || CurrencyViewModel.currencyName(it).lowercase().contains(q)
            }
            filtered = list.map { CurrencyInfo(it, CurrencyViewModel.currencyDisplayName(it)) }.toMutableList()
        }

        val rowAdapter = object : BaseAdapter() {
            override fun getCount() = filtered.size
            override fun getItem(pos: Int): CurrencyInfo = filtered[pos]
            override fun getItemId(pos: Int) = pos.toLong()
            override fun areAllItemsEnabled() = false
            override fun isEnabled(pos: Int) = !vm.isAdded(filtered[pos].code)

            override fun getView(pos: Int, convertView: View?, parent: ViewGroup): View {
                val view = convertView ?: LayoutInflater.from(parent.context)
                    .inflate(R.layout.dialog_currency_row, parent, false)
                val item = filtered[pos]
                val added = vm.isAdded(item.code)
                val inActive = vm.isInActiveSource(item.code)
                view.findViewById<TextView>(R.id.tvFlag).text = currencyFlag(item.code)
                view.findViewById<TextView>(R.id.tvCode).text = item.code
                view.findViewById<TextView>(R.id.tvName).text = item.name
                view.findViewById<TextView>(R.id.tvAdded).visibility = if (added) View.VISIBLE else View.GONE
                view.alpha = if (added) 0.4f else if (!inActive) 0.72f else 1f
                // Цветные точки источников
                val dots = view.findViewById<android.widget.LinearLayout>(R.id.dots)
                dots.removeAllViews()
                for (i in vm.sourcesWith(item.code)) {
                    val d = View(this@MainActivity)
                    val sz = (9 * density).toInt()
                    val lp = android.widget.LinearLayout.LayoutParams(sz, sz)
                    lp.marginStart = (4 * density).toInt()
                    d.layoutParams = lp
                    d.background = androidx.core.content.ContextCompat.getDrawable(this@MainActivity, R.drawable.bg_dot)
                    d.backgroundTintList = android.content.res.ColorStateList.valueOf(CurrencyRepository.SOURCES[i].color)
                    dots.addView(d)
                }
                return view
            }
        }
        listView.adapter = rowAdapter

        fun refilterAndDraw() { applyFilter(); rowAdapter.notifyDataSetChanged() }

        fun buildChips() {
            chipRow.removeAllViews()
            fun addChip(label: String, idx: Int, color: Int, on: Boolean) {
                val tv = TextView(this@MainActivity)
                tv.text = label; tv.textSize = 12f
                tv.setPadding((11*density).toInt(), (5*density).toInt(), (11*density).toInt(), (5*density).toInt())
                val bg = android.graphics.drawable.GradientDrawable()
                bg.cornerRadius = 14 * density
                if (on) {
                    bg.setColor(color)
                    tv.setTextColor(getColor(R.color.white))
                } else {
                    bg.setColor(getColor(R.color.surface))
                    bg.setStroke((1*density).toInt(), getColor(R.color.divider))
                    tv.setTextColor(getColor(R.color.text_secondary))
                }
                tv.background = bg
                val lp = android.widget.LinearLayout.LayoutParams(
                    android.widget.LinearLayout.LayoutParams.WRAP_CONTENT,
                    android.widget.LinearLayout.LayoutParams.WRAP_CONTENT)
                lp.marginEnd = (6*density).toInt()
                tv.layoutParams = lp
                tv.setOnClickListener { filter = idx; buildChips(); refilterAndDraw() }
                chipRow.addView(tv)
            }
            addChip(getString(R.string.filter_all), -1, 0xFF455A64.toInt(), filter == -1)
            // источники «только вручную» в фильтре не показываем
            CurrencyRepository.SOURCES.forEachIndexed { i, s ->
                if (!s.manualOnly) addChip(s.short, i, s.color, filter == i)
            }
        }

        listView.setOnItemClickListener { _, _, pos, _ ->
            val code = filtered[pos].code
            if (vm.isAdded(code)) return@setOnItemClickListener
            if (vm.isInActiveSource(code)) { vm.addCurrency(code); dialog?.dismiss() }
            else {
                val s = vm.sourcesWith(code)
                if (s.isNotEmpty()) { dialog?.dismiss(); confirmSwitch(code, s[0]) }
            }
        }

        etSearch.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, st: Int, c: Int, a: Int) {}
            override fun onTextChanged(s: CharSequence?, st: Int, b: Int, c: Int) {}
            override fun afterTextChanged(s: Editable?) { refilterAndDraw() }
        })

        buildChips(); refilterAndDraw()
        if (!vm.sourceCodesLoaded()) vm.loadSourceCodes {
            runOnUiThread {
                buildChips(); refilterAndDraw()
                dialog?.setTitle(getString(R.string.add_currency_title, vm.addableCount()))
            }
        }

        dialog = AlertDialog.Builder(this)
            .setTitle(getString(R.string.add_currency_title, vm.addableCount()))
            .setView(dialogView)
            .setNegativeButton(getString(R.string.cancel), null)
            .create()

        dialog.window?.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_STATE_VISIBLE)
        dialog.show()
        etSearch.requestFocus()
    }

    private fun confirmSwitch(code: String, srcIdx: Int) {
        val srcName = sourceOptions()[srcIdx + 1]   // 0=Авто, дальше источники
        AlertDialog.Builder(this)
            .setTitle(getString(R.string.switch_source_title))
            .setMessage(getString(R.string.switch_source_msg, code, srcName))
            .setPositiveButton(getString(R.string.switch_and_add)) { _, _ -> vm.switchSourceAndAdd(code, srcIdx) }
            .setNegativeButton(getString(R.string.back)) { _, _ -> showAddDialog() }
            .show()
    }

    companion object {
        // 40 языков: тег (совпадает с папкой ресурсов) → родное название
        const val KEY_LANG_INITIALIZED = "lang_initialized"

        val LANGUAGES = listOf(
            "en" to "English",
            "sr" to "Srpski",
            "hr" to "Hrvatski",
            "bs" to "Bosanski",
            "mk" to "Македонски",
            "sq" to "Shqip",
            "sl" to "Slovenščina",
            "bg" to "Български",
            "el" to "Ελληνικά",
            "ro" to "Română",
            "de" to "Deutsch",
            "fr" to "Français",
            "es" to "Español",
            "it" to "Italiano",
            "pt" to "Português",
            "nl" to "Nederlands",
            "pl" to "Polski",
            "cs" to "Čeština",
            "sk" to "Slovenčina",
            "hu" to "Magyar",
            "sv" to "Svenska",
            "da" to "Dansk",
            "nb" to "Norsk",
            "fi" to "Suomi",
            "lt" to "Lietuvių",
            "lv" to "Latviešu",
            "et" to "Eesti",
            "ru" to "Русский",
            "ka" to "ქართული",
            "zh" to "中文",
            "ja" to "日本語",
            "ko" to "한국어",
            "th" to "ไทย",
            "vi" to "Tiếng Việt",
            "id" to "Bahasa Indonesia",
            "hi" to "हिन्दी",
            "ar" to "العربية",
            "he" to "עברית",
            "fa" to "فارسی",
            "tr" to "Türkçe"
        )
    }
}
