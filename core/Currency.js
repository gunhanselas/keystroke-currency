.pragma library

function parse(query, preferred) {
  var match = /^\s*([+-]?(?:\d+(?:[.,]\d+)?|[.,]\d+))\s*([a-z]{3}|tl)(?:\s+(?:to|in)\s+([a-z]{3}|tl))?\s*$/i.exec(query)
  if (!match) return null
  var amount = Number(match[1].replace(",", "."))
  if (!isFinite(amount)) return null
  var base = match[2].toUpperCase(), quote = String(match[3] || preferred || "").toUpperCase()
  if (!/^[A-Z]{3}$/.test(quote) && quote !== "TL") return null
  if (base === "TL") base = "TRY"
  if (quote === "TL") quote = "TRY"
  return { amount: amount, base: base, quote: quote, key: base + "/" + quote, explicit: !!match[3] }
}

function crossRate(cache, conversion) {
  if (!cache || cache.base !== "EUR" || !cache.rates) return null
  var source = conversion.base === "EUR" ? {rate: 1, date: ""} : cache.rates[conversion.base]
  var target = conversion.quote === "EUR" ? {rate: 1, date: ""} : cache.rates[conversion.quote]
  if (!source || !target || !(source.rate > 0) || !(target.rate > 0)) return null
  var rate = target.rate / source.rate
  if (!isFinite(rate)) return null
  var dates = [source.date, target.date].filter(function(d) { return !!d })
  dates.sort()
  return { rate: rate, date: dates[0] === dates[dates.length - 1] ? dates[0] : dates.join(" / ") }
}

function overdue(fetchedAt, nowMs) {
  var now = new Date(nowMs), boundary = new Date(nowMs)
  boundary.setHours(4, 0, 0, 0)
  if (now < boundary) boundary.setDate(boundary.getDate() - 1)
  var fetched = Date.parse(fetchedAt)
  return !isFinite(fetched) || fetched < boundary.getTime()
}

function result(conversion, rate) {
  var value = conversion.amount * rate
  return isFinite(value) ? value.toLocaleString(Qt.locale(), "f", 2) + " " + conversion.quote : ""
}

function preferredTarget(settings, counts, cache) {
  var preferred = String(settings.preferredCurrency || "TRY").trim().toUpperCase()
  if (preferred === "TL") preferred = "TRY"
  var available = function(code) { return code === "EUR" || !!(cache && cache.rates && cache.rates[code]) }
  if (!available(preferred)) preferred = "TRY"
  if (settings.currencyTargetMode !== "Automatic") return preferred
  var winner = preferred, best = Number(counts[preferred]) || 0
  Object.keys(counts).sort().forEach(function(code) {
    var count = counts[code]
    if (available(code) && typeof count === "number" && isFinite(count) && count > best) {
      winner = code
      best = count
    }
  })
  return winner
}

function readCounts(raw) {
  var counts = {}
  try {
    var data = JSON.parse(raw)
    if (data.version !== 1 || !data.counts) return counts
    Object.keys(data.counts).forEach(function(code) {
      var count = data.counts[code]
      if (/^[A-Z]{3}$/.test(code) && typeof count === "number" && isFinite(count) && count > 0)
        counts[code] = Math.min(Math.floor(count), 1000000)
    })
  } catch (e) { }
  return counts
}
