# Prices — macOS Menu Bar App (Claude Code Project)

A lightweight macOS menu bar app that shows live prices for crypto and stocks. It sits in your menu bar and displays a panel with current prices, percentage changes, a P/E ratio, and a GBP portfolio value. I concentrated on a clear specification including edge case behaviour (like reduced API call frequency when closed). Claude Code, in the terminal, created the Swift code.

![Price panel](images/Screenshot%202026-04-28%20at%2021.04.53.png)

---

## Features

- **Tracks crypto and stocks** — works with any Yahoo Finance ticker: `BTC-USD`, `ETH-USD`, US stocks like `NVDA`, and UK LSE stocks like `RR.L`
- **Six columns per asset:**
  | Column | What it shows |
  |--------|--------------|
  | Price | Current price in native currency |
  | 1h % | % change over the last 60 minutes |
  | 24h % | % change vs the previous session's close |
  | 1y % | % change vs the price one year ago |
  | P/E | Price-to-earnings ratio (stocks only; requires Alpha Vantage key) |
  | Val | Portfolio value in GBP — price × qty × (1 − tax rate) |
- **Market-aware 1h column** — shows `CLOSED` for stocks when the exchange is shut; a yellow `%` means the market has been open less than one hour
- **Smart refresh cadence** — refreshes every 30 seconds while the panel is open; drops to every 10 minutes in the background to avoid rate limiting
- **No Dock icon** — lives entirely in the menu bar
- **Yahoo Finance** as the primary data source; **Alpha Vantage** for P/E data and as a fallback when Yahoo throttles

---

## Screenshots

**Price panel**

![Price panel showing crypto and stock prices](images/Screenshot%202026-04-28%20at%2021.04.53.png)

**Settings**

![Settings window showing tracked items with quantity and tax fields](images/Screenshot%202026-04-28%20at%2021.05.24.png)

---

## Requirements

- macOS 26 (Tahoe) or later
- [Xcode 26](https://developer.apple.com/xcode/) / Swift 6.2 toolchain (to build from source)

---

## Build and Install

**1. Build a release binary**

```bash
cd prices_menu_bar_macos
swift build -c release
```

**2. Create the app bundle**

```bash
APP=Prices.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/PricesMenuBar "$APP/Contents/MacOS/PricesMenuBar"
cp Sources/PricesMenuBar/Resources/Info.plist "$APP/Contents/Info.plist"
codesign --deep --force --sign - "$APP"
```

**3. Move to Applications**

Drag `Prices.app` to your `/Applications` folder, or:

```bash
cp -R Prices.app /Applications/
```

**4. First launch**

Because the app isn't signed with an Apple developer certificate, macOS Gatekeeper will block it on the first open. Right-click `Prices.app` in Finder, choose **Open**, then confirm. You only need to do this once.

**5. Launch at login (optional)**

Go to **System Settings → General → Login Items** and add `Prices.app`.

---

## Settings

Open Settings by clicking the **⚙** icon in the panel toolbar.

- **Alpha Vantage API Key** — required to show P/E ratios; also used as a fallback when Yahoo Finance throttles. Get a free key at [alphavantage.co](https://www.alphavantage.co). Free tier supports 25 requests/day.
- **Add Item** — search for any ticker by name or symbol (powered by Yahoo Finance search)
- **Qty** — number of units you hold; used to calculate the Val column
- **Tax %** — a tax rate applied to the Val column (e.g. 24 for CGT). Val = price × qty × (1 − tax / 100)

---

## Column reference

| Indicator | Meaning |
|-----------|---------|
| `CLOSED` in the 1h column | The exchange is not currently in its regular trading session |
| Yellow `%` in the 1h column | The market has been open less than 1 hour; the figure compares to the previous session's close rather than a true 60-minute move |
| `—` in P/E | Crypto, or no EPS data available from Alpha Vantage for that stock |

---

## Data sources

- **[Yahoo Finance](https://finance.yahoo.com)** — primary source for real-time prices, intraday bars, and historical data. Uses the unofficial chart API; no key required.
- **[Alpha Vantage](https://www.alphavantage.co)** — used to fetch trailing 12-month EPS for P/E calculation, and as a fallback if Yahoo Finance rate-limits. Requires a free API key. Note: Alpha Vantage does not provide 1h change data, so that column shows `—` when the fallback is active.
