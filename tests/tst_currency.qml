import QtQuick
import QtTest
import "../core/Currency.js" as Currency

TestCase {
  name: "Currency"
  function test_queries() {
    compare(Currency.parse("100 usd to try"), {amount: 100, base: "USD", quote: "TRY", key: "USD/TRY", explicit: true})
    compare(Currency.parse("12,50 eur in tl").amount, 12.5)
    compare(Currency.parse("12,50 eur in tl").quote, "TRY")
    compare(Currency.parse("100 usd to tr"), null)
    compare(Currency.parse("2m in feet"), null)
  }
  function test_preferred_currency() {
    compare(Currency.parse("129usd", "TRY").quote, "TRY")
    compare(Currency.parse("129 usd", "EUR").quote, "EUR")
    compare(Currency.parse("129usd", "TRY").explicit, false)
    compare(Currency.parse("129 usd to eur", "TRY").quote, "EUR")
    compare(Currency.parse("129 usd to", "TRY"), null)
    compare(Currency.parse("129 usd to e", "TRY"), null)
    compare(Currency.parse("12,50eur", "TL").quote, "TRY")
    var cache = {rates: {TRY: {}, USD: {}, GBP: {}}}
    compare(Currency.preferredTarget({preferredCurrency: "TRY", currencyTargetMode: "Preferred"}, {USD: 10}, cache), "TRY")
    compare(Currency.preferredTarget({preferredCurrency: "TRY", currencyTargetMode: "Automatic"}, {USD: 10, TRY: 2}, cache), "USD")
    compare(Currency.preferredTarget({preferredCurrency: "TRY", currencyTargetMode: "Automatic"}, {}, cache), "TRY")
    compare(Currency.preferredTarget({preferredCurrency: "TRY", currencyTargetMode: "Automatic"}, {USD: 2, TRY: 2}, cache), "TRY")
    compare(Currency.preferredTarget({preferredCurrency: "TRY", currencyTargetMode: "Automatic"}, {XYZ: 100, GBP: 3}, cache), "GBP")
    compare(Currency.readCounts('{"version":1,"counts":{"TRY":3,"USD":-2,"invalid":7}}'), {TRY: 3})
    compare(Currency.readCounts('broken'), {})
  }
  function test_cross_rates() {
    var cache = {base: "EUR", rates: {USD: {rate: 1.2, date: "2026-09-10"}, TRY: {rate: 60, date: "2026-09-10"}}}
    compare(Currency.crossRate(cache, Currency.parse("100 usd to try")).rate, 50)
    compare(Currency.crossRate(cache, Currency.parse("100 eur to try")).rate, 60)
    compare(Currency.crossRate(cache, Currency.parse("100 try to eur")).rate, 1 / 60)
    compare(Currency.crossRate(cache, Currency.parse("100 usd to gbp")), null)
    compare(Currency.crossRate(cache, Currency.parse("100 usd to try")).date, "2026-09-10")
    cache.rates.USD.date = "2026-09-09"
    compare(Currency.crossRate(cache, Currency.parse("100 usd to try")).date, "2026-09-09 / 2026-09-10")
    compare(Currency.result(Currency.parse("100 usd to try"), 50), (5000).toLocaleString(Qt.locale(), "f", 2) + " TRY")
  }
  function test_refresh_boundary() {
    var fetched = new Date(2026, 8, 10, 5).toISOString()
    verify(!Currency.overdue(fetched, new Date(2026, 8, 11, 3, 59).getTime()))
    verify(Currency.overdue(fetched, new Date(2026, 8, 11, 4).getTime()))
    verify(Currency.overdue("invalid", Date.now()))
  }
}
