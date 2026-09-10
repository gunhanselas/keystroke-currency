# Keystroke Currency

A standalone currency conversion provider for the [Keystroke](https://github.com/evindor/keystroke) command palette.

## Features

- **EUR-based cross rates** — all currency pairs computed from a single daily EUR table
- **Compact queries** — `129usd` converts to your preferred currency (TRY by default)
- **Explicit targets** — `100 usd to eur`, `12,50 eur in tl`
- **Preferred and automatic targets** — Automatic mode learns the currencies you use most
- **Daily cache** — rates downloaded at 04:00 local time, with offline catch-up after suspend
- **Freshness tracking** — shows rate dates and download time, flags when refresh is pending

## Install

```sh
omarchy plugin add https://github.com/gunhan/keystroke-currency.git --enable
```

Or from a local checkout:

```sh
cp -r keystroke-currency ~/.config/omarchy/plugins/gunhan.keystroke-currency
omarchy plugin enable gunhan.keystroke-currency
```

The systemd timer is installed automatically on first load.

## Usage

Type in the Keystroke palette:

| Query | Result |
| --- | --- |
| `129usd` | 129 USD to TRY (or your preferred currency) |
| `100 usd to try` | 100 USD to TRY |
| `12,50 eur in tl` | 12.50 EUR to TRY |
| `$100 in eur` | 100 USD to EUR |
| `1000 gbp to usd` | 1000 GBP to USD |

Press `Enter` to copy the result.

## Settings

Open Keystroke Settings → Currency:

| Setting | Default | Description |
| --- | --- | --- |
| Currency target | Preferred | **Preferred** always uses the preferred currency. **Automatic** learns explicit targets you view or copy. |
| Preferred currency | TRY | Target for compact queries like `129usd`. Also the fallback for Automatic mode. |

## How it works

1. **Background refresh**: A systemd timer fires at 04:00 local time. It downloads all EUR-base rates from [Frankfurter](https://frankfurter.dev) and writes them to `~/.cache/keystroke/currency-rates.json`.
2. **Cache watch**: The provider watches the cache file. When it changes, the palette refreshes automatically.
3. **Cross-rate calculation**: `100 usd to try` is computed as `TRY.rate / USD.rate` from the EUR table. Each currency carries its own source date.
4. **Usage learning**: In Automatic mode, explicit targets (`to EUR`) earn a bounded usage count after a 1.2s dwell or activation.

## Files

| Path | Purpose |
| --- | --- |
| `~/.cache/keystroke/currency-rates.json` | EUR-base daily rate cache |
| `~/.local/state/keystroke/currency-usage.json` | Per-currency usage counts for Automatic mode |
| `~/.config/systemd/user/keystroke-currency.timer` | Daily refresh timer |

## Remove

```sh
systemctl --user disable --now keystroke-currency.timer
rm ~/.config/systemd/user/keystroke-currency.timer
rm ~/.config/systemd/user/keystroke-currency.service
systemctl --user daemon-reload
omarchy plugin remove gunhan.keystroke-currency
```

## Test

```sh
bin/test
```

Runs QML unit tests, Python cache tests, and manifest validation.

## License

MIT
