package com.example.currencyconverter.ui

data class CurrencyItem(
    val code: String,
    val name: String,
    val flag: String,
    val symbol: String,
    val amount: Double,
    val rateText: String
)

data class CurrencyInfo(val code: String, val name: String)
