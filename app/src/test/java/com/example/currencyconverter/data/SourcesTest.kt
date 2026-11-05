package com.example.currencyconverter.data

import com.google.gson.Gson
import com.google.gson.JsonObject
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.IOException
import java.util.Collections

/**
 * Источники курсов: разбор ответов, порядок, резерв, перенос сохранённого
 * выбора. Сеть подменяется — тест не зависит от того, какой источник жив.
 */
class SourcesTest {
    private fun json(s: String) = Gson().fromJson(s, JsonObject::class.java)
    private val names get() = CurrencyRepository.SOURCES.map { it.name }
    private val wise get() = names.indexOf("Wise") + 1
    private val fiveAuto = listOf("Coinbase", "FXRatesAPI", "ExchangeRate-API", "F.A.", "Frankfurter (ECB)")

    /** Репозиторий с подменённой сетью; что спросили — в [asked]. */
    private fun repo(asked: MutableList<String>, answer: (String) -> String) =
        CurrencyRepository { url -> asked.add(url); answer(url) }
    private fun askedList(): MutableList<String> = Collections.synchronizedList(mutableListOf())

    @Test fun liveSources_ratesComeAsStrings() {
        assertEquals(
            mapOf("EUR" to 1.0, "RSD" to 117.6, "NUM" to 3.5),
            CurrencyRepository.numRates(json(
                """{"EUR":"1","rsd":"117.6","BAD":"x","ZERO":"0","NEG":"-2","INF":"Infinity","NUM":3.5,"NUL":null}""")))
    }

    @Test fun coinbaseAndFxRates_areParsed() = runBlocking {
        val asked = askedList()
        val cb = repo(asked) { url ->
            if ("api.coinbase.com" in url) """{"data":{"currency":"EUR","rates":{"EUR":"1","USD":"1.1237","BTC":"0.0000098"}}}"""
            else throw IOException("down")
        }.getRates(0).getOrThrow()
        assertEquals("Coinbase", cb.source)
        assertEquals(mapOf("EUR" to 1.0, "USD" to 1.1237, "BTC" to 0.0000098), cb.rates)

        val fx = repo(askedList()) { url ->
            if ("api.fxratesapi.com" in url) """{"success":true,"base":"EUR","rates":{"EUR":1,"USD":1.1237}}"""
            else throw IOException("down")
        }.getRates(2).getOrThrow()
        assertEquals("FXRatesAPI", fx.source)
        assertEquals(mapOf("EUR" to 1.0, "USD" to 1.1237), fx.rates)
    }

    @Test fun fxRatesRefusal_isNotAnAnswer() = runBlocking {
        // отказ (лимит, сбой) приходит с кодом 200 и success=false — даже если
        // в ответе есть что-то похожее на курсы, это ошибка источника
        val r = repo(askedList()) { url ->
            if ("api.fxratesapi.com" in url) """{"success":false,"rates":{"EUR":1,"USD":9}}"""
            else throw IOException("down")
        }.getRates(2)
        assertTrue("отказ FXRatesAPI принят за успешный ответ: ${r.getOrNull()}", r.isFailure)
    }

    @Test fun autoOrder_liveFirst_manualOnlySkipped() {
        assertEquals(fiveAuto, CurrencyRepository.order(0))
        assertEquals(listOf("F.A.", "Coinbase", "FXRatesAPI", "ExchangeRate-API", "Frankfurter (ECB)"),
            CurrencyRepository.order(4))
        assertEquals(listOf("Wise") + fiveAuto, CurrencyRepository.order(wise))
        assertEquals("неизвестный номер = «Авто»", fiveAuto, CurrencyRepository.order(99))
    }

    @Test fun fallsBack_whenCoinbaseIsDown_andNeverAsksWise() = runBlocking {
        val asked = askedList()
        val snap = repo(asked) { url ->
            if ("api.fxratesapi.com" in url) """{"success":true,"rates":{"EUR":1,"USD":1.5}}"""
            else throw IOException("down")          // Coinbase недоступен
        }.getRates(0, listOf("EUR", "USD")).getOrThrow()
        assertEquals("FXRatesAPI", snap.source)
        assertEquals(1.5, snap.rates["USD"]!!, 0.0)
        assertEquals("после успешного ответа дальше не спрашиваем: $asked", 2, asked.size)
        assertTrue("первым идёт Coinbase", "api.coinbase.com" in asked[0])
        assertFalse("в «Авто» Wise не участвует", asked.any { "wise.com" in it })
    }

    @Test fun wise_asksOnlyShownCurrencies() = runBlocking {
        val asked = askedList()
        val snap = repo(asked) { url ->
            if ("wise.com" in url) """{"source":"EUR","target":"X","value":117.6,"time":1}"""
            else throw IOException("down")
        }.getRates(wise, listOf("EUR", "RSD", "USD", "RSD")).getOrThrow()
        assertEquals("Wise", snap.source)
        assertEquals(mapOf("EUR" to 1.0, "RSD" to 117.6, "USD" to 117.6), snap.rates)
        assertEquals(setOf("https://wise.com/rates/live?source=EUR&target=RSD",
                           "https://wise.com/rates/live?source=EUR&target=USD"), asked.toSet())
    }

    @Test fun savedChoice_movesToNewNumbering() {
        // до 1.65: 1 — ExchangeRate-API, 2 — F.A., 3 — Frankfurter
        assertEquals(listOf(0, 3, 4, 5), listOf(0, 1, 2, 3).map { CurrencyRepository.migrateSource(it, 1) })
        assertEquals("ExchangeRate-API", names[3 - 1])
        assertEquals("F.A.", names[4 - 1])
        assertEquals("Frankfurter (ECB)", names[5 - 1])
        assertEquals("повторный перенос ничего не сдвигает",
            listOf(1, 2, 3, 6), listOf(1, 2, 3, 6).map { CurrencyRepository.migrateSource(it, 2) })
    }
}
