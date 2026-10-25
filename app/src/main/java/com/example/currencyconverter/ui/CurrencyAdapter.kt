package com.example.currencyconverter.ui

import android.annotation.SuppressLint
import java.util.Locale
import android.text.Editable
import android.text.TextWatcher
import android.view.GestureDetector
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.ViewGroup
import androidx.recyclerview.widget.DiffUtil
import androidx.recyclerview.widget.RecyclerView
import com.example.currencyconverter.databinding.ItemCurrencyBinding

class CurrencyAdapter(
    private val onAmountChanged: (currency: String, amount: Double) -> Unit,
    private val onDeleteClick: (currency: String) -> Unit,
    /** Нажали «Готово» на клавиатуре — экран её закрывает. */
    private val onDone: () -> Unit = {}
) : RecyclerView.Adapter<CurrencyAdapter.ViewHolder>() {

    var startDragListener: ((ViewHolder) -> Unit)? = null
    var onOrderChanged: ((List<String>) -> Unit)? = null
    var decimalPlaces: Int = 0
    var grouping: Int = 0

    private var items: MutableList<CurrencyItem> = mutableListOf()
    private var activeCurrency: String = ""
    private var isDragging = false
    private var renderedDecimalPlaces: Int = 0
    private var renderedGrouping: Int = 0

    init { setHasStableIds(true) }

    override fun getItemId(position: Int) = items[position].code.hashCode().toLong()

    fun submitList(newItems: List<CurrencyItem>, newActive: String) {
        if (isDragging) return
        val diff = DiffUtil.calculateDiff(object : DiffUtil.Callback() {
            override fun getOldListSize() = items.size
            override fun getNewListSize() = newItems.size
            override fun areItemsTheSame(o: Int, n: Int) = items[o].code == newItems[n].code
            override fun areContentsTheSame(o: Int, n: Int) = items[o] == newItems[n]
        })
        val prevActive = activeCurrency
        val decimalsChanged = renderedDecimalPlaces != decimalPlaces || renderedGrouping != grouping
        activeCurrency = newActive
        renderedDecimalPlaces = decimalPlaces
        renderedGrouping = grouping
        items = newItems.toMutableList()
        // Смена точности не меняет amount → DiffUtil не видит разницы.
        // Форсируем полный ребинд, чтобы все строки переформатировались.
        if (prevActive != newActive || decimalsChanged) notifyDataSetChanged()
        else diff.dispatchUpdatesTo(this)
    }

    fun onItemMove(from: Int, to: Int) {
        val item = items.removeAt(from)
        items.add(to, item)
        notifyItemMoved(from, to)
    }

    fun commitOrder() {
        onOrderChanged?.invoke(items.map { it.code })
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int) =
        ViewHolder(ItemCurrencyBinding.inflate(LayoutInflater.from(parent.context), parent, false))

    override fun onBindViewHolder(holder: ViewHolder, position: Int) {
        holder.bind(items[position], items[position].code == activeCurrency)
    }

    override fun getItemCount() = items.size

    @SuppressLint("ClickableViewAccessibility")
    inner class ViewHolder(private val b: ItemCurrencyBinding) : RecyclerView.ViewHolder(b.root) {

        private var currentCode = ""
        private var currentAmount = 0.0
        private var textWatcher: TextWatcher? = null

        init {
            // Клавиша «Готово» (✓) закрывает клавиатуру. Без imeOptions Android
            // ставил на это место «Далее» (→|), и клавиша не закрывала её, а
            // перескакивала в следующую строку — убрать клавиатуру было нечем,
            // кроме системного «Назад».
            b.etAmount.setOnEditorActionListener { _, actionId, _ ->
                if (actionId == android.view.inputmethod.EditorInfo.IME_ACTION_DONE) { onDone(); true } else false
            }
            b.etAmount.setOnFocusChangeListener { _, hasFocus ->
                if (hasFocus && currentCode.isNotEmpty()) {
                    // Используем точное значение из модели, а не отображаемый текст
                    // (ceil-округление отображения иначе накапливает ошибку при смене поля)
                    onAmountChanged(currentCode, currentAmount)
                }
            }

            // Двойной клик по сумме → выделить ВСЁ число (в т.ч. дробную часть),
            // а не «слово». post{} — чтобы перебить стандартное выделение EditText.
            val doubleTap = GestureDetector(b.etAmount.context,
                object : GestureDetector.SimpleOnGestureListener() {
                    override fun onDoubleTap(e: MotionEvent): Boolean {
                        b.etAmount.post { b.etAmount.selectAll() }
                        return false
                    }
                })
            b.etAmount.setOnTouchListener { _, event ->
                doubleTap.onTouchEvent(event)
                false  // обычные тапы/курсор/вставка работают как прежде
            }

            // Вся карточка — зона нажатия: это тач-экран, целиться в число
            // незачем. Тап мимо поля ставит в него фокус (число выделяется
            // целиком — selectAllOnFocus) и открывает клавиатуру. Крестик и
            // ручка перехватывают свои касания сами.
            b.card.setOnClickListener {
                if (b.etAmount.hasFocus()) return@setOnClickListener
                b.etAmount.requestFocus()
                val imm = b.etAmount.context.getSystemService(android.content.Context.INPUT_METHOD_SERVICE)
                    as android.view.inputmethod.InputMethodManager
                b.etAmount.post { imm.showSoftInput(b.etAmount, android.view.inputmethod.InputMethodManager.SHOW_IMPLICIT) }
            }

            b.ivDragHandle.setOnTouchListener { _, event ->
                if (event.actionMasked == MotionEvent.ACTION_DOWN) {
                    isDragging = true
                    startDragListener?.invoke(this)
                }
                false
            }
        }

        fun onDragEnd() {
            isDragging = false
            commitOrder()
        }

        fun bind(item: CurrencyItem, isActive: Boolean) {
            currentCode = item.code
            currentAmount = item.amount

            b.tvFlag.text   = item.flag
            b.tvCode.text   = item.code
            b.tvName.text   = item.name
            b.tvSymbol.text = item.symbol
            b.tvRate.text   = item.rateText

            b.card.strokeWidth = if (isActive) 3 else 0
            // цвет акцента из темы: зашитый светло-синий не менялся в тёмной теме
            b.card.strokeColor = if (isActive) b.root.context.getColor(com.example.currencyconverter.R.color.accent) else 0x00000000

            // Не перезаписываем только поле, которое СЕЙЧАС в фокусе (живой ввод).
            // Активную валюту без фокуса тоже переформатируем — иначе при смене
            // точности её строка не обновляется.
            if (!b.etAmount.hasFocus()) setAmountSilently(fmtAmount(item.amount))

            textWatcher?.let { b.etAmount.removeTextChangedListener(it) }
            textWatcher = object : TextWatcher {
                override fun beforeTextChanged(s: CharSequence?, st: Int, c: Int, a: Int) {}
                override fun onTextChanged(s: CharSequence?, st: Int, b2: Int, c: Int) {}
                override fun afterTextChanged(s: Editable?) {
                    if (b.etAmount.hasFocus())
                        onAmountChanged(currentCode, s.toString().parseAmount())
                }
            }
            b.etAmount.addTextChangedListener(textWatcher)
            b.btnDelete.setOnClickListener { onDeleteClick(item.code) }
        }

        private fun setAmountSilently(text: String) {
            textWatcher?.let { b.etAmount.removeTextChangedListener(it) }
            if (b.etAmount.text.toString() != text) b.etAmount.setText(text)
            textWatcher?.let { b.etAmount.addTextChangedListener(it) }
        }

        // Умное округление вверх: выбранная точность — минимум, но если она
        // искажает абсолютное значение больше чем на TOL (2%), добавляем знаки,
        // чтобы у мелких валют не терялся финансовый смысл (0.0067 не станет «1»).
        private fun fmtAmount(v: Double): String {
            val n = decimalPlaces
            if (v <= 0.0) return if (n == 0) "0" else String.format(Locale.ROOT, "%.${n}f", 0.0)
            val tol = 0.02
            var d = n
            while (d < 8) {
                val f = Math.pow(10.0, d.toDouble())
                val ceiled = Math.ceil(v * f - 1e-9) / f
                if (ceiled - v <= tol * v) break
                d++
            }
            val f = Math.pow(10.0, d.toDouble())
            val ceiled = Math.ceil(v * f - 1e-9) / f
            // Locale.ROOT: иначе на русском, сербском, немецком десятичный знак —
            // запятая, и она сталкивается с запятой-разделителем разрядов
            // («1,,17»), а на арабском и персидском цифры выходят восточные
            // (۱٫۱۷) — такое поле при правке разбиралось в 0, и обнулялись все строки.
            val text = if (d == 0) ceiled.toLong().toString() else String.format(Locale.ROOT, "%.${d}f", ceiled)
            return groupDigits(text)
        }

        /** Разделитель разрядов из настроек. Применяется только к целой части;
         *  в поле, которое сейчас редактируют, группировки нет — она мешала бы
         *  набору и прыгала бы под курсором. */
        private fun groupDigits(text: String): String {
            if (grouping == 0) return text
            val sep = if (grouping == 1) "\u00A0" else ","   // неразрывный пробел, чтобы число не рвалось
            val dot = text.indexOf('.')
            val intPart = if (dot >= 0) text.substring(0, dot) else text
            val rest = if (dot >= 0) text.substring(dot) else ""
            if (intPart.length <= 3) return text
            val grouped = intPart.reversed().chunked(3).joinToString(sep).reversed()
            return grouped + rest
        }

        private fun String.parseAmount(): Double = AmountParser.parse(this, grouping)
    }
}
