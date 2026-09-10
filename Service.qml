import QtQuick
import Quickshell
import Quickshell.Io
import "core/Currency.js" as Currency

QtObject {
  id: root
  property var shell: null
  property var manifest: null

  readonly property string currencyCachePath: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/keystroke/currency-rates.json"
  readonly property string usagePath: Quickshell.env("HOME") + "/.local/state/keystroke/currency-usage.json"
  readonly property string pluginPath: decodeURIComponent(Qt.resolvedUrl(".").toString().replace(/^file:\/\//, ""))

  FileView {
    id: currencyFile
    path: root.currencyCachePath
    watchChanges: true
    printErrors: false
    onLoaded: {
      try {
        var parsed = JSON.parse(text())
        if (parsed.version === 1 && parsed.base === "EUR" && parsed.rates && parsed.fetchedAt)
          root.currencyCache = parsed
      } catch (e) { }
      if (root.host) root.host.requery()
    }
    onFileChanged: reload()
  }

  property var currencyCache: null

  property var currencyCounts: ({})
  property var seenCurrencyTargets: ({})
  property string pendingTarget: ""

  FileView {
    id: currencyUsage
    path: root.usagePath
    printErrors: false
    atomicWrites: true
    onLoaded: root.currencyCounts = Currency.readCounts(text())
  }

  Connections {
    target: root.host
    function onOpenedChanged() {
      learningDelay.stop()
      root.seenCurrencyTargets = ({})
    }
  }

  Timer {
    id: learningDelay
    interval: 1200
    onTriggered: if (root.host && root.host.opened) root.learnTarget(root.pendingTarget)
  }

  function learnTarget(code) {
    if (!code || root.seenCurrencyTargets[code]) return
    root.seenCurrencyTargets[code] = true
    var counts = JSON.parse(JSON.stringify(root.currencyCounts))
    counts[code] = Math.min((counts[code] || 0) + 1, 1000000)
    root.currencyCounts = counts
    currencyUsage.setText(JSON.stringify({version: 1, counts: counts}) + "\n")
  }

  function answer(text, detail, query) {
    return {
      id: "currency-conversion",
      title: text,
      subtitle: detail,
      icon: "\u20ac",
      section: "Currency",
      verb: "Copy result",
      tier: "answer",
      score: 195,
      action: { type: "copy", text: text },
      preview: text,
      previewLabel: "CONVERSION",
      previewDetail: query + "\n" + detail
    }
  }

  function currencyRows(conversion, ctx) {
    if (conversion.base === conversion.quote)
      return [root.answer(Currency.result(conversion, 1), "1 " + conversion.base + " = 1 " + conversion.quote, ctx.query)]
    var pair = Currency.crossRate(root.currencyCache, conversion)
    if (pair) {
      var downloaded = new Date(root.currencyCache.fetchedAt).toLocaleString(Qt.locale("en_US"), "dd MMM HH:mm")
      var rateDates = pair.date.split(" / ").map(function(date) {
        return new Date(date + "T12:00:00").toLocaleDateString(Qt.locale("en_US"), "dd MMM yyyy")
      })
      if (rateDates.length > 1) rateDates = pair.date.split(" / ").map(function(date) {
        return new Date(date + "T12:00:00").toLocaleDateString(Qt.locale("en_US"), "dd MMM")
      })
      var detail = "1 " + conversion.base + " = " + Number(pair.rate.toPrecision(6)) + " " + conversion.quote
      var stale = Currency.overdue(root.currencyCache.fetchedAt, Date.now())
      var text = Currency.result(conversion, pair.rate)
      if (text) {
        var row = root.answer(text, detail, ctx.query)
        if (conversion.explicit && ctx.settings.currencyTargetMode === "Automatic") {
          row.currencyTarget = conversion.quote
          root.pendingTarget = conversion.quote
          if (!root.seenCurrencyTargets[conversion.quote]) learningDelay.restart()
        }
        row.previewDetail = "Rates: " + rateDates.join(" / ")
          + "\nFetched: " + downloaded
          + "\n" + (stale ? "Refresh pending" : "Frankfurter / Daily")
        return [row]
      }
    }
    return [{
      id: "currency-status",
      title: root.currencyCache ? "Currency not available" : "Exchange rates not downloaded yet",
      subtitle: root.currencyCache ? "Check your currency codes" : "Automatic download will retry when connected",
      section: "Currency",
      tier: "answer",
      score: 195,
      disabled: true,
      action: { type: "noop" }
    }]
  }

  Process {
    id: systemdInstaller
    property bool installed: false
    command: ["bash", "-c", "systemctl --user is-enabled keystroke-currency.timer 2>/dev/null || (systemctl --user link '" + root.pluginPath + "/systemd/keystroke-currency.timer' && systemctl --user enable --now keystroke-currency.timer)"]
    running: true
    stdout: StdioCollector { onStreamFinished: systemdInstaller.installed = true }
    stderr: StdioCollector { onStreamFinished: { } }
  }

  readonly property var provider: ({
    apiVersion: 1,
    name: "Currency",
    icon: "€",
    color: "#81c8b6",
    description: "Currency conversion with EUR-based cross rates, preferred and automatic targets",
    patterns: [
      { id: "currency-symbol", regex: "[$€£]\\s*\\d", flags: "", boost: 12, example: "$100 in EUR" },
      { id: "currency-code", regex: "\\d[\\d.,]*\\s*[a-z]{3}", flags: "i", boost: 10, example: "129 usd to try" }
    ],
    settings: [
      { key: "currencyTargetMode", type: "enum", label: "Currency target", "default": "Preferred",
        options: ["Preferred", "Automatic"], description: "Automatic learns explicit targets you view or copy." },
      { key: "preferredCurrency", type: "string", label: "Preferred currency", "default": "TRY",
        description: "Target for amounts like 129usd. Currency code, e.g. TRY, EUR or USD. Also the automatic fallback." }
    ],
    query: function(ctx) {
      learningDelay.stop()
      if (ctx.scope) return []
      var q = ctx.query.trim()
      if (!q) return []
      var currency = Currency.parse(q, Currency.preferredTarget(ctx.settings, root.currencyCounts, root.currencyCache))
      if (!currency) return []
      if (!currency.explicit && currency.base !== "EUR" && (!root.currencyCache || !root.currencyCache.rates[currency.base])) return []
      return root.currencyRows(currency, ctx)
    },
    activate: function(row, ctx) {
      if (row.currencyTarget && ctx.settings.currencyTargetMode === "Automatic") root.learnTarget(row.currencyTarget)
      return ctx.alternate && row.altAction ? row.altAction : row.action
    }
  })
}
