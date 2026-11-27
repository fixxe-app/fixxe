# FIXXE stories — production sheet (final decisions; overrides creative.md / marketer.md where they differ)

Read first: BRIEF.md (facts, bans, tools), then creative.md (section "0. Before you start",
your concept's section, "How the four read as one campaign", "Production notes").
Folder: ..

## Shared system (identical on all 5 frames — do not improvise here)
- Canvas 1080×1920, `html,body{width:1080px;height:1920px;margin:0;overflow:hidden} body{position:relative}`.
- Safe zone: all text/logo/CTA within y=250–1580. Below 1580 — background only.
- Fonts (Google Fonts, `display=block`): Unbounded 700/800/900 (headlines), Manrope 500/600/700/800
  (wordmark, subs, CTA), JetBrains Mono 700/800 (boards/figures), Caveat 700 (frame 1 scribbles only).
  Wait for `document.fonts.ready` before anything measures text.
- Background `--night #0B0F17` (frame 2 is the only light one: paper `#F3EFE7`).
- Lockup: icon (copy store-assets/icon-512.png into your
  subfolder and reference it relatively) 84×84 radius 20 at x=64,y=268; "FIXXE" Manrope 800 46px letter-spacing .22em,
  #81C784 (light frame #2E7D32), x=168 vertically centred on the icon; gold rule 120×4 #C9A55C at x=64,y=360.
- CTA block at x=64, y=1440–1560:
  line 1 Manrope 700 34px, 75% white (light: 70% ink):
    EN "Free · App Store · Google Play · Web"   RU «Бесплатно · App Store · Google Play · веб»
  line 2 Manrope 800 44px, #64B5F6 (light #1565C0), preceded by a small gold "→": telebimmer.com/fixxe
- Headline: left-aligned at x=64, width ≤ 952, max 2 lines (3 only if RU truly needs it), fit-to-width
  JS loop (shrink font-size until it fits) so EN and RU share one layout.
- Real app imagery only, in rounded cards (radius 32–48, soft shadow), never a fake phone frame. Crop out
  the status line (provider name) — start crops below it.
- Russian: address the viewer as «ты» throughout. Numbers in Russian copy use comma decimals
  («1,5%»), except inside app UI and the stamp, which show the app's own "+1.5%".
- Accents: gold #C9A55C/#E8C77A in small doses on every frame (rule, arrows, CTA arrow).

## Live data
Use `capture.sh` for every app crop you need (EN capture for the EN frame, `"lang":"ru"` for the RU
frame). Rates are live, so take the numbers you show in text from YOUR capture. Never write a number in the
frame that doesn't match the crop next to it.

## Output
Your own subfolder `frames/<id>/`: `<id>-en.html`, `<id>-ru.html` (or one HTML with ?lang= — but
render.sh takes a file path, so two files is simpler), captures you used, and `<id>-en.png`,
`<id>-ru.png` rendered with `render.sh`. Then LOOK at both PNGs (Read tool) at full size and fix:
clipped text, RU overflow, emoji/flags missing, fonts not loaded (fallback look), anything outside the
safe zone, unreadable contrast, provider names visible. Iterate until both are clean.
Do not touch files outside your subfolder (except reading). Do not edit capture.sh/render.sh.

## The five frames (copy is final; small wording tweaks only if layout forces them — say so)

### 1 `mozg` — chaos → calm (creative.md Concept 7)
- Headline (gold gradient + glow, the only gold headline in the series):
  RU «Хватит ломать мозг.»   EN "Stop the mental math."
- Chaos zone: typographic glyph storm + crossed-out Caveat scribbles (seeded RNG, same layout EN/RU).
  Scribbles RU: «24,90 × 117,6 = ???», «+1,5%… или 2?», «÷ 0,92 ≈ ?», «а в рублях сколько?!»
  EN: "24.90 × 117.6 = ???", "+1.5%… or 2?", "÷ 0.92 ≈ ?", "and in dollars?!"
  (RU scribble numbers must use the same base as the crop below: 24,90 EUR; take the RSD rate from your
  capture and write it in the first scribble instead of 117,6 if it differs.)
- Gold line, then real dark capture: currencies EUR, RSD, RUB, USD, 24.9 EUR typed
  (saved_code EUR, saved_amount 24.9, amount_memory 3, grouping 1).
- Sub: RU «Вводи сумму в любой строке — остальное уже посчитано.»  EN "Type in any row. The rest is already done."
- No character illustration (slot not needed now).

### 2 `stamp` — +1.5% (creative.md Concept 2; the light frame)
- Headline: RU «Обменник своё возьмёт. Посчитай заранее.»   EN "They'll take their cut. Know it first."
- Stamp "+1.5%" (purple #6A1B9A, ink texture, −9°, multiply) over a LIGHT capture with adjustment on:
  theme 1, currencies EUR, USD, RSD, GEL, TRY, GBP, saved EUR 100, adjust_pct 1.5, adjust_keep true,
  adjust_left_at "NOW". Keep the purple «Курсы с поправкой»/"Adjusted rates" banner in the crop.
- Line under the screen: RU «Поставь +1,5% один раз — и все суммы уже с комиссией.»
  EN "Set +1.5% once. Every amount includes the fee."

### 3 `board` — departures (creative.md Concept 3)
- Headline: RU «Динар, лари, сом — все на месте.»   EN "Dinar. Lari. Som. All on board."
- Board rows (city · flag · code · status pill): BELGRADE/БЕЛГРАД RSD, TBILISI/ТБИЛИСИ GEL,
  BISHKEK/БИШКЕК KGS, DUSHANBE/ДУШАНБЕ TJS, YEREVAN/ЕРЕВАН AMD, ALMATY/АЛМАТЫ KZT.
  Status: EN "ON BOARD" / RU «НА БОРТУ». Header strip: "DEPARTURES" / «ВЫЛЕТ».
- Proof strip: dark capture with currencies RSD, GEL, KGS, TJS (and EUR as base 100) — show 2–4 real rows.
- Sub: RU «300+ валют · 150+ криптовалют · металлы»   EN "300+ currencies · 150+ crypto · metals"

### 4 `bleed` — every zero fits (creative.md Concept 4; new in 1.69)
- Headline: RU «Все нули влезут.»   EN "Every zero fits."
- Giant background number bleeding off both edges (blue, ~18%), equal to a real amount from the capture.
- Dark capture: currencies EUR, KPW, IRR, VND, saved EUR 1000000000 (grouping 1). Verify in the capture
  that the long amounts are whole and visibly smaller (the 1.69 shrink). If the field doesn't shrink in a
  non-focused row, use whatever the real capture shows that is whole — never fake it; report what you saw.
- Sub: RU «Длинные суммы уменьшаются, а не обрезаются.»  EN "Long amounts shrink to fit, never cut off."

### 5 `nothing` — end card (creative.md Concept 6)
- Struck-through words: RU РЕКЛАМА / РЕГИСТРАЦИЯ / СЛЕЖКА   EN ADS / ACCOUNT / TRACKING
- Green unstruck line: RU «Просто курс.»   EN "Just the number."
- Small sub: RU «Бесплатно. Единственное разрешение — доступ в интернет.»
  EN "Free. The only permission it asks for is internet."
- Thin strip of the real dark app (header + 2 rows, below the status line) — capture it.
- Since this is the closing card, the CTA may be slightly larger than the shared size (keep its position).

## ROUND 2 — series-wide changes (after review; apply to every frame)
- CTA on frames 1–4 (mozg, stamp, board, bleed): no URL. Same position/style as before:
  line 1 (Manrope 700 34px, 75% white / 70% ink): EN "Free · App Store · Google Play · Web"  RU «Бесплатно · App Store · Google Play · веб»
  line 2 (Manrope 800 44px, blue, gold "→" before it): EN "Search “FIXXE”"   RU «Ищи «FIXXE» в магазине»
  The URL telebimmer.com/fixxe stays ONLY on the end card (nothing).
- Numbers: re-capture with "grouping":1 and "decimals":2 wherever an amount is shown, so every frame
  formats money the same way (thousands spaced, 2 decimals). Never show a round-up whole number next
  to a rate that contradicts it.
- App crops must be legible at phone size (the frame is seen ~390 px wide ⇒ divide sizes by 2.8):
  amounts ≥ ~50 px in the 1080 frame, rate lines ≥ ~26 px. Show fewer rows, bigger.
- Nothing important below y=1580; nothing bright in y=0–250 (avatar/"Sponsored" sit there).
- Banned words added: crypto/криптовалют(ы) anywhere; no Iranian or other sanctioned-country flags/currencies.
