# Keystroke Currency

> **This repository is archived.** The currency extension has been merged into [Keystroke](https://github.com/evindor/keystroke) as a built-in extension. See [evindor/keystroke#7](https://github.com/evindor/keystroke/pull/7).

Currency conversion is now shipped with Keystroke. To use it:

1. Update Keystroke to the latest version
2. Open the palette, type `ext`, go to **Extensions → Currency**
3. Toggle **Enabled** on

The extension lives at [`extensions/currency/`](https://github.com/evindor/keystroke/tree/dev/extensions/currency) in the Keystroke repository.

---

## Original Features

- **EUR-based cross rates** — all currency pairs computed from a single daily EUR table
- **Compact queries** — `129usd` converts to your preferred currency
- **Explicit targets** — `100 usd to eur`, `12,50 eur in tl`
- **Symbol support** — `$100 in eur`, `100€ to $`, `£20 to usd`
- **Preferred and automatic targets** — Automatic mode learns the currencies you use most
- **On-demand fetch** — rates downloaded on first conversion of the day (after 04:00), no background services
- **Freshness tracking** — shows rate dates and download time, flags when refresh is pending

## License

MIT
