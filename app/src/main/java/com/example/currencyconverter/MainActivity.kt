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
import com.example.currencyconverter.databinding.ActivityMainBinding
import com.example.currencyconverter.ui.CurrencyAdapter
import com.example.currencyconverter.ui.CurrencyInfo
import com.example.currencyconverter.ui.CurrencyViewModel
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
                binding.tvCount.text = getString(R.string.selected, s.currencyItems.size)
                // Перенос не должен рвать название источника («ExchangeRate-» / «API»)
                // и не должен начинать строку с разделителя «·»: дефис внутри
                // названия и пробел перед точкой делаем неразрывными.
                val src = shortSource(s.source)
                fun tidy(t: String) = t.replace(" · ", "\u00A0· ")
                binding.tvStatus.text = tidy(when {
                    s.error != null         -> getString(R.string.error_prefix, s.error)
                    s.lastUpdated.isEmpty() -> getString(R.string.loading)
                    // кэшу больше суток — предупреждаем заметно
                    s.stale                 -> getString(R.string.rates_stale, s.lastUpdated, src)
                    s.fromCache             -> getString(R.string.rates_offline, s.lastUpdated, src)
                    else                    -> getString(R.string.updated, s.lastUpdated, src)
                })
                binding.tvStatus.setTextColor(
                    when {
                        // цвета из ресурсов, у каждой темы свой: зашитый #666666 в тёмной
                        // теме давал 2.9:1 — строку статуса было почти не видно
                        s.stale     -> getColor(R.color.status_stale)     // устаревшие курсы
                        s.fromCache -> getColor(R.color.status_offline)   // офлайн, но свежие
                        else        -> getColor(R.color.text_secondary)
                    }
                )
                adapter.decimalPlaces = s.decimalPlaces
                adapter.grouping = s.grouping
                adapter.submitList(s.currencyItems, s.activeCurrency)
            }
        }

        binding.tvVersion.text = getString(R.string.version, BuildConfig.VERSION_NAME)
        binding.btnSourceInfo.setOnClickListener { showSourceInfoDialog() }
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
        vm.resumeAutoRefresh()
    }

    override fun onResume() {
        super.onResume()
        vm.refresh()
    }

    // приложение ушло с экрана — свёрнуто, заблокирован телефон, открыто другое
    override fun onStop() {
        super.onStop()
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
        AlertDialog.Builder(this)
            .setTitle(getString(R.string.source_info_title))
            .setMessage(getString(R.string.source_info_message))
            .setNeutralButton("exchangerate-api.com") { _, _ ->
                openUrl("https://www.exchangerate-api.com")
            }
            .setPositiveButton(getString(R.string.ok), null)
            .show()
    }

    // Названия источников: индекс 0 = Авто (локализуется), дальше — бренды (не переводятся)
    private fun sourceOptions() = arrayOf(
        getString(R.string.source_auto), "ExchangeRate-API", "F.A.", "Frankfurter (ECB)"
    )

    private fun showSettingsDialog() {
        val decimals = vm.getDecimalPlaces()
        val decimalLabel = if (decimals == 0) getString(R.string.precision_value_int)
                           else getString(R.string.precision_value_n, decimals)
        val srcName = sourceOptions()[vm.getSourceMode().coerceIn(0, 3)]

        val groupingLabel = groupingOptions()[vm.getGrouping().coerceIn(0, 2)]

        val themeLabel = themeOptions()[getSharedPreferences("axe_prefs", MODE_PRIVATE)
            .getInt("theme", 0).coerceIn(0, 2)]

        val items = arrayOf(
            getString(R.string.setting_theme, themeLabel),
            getString(R.string.setting_precision, decimalLabel),
            getString(R.string.setting_grouping, groupingLabel),
            getString(R.string.setting_source, srcName),
            getString(R.string.setting_language, currentLanguageLabel())
        )

        AlertDialog.Builder(this)
            .setTitle(getString(R.string.settings))
            .setItems(items) { _, which ->
                when (which) {
                    0 -> showThemeDialog()
                    1 -> showDecimalDialog()
                    2 -> showGroupingDialog()
                    3 -> showSourceDialog()
                    4 -> showLanguageDialog()
                }
            }
            .setNegativeButton(getString(R.string.close), null)
            .show()
    }

    private fun showDecimalDialog() {
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
            .show()
    }

    private fun groupingOptions() = arrayOf(
        getString(R.string.group_none), getString(R.string.group_space), getString(R.string.group_comma)
    )

    private fun showGroupingDialog() {
        AlertDialog.Builder(this)
            .setTitle(getString(R.string.grouping_title))
            .setSingleChoiceItems(groupingOptions(), vm.getGrouping().coerceIn(0, 2)) { dialog, which ->
                vm.setGrouping(which)
                dialog.dismiss()
            }
            .setNegativeButton(getString(R.string.back), null)
            .show()
    }

    private fun showSourceDialog() {
        val checked = vm.getSourceMode().coerceIn(0, 3)

        AlertDialog.Builder(this)
            .setTitle(getString(R.string.source_title))
            .setSingleChoiceItems(sourceOptions(), checked) { dialog, which ->
                vm.setSourceMode(which)
                dialog.dismiss()
            }
            .setNegativeButton(getString(R.string.back), null)
            .show()
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
        "ExchangeRate-API"  -> "ER\u2011API"
        "Frankfurter (ECB)" -> "Fra.ECB"
        else                -> name           // «F.A.» уже короткое
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

    private fun showThemeDialog() {
        val prefs = getSharedPreferences("axe_prefs", MODE_PRIVATE)
        AlertDialog.Builder(this)
            .setTitle(getString(R.string.theme_title))
            .setSingleChoiceItems(themeOptions(), prefs.getInt("theme", 0).coerceIn(0, 2)) { dialog, which ->
                prefs.edit().putInt("theme", which).apply()
                dialog.dismiss()
                applyTheme()      // setDefaultNightMode сам пересоздаст экран
            }
            .setNegativeButton(getString(R.string.back), null)
            .show()
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

    private fun showLanguageDialog() {
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
                AppCompatDelegate.setApplicationLocales(locales)  // применяется + сохраняется автоматически
                dialog.dismiss()
            }
            .setNegativeButton(getString(R.string.back), null)
            .show()
    }

    private val SRC_SHORT  = arrayOf("er-api", "F.A.", "ECB")
    private val SRC_COLORS = intArrayOf(0xFF1565C0.toInt(), 0xFF43A047.toInt(), 0xFFFB8C00.toInt())

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
                    d.backgroundTintList = android.content.res.ColorStateList.valueOf(SRC_COLORS[i])
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
            SRC_SHORT.forEachIndexed { i, s -> addChip(s, i, SRC_COLORS[i], filter == i) }
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
        val srcName = sourceOptions()[srcIdx + 1]   // 0=Авто, 1..3 = источники
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
