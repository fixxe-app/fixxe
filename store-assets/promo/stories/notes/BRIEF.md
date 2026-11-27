# FIXXE — vertical story ads (Instagram / TikTok / Telegram stories)

Goal: a set of vertical story images that stop the thumb and make people want to
install and try FIXXE today. Not a store screenshot with bullets — an ad.

## Product (only these facts may be claimed)
FIXXE — currency converter / currency calculator. Free. iPhone, iPad, Mac (Apple silicon),
Android, and web app (installable to home screen).
- Live mid-market rates (the neutral midpoint, not bank spreads). Main sources update about
  once a minute; 5 sources with automatic fallback — if one is down, the next one is used.
  (Do NOT name Coinbase / Wise / other providers in ads, no third-party logos.)
- Works offline: last rates kept on device; warns plainly if rates are older than a day.
- Type in any row — every other currency updates instantly. Dynamic base: no switching.
- Smart rounding: never distorts an amount by more than 2% (0.94 CHF never becomes "1");
  can round UP so the shown amount is never less than the real one — "the money is always enough".
- Rate adjustment: add your own % (bank fee, exchange-office margin, e.g. +1.5%) and every
  amount shows the real result at once; adjusted figures are marked (purple, % badge);
  auto-resets after 4 h unless kept on.
- Remembers your amount after closing the app (12 h by default; 24 h / always / while open).
- Long amounts shrink to fit instead of being cut off (new in 1.69).
- 300+ currencies with flags, incl. ones converters often skip (Serbian dinar, Georgian lari,
  Tajik somoni, Kyrgyz som, Russian ruble, North Korean won…), 150+ crypto, precious metals.
- No ads. No accounts. No tracking. The only permission is internet access.
- 40 languages incl. right-to-left. Light and dark theme.
- Where: App Store, Google Play, and web: telebimmer.com/fixxe  (landing with all install
  options: telebimmer.com/fixxe/about/#install)

## Must NOT
- Claim "real-time trading quotes", "best rate", "beats your bank", "most accurate", "#1".
  Rates are mid-market reference values.
- Name or show competitors (XE, Revolut, Google, Wise…) or rate providers; no store badges
  artwork (write "App Store · Google Play" as text instead).
- Invent UI the app does not have. Use the real screenshots, or crops/zooms of them, or
  screenshots captured from the real web app (see below).
- Mention any developer/person names or GitHub accounts.

## Brand
- Icon: gold compass on dark (store-assets/icon-512.png). Wordmark "FIXXE" in green
  (#2E7D32 light / #81C784 dark), letter-spaced.
- Brand blue #1565C0 (dark theme #64B5F6). Adjusted-rate purple (see app). App font: system
  (SF Pro on iPhone). Previous story (store-assets/promo/story-en.png) is a calm "store
  screenshot with bullets" — we want something far more thumb-stopping than that.

## Assets (repo root: (repo root))
- store-assets/screenshots-ios/1-main.png (light), 5-dark.png (dark), 6-dark-ru.png (dark, Russian UI),
  2-add-currency.png, 3-settings.png, 4-sources.png — 1320×2868 iPhone screenshots.
- store-assets/screenshots/ — Android 1080-wide screenshots.
- store-assets/icon-512.png, web/icons/
- The web app (web/index.html) is the same app: it can be served locally
  (`python3 -m http.server PORT --directory (repo root)`, open
  /web/) and captured with headless Chrome at phone size to get a specific state
  (e.g. an amount typed, rate adjustment on, Russian UI). Settings live in localStorage
  keys `fixe.<name>` (JSON): currencies (array of codes), lang, theme, adjust_pct, grouping…

## Format
- 1080×1920 PNG. Safe zone: keep all text, logos and CTA between y=250 and y=1580
  (top is covered by the story progress bar/avatar, bottom by the reply field / link sticker).
- Readable at a glance in ~1.5 s: one idea per frame, big type, high contrast.
- Two languages per concept: English (en) and Russian (ru). Russian copy must read natural,
  not translated.
- Render: HTML → PNG via headless Chrome:
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless --disable-gpu
  --hide-scrollbars --force-device-scale-factor=1 --window-size=1080,1920
  --screenshot=OUT.png file:///…/frame.html

## Tools (ready, use them — do not write your own)
- `stories/capture.sh OUT.png '<json>' [w=430] [h=932]` — real FIXXE web app screenshot in a given
  state, live rates, output (w×3)×(h×3) = 1290×2796 by default. JSON keys (→ localStorage):
  currencies ["EUR","RSD",…]; theme 1 light / 2 dark; lang "ru"/"en"; saved_code "EUR" +
  saved_amount 250 + amount_memory 3 → that amount is typed in; adjust_pct 1.5 + adjust_keep true
  + adjust_left_at "NOW" → rate adjustment on (purple amounts, % badges, purple banner);
  grouping 1 → "29 842" with spaces; decimals 0..3; round_up true/false.
  Example already captured: stories/captures/adj-ru-dark.png (RU, dark, 250 EUR, +1.5%).
  IMPORTANT: the app's top status line names the live rate provider (e.g. "Coinbase") — crop it
  out of every ad (start crops below it, e.g. from y≈130 of 932 CSS px / y≈390 px of the 1290-wide capture).
- `stories/render.sh frame.html out.png` — HTML frame → exactly 1080×1920 PNG (handles headless
  Chrome's viewport quirks). In the HTML: html,body{width:1080px;height:1920px;margin:0;overflow:hidden} body{position:relative} — position absolutely inside body (the browser viewport itself is taller than 1920).
  Reference images by relative path from the HTML file.
