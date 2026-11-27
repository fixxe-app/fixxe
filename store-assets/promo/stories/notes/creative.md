# FIXXE story ads: visual concepts

Canvas 1080×1920. Safe zone y=250–1580 (all text, logo and CTA stay inside it). The background and decorative graphics may run to the edges.
Every frame is built in HTML/CSS/SVG. Images come only from real FIXXE screens: the store screenshots, crops and zooms of them, or captures of the web app.

---

## 0. Before you start: what I found in the assets (read this first)

**Things the screenshots show that we must not**
- `1-main.png` / `5-dark.png`: the status line at the top reads **"Market rate · 14:50 · FXR-API"**, which names a rate provider. Every crop must start below it, at y ≥ 360 in original 1320×2868 pixels.
- `2-add-currency.png` / `4-sources.png`: the filter chips say **Coinbase, FXRates, er-api, ECB**. Do not use the area at y≈600–700 (original px). The coloured dots in the rows carry no names, so they are fine.
- `3-settings.png`: the "Rate source" row reads **FXRatesAPI**, and the screen shows "Version 1.68". Don't use this screenshot. If a settings view is ever needed, capture it from the web app and crop it.
- Shrink-to-fit arrived in 1.69 and the iOS screenshots are 1.68. The shrink frame therefore needs a capture from the current web build.

**Row map for `1-main.png` / `5-dark.png` (original px, card x=31–1289)**

| Row | y range | Shows |
|---|---|---|
| Header (FIXXE · compass · Clear) | 378–501 | wordmark in the UI |
| EUR (base, blue outline) | 523–732 | `1` |
| USD | 759–963 | `1.1` · 1 EUR = 1.0980 USD |
| RUB | 990–1194 | `91` |
| KPW | 1222–1426 | `989` |
| RSD | 1453–1658 | `118` · 1 EUR = 117.64 RSD |
| GEL | 1686–1890 | `2.9` · 1 EUR = 2.8471 GEL |
| TRY | 1918–2122 | `56` |
| CHF | 2150–2354 | `0.93` · 1 EUR = 0.923399 CHF |
| GBP | 2382–2586 | `0.84` |

The CHF row is real proof of "round up, never short": the rate is 0.923399, and the app shows **0.93**.

**App colours, from `web/styles.css`**
- blue `#1565C0` / dark `#64B5F6`
- wordmark green `#2E7D32` / dark `#81C784`
- adjusted purple `#6A1B9A` on light, `#CE93D8` on dark, with background `#EBD9F0` / `#3A2348`
- compass gold, sampled from the icon: `#C9A55C` (highlight `#E8C77A`, shadow `#8A6B2E`)
- icon background `#2B2F33`

**Ad palette (shared by all concepts)**
- `--night #0B0F17`: main dark background, close to the icon's charcoal but cooler
- `--card #1E1E1E`: same as the app's dark card
- `--paper #F3EFE7`: the only light background in the series
- `--gold #C9A55C` / `--gold-hi #E8C77A`
- `--green #81C784` on dark, `#2E7D32` on light
- `--blue #64B5F6` on dark, `#1565C0` on light
- `--purple #CE93D8` on dark, `#6A1B9A` on light
- `--amber #FFB547`: LED and flip-board figures only

**Fonts (Google Fonts; all four include Cyrillic)**
- **Unbounded** 700/800/900: headlines and stamps. It is wide and loud, the right "ad" voice.
- **Manrope** 500/700/800: wordmark, sub-lines, CTA.
- **JetBrains Mono** 700/800: board and flip-flap figures.
- **Caveat** 700: hand-written scribbles, Concept 7 only.
- Load with `&display=block`. Render with `--virtual-time-budget=8000` added to the Chrome command so fonts load before the screenshot.
- Fallback: `-apple-system, "SF Pro Display", system-ui`.
- Russian lines run 20–35% longer. Every headline box gets a fixed width and a small JS loop that lowers the font-size until the text fits in at most two lines. The ad itself "shrinks to fit", like the app.

---

## Concept 1: "MIDPOINT" (exchange-office board vs the app)

**Idea:** An exchange office shows two prices, BUY and SELL. FIXXE shows the one in the middle.

**Visual device:** A glowing amber split-flap board, as on an exchange-office window, with two big figures: BUY `116.14` | SELL `119.14`. A gold wedge or bracket drops from the gap between them onto a real FIXXE row reading `1 EUR = 117.64 RSD`, which is exactly the midpoint. The frame teaches what "mid-market" means without a word of jargon.

**Composition (1080×1920, dark `--night`)**
- 0–250: background only. A faint dotted LED-matrix texture (CSS `radial-gradient` 6px grid, 6% amber) fades from the top.
- 270–350: logo lockup (shared system, see below).
- 400–620: headline, two lines, Unbounded 800, 92px, white, left aligned at x=64, width 952.
- 680–1000: **the board.** A black slab at x=64–1016 with an 8px bezel in `#1A1A1A` and inner shadow.
  - Two columns of split-flap tiles in JetBrains Mono 800, 104px, amber `#FFB547` with a `0 0 24px` amber glow.
  - Each digit is a tile (64×110, `#151515`) with a 2px horizontal "flap seam" line through the middle.
  - Labels above the columns: "BUY" / "SELL" (RU: "ПОКУПКА" / "ПРОДАЖА"), Manrope 700, 30px, letter-spacing .2em, 60% white.
  - The row label "EUR → RSD" with a 🇪🇺 and a 🇷🇸 flag emoji sits at the left, 40px.
- 1000–1120: a gold SVG bracket (├──┬──┤ shape) spans from under BUY to under SELL. Its stem drops to a ▼ at the centre. Next to the stem, a small gold label in Manrope 700, 30px: "mid-market" / RU "середина".
- 1130–1360: **real app row.** Crop the RSD row from `5-dark.png` (x 31–1289, y 1453–1658) and scale it to 952 px wide (×0.757 → ~155 px tall, then ×1.35 for emphasis). Place it with a 2px gold outline and a soft gold glow; this replaces the app's blue base-row outline.
- 1440–1560: CTA block.
- 1580–1920: the board's amber glow fades out; no text.

**Typography:** headline Unbounded 800, 92/96; board JetBrains Mono 800, 104; labels Manrope 700, 30, tracked.

**Screenshot:** `5-dark.png`, RSD row only. This row's rate line, `1 EUR = 117.64 RSD`, is the hero. The board figures are illustrative and must average exactly to the app figure: (116.14 + 119.14) / 2 = 117.64. Mark them with a tiny "example" caption under the board, 22px, 40% white.

**Placeholder headline**
- EN: "Buy. Sell. And the rate in between."
- RU: "«Куплю», «продам» — и курс посередине."

**Why it stops the scroll (first 0.5 s):** A glowing amber board on a black phone screen reads instantly as "money street sign". Two numbers with one in the middle is a puzzle the eye solves without reading.

**Compliance:** It never says "better than the office". It shows where the mid-market rate sits.

---

## Concept 2: "THE STAMP" (+1.5%)

**Idea:** Your bank quietly adds a percent. FIXXE lets you stamp it on and see what you'll really pay.

**Visual device:** A giant purple rubber stamp, **"+1.5%"**, slammed at −9° across a real light-theme FIXXE screen in its adjusted state. Every amount on the screen is purple with the app's own `%` badges. The stamp has ink texture from an SVG `feTurbulence` + `feDisplacementMap` filter on a `mask`, giving rough edges and speckle. A double rounded-rect border makes it read as a stamp, not just text.

**Composition (light paper `--paper #F3EFE7`; the one light frame in the series)**
- 0–250: paper with a subtle fibre noise (SVG turbulence at 4% opacity).
- 270–350: logo lockup, light variant (wordmark `#2E7D32`).
- 390–560: headline, Unbounded 800, 84px, ink `#14121A`, two lines max.
- 600–1400: **phone screen.** A web-app capture in a frameless card (radius 48, shadow `0 40px 80px rgba(60,20,80,.18)`), 820 px wide, centred, rotated +2°, showing about 5 rows.
  - Rows: EUR base `100` (blue outline), then USD / RSD / GEL / TRY / GBP in purple with `%` badges.
  - The purple adjust banner at the top of the list is kept in the crop, because it is real UI and it is purple.
- 820–1130: **the stamp**, centred at about (560, 980), rotated −9°.
  - Text "+1.5%" in Unbounded 900, 260px, colour `#6A1B9A` at 88%, `mix-blend-mode: multiply` so the screen shows through like ink.
  - Border: two rounded rects, 10px and 4px strokes, 18px apart.
  - Grunge mask. It overhangs the screen edge on the right by ~60 px, which is what makes it feel physical.
- 1440–1560: CTA block, light variant.

**Typography:** headline Unbounded 800, 84; stamp Unbounded 900, 260. A small line under the screen: "Your fee, built into every amount", Manrope 600, 34, purple.

**Capture:** web app via `localStorage`:
- `fixe.theme="light"`
- `fixe.currencies=["EUR","USD","RSD","GEL","TRY","GBP"]`
- `fixe.adjust_pct=1.5`
- type 100 in EUR
- viewport 430×932 @3x

Crop out the status line if it shows a provider name. Before relying on the screenshot, check that the banner and badges render as described.

**Placeholder headline**
- EN: "Add the bank's 1.5%. See the real total."
- RU: "Добавьте 1,5% банка — и увидите реальную сумму."

**Why it stops the scroll:** A stamp is the most physical, violent gesture you can put on a screen, so it breaks the flat-UI pattern of every other app ad. The colour also matches what the app really does: a purple mark on adjusted amounts.

---

## Concept 3: "DEPARTURES" (the rare-currency flight board)

**Idea:** Going where most converters don't go? FIXXE's currency list covers it.

**Visual device:** A full-bleed airport departure board in yellow split-flap on black, with columns **DESTINATION | CURRENCY | STATUS**:
- BELGRADE · RSD
- TBILISI · GEL
- DUSHANBE · TJS
- BISHKEK · KGS
- MOSCOW · RUB
- PYONGYANG · KPW

Every STATUS cell reads **"ON BOARD"** in green (RU: «НА БОРТУ»). The board carries no exchange figures, so nothing needs to be "live".

**Composition (dark `--night`)**
- 0–250: the board header "DEPARTURES / ВЫЛЕТ" in amber, partly hidden under the progress bar on purpose. Only decorative chrome lives here.
- 270–350: logo lockup.
- 380–560: headline, Unbounded 800, 88px, white.
- 600–1260: **the board**, 6 rows × 100 px, x=40–1040.
  - Each character is a flap tile: JetBrains Mono 800, 54px, `#FFD54A` on `#141414`, 1px seam line, 4px gap.
  - Flag emoji at 56px, left of the city.
  - STATUS column: a green pill `#2E7D32` with white "ON BOARD", Manrope 800, 30px.
  - One row (Pyongyang/KPW) uses a half-flipped tile: its top half shows the previous letter, skewed with CSS `transform: perspective(300px) rotateX(-40deg)`. That frozen mid-flip moment says "live board".
- 1280–1400: real proof strip. Two app rows cropped from `5-dark.png`, GEL (y 1686–1890) and RSD (y 1453–1658), shown small (480 px wide each) side by side with radius 24, so the board is grounded in the actual app.
- 1440–1560: CTA block. Above it, a one-line sub in Manrope 700, 36: "300+ currencies · 150+ crypto · metals".

**Placeholder headline**
- EN: "Flying where others don't?"
- RU: "Летите туда, куда не летают конвертеры?"
- shorter RU option: "Даже динар. Даже сомони."

**Why it stops the scroll:** Everyone instantly recognises an airport board, and it triggers the traveller's "that's me" moment. Seeing your own odd destination (Belgrade, Tbilisi, Bishkek) listed is a personal hook. Yellow-on-black flap tiles are the highest-contrast thing in a story feed.

**Compliance:** "ON BOARD" only means the currency is supported in the app. No rate claims.

---

## Concept 4: "BLEED" (the number too big for the story)

**Idea:** A number so big it runs off the screen, except inside FIXXE, where it fits.

**Visual device:** Behind everything, one gigantic amount in Unbounded 900 at about 330px, cut off by both canvas edges, e.g. **989 000 000 000** KPW, in `#64B5F6` at 18% opacity so it reads as texture. In front sits a real FIXXE row where the same amount sits whole inside the card, shrunk to fit (new in 1.69). A blue "squeeze" bracket (→ ←) shows the number pressed into the card.

**Composition (dark `--night`)**
- 0–1920: a background band at y 700–1100 holds the giant number, left-aligned at x=−120 so it bleeds both ways. Use a second line underneath for rhythm.
- 270–350: logo lockup.
- 380–600: headline, Unbounded 800, 96px, white; one key word in blue.
- 760–1160: **real row(s)** from a web capture with dark theme:
  - `fixe.currencies=["EUR","KPW","IRR","VND"]`
  - type `1000000000` into EUR, so KPW/IRR/VND turn into long amounts and shrink
  - Crop 2–3 rows, scaled to 952 px wide, with a 3px blue `#64B5F6` outline on the longest row.
- 1180–1260: blue SVG arrows ⟶|card|⟵ pointing at the long amount, with a small caption "fits, never cut off", Manrope 700, 32.
- 1440–1560: CTA block.

**Placeholder headline**
- EN: "Big numbers. No cut-offs."
- RU: "Большие суммы. Без обрезанных нулей."

**Why it stops the scroll:** A number too big for the screen is a visual glitch, and broken-looking frames get stopped on. The resolution, a neat card holding the same amount, pays the glitch off within a second.

**Note:** Use real captured values, not invented ones. Run this frame only after confirming the web build shows the 1.69 shrink behaviour.

---

## Concept 5: "LOUPE" (0.923399 → 0.93)

**Idea:** We round up, so the money you count on is always enough.

**Visual device:** A jeweller's loupe or magnifier, drawn in SVG: a thick gold ring with a glass radial-gradient highlight and a short handle. It hovers over the real CHF row from the screenshot. Inside the lens, the row is zoomed ×2.6, and the rate line `1 EUR = 0.923399 CHF` sits next to the shown amount **0.93**. Outside the lens, a hand-drawn gold arrow from `0.923399` up to `0.93` carries the tag "↑ rounded up".

**Composition (dark `--night`)**
- 270–350: logo lockup.
- 380–620: headline, Unbounded 800, 90px.
- 700–1000: CHF row crop from `5-dark.png` (x 31–1289, y 2150–2354), shown at 952 px wide, dimmed to 50%.
- 640–1200: the loupe, a 460 px circle centred near (700, 900). Inside, the same crop at ×2.6 via CSS `background-size` / `background-position`, clipped by `border-radius: 50%`. Ring: 22px gold `#C9A55C` → `#8A6B2E` conic gradient.
- 1220–1380: a typographic proof line in JetBrains Mono 700, 56: `0.923399 → 0.93`, with the arrow in gold. Below it, in Manrope 600, 34, 70% white: "Never more than 2% off · never less than the real amount".
- 1440–1560: CTA.

**Placeholder headline**
- EN: "Rounded up. Never short."
- RU: "Округляем вверх. Денег хватит."

**Why it stops the scroll:** The magnifier is a universal "look closer" gesture, and its gold glint against black matches the brand compass. The six decimals under the lens look precise, which makes people trust the claim.

---

## Concept 6: "CROSSED OUT" (no ads, no account, no tracking)

**Idea:** Everything other apps ask from you, crossed out. FIXXE needs one thing: internet.

**Visual device:** A stack of huge words in Unbounded 900, each struck through by a thick hand-drawn gold SVG stroke (`stroke-linecap: round`, slight wobble):
- ADS
- ACCOUNT
- TRACKING
- SIGN-UP

The last line is un-struck, in green `#81C784`: **"Internet. That's it."**

**Composition (dark `--night`)**
- 270–350: logo lockup.
- 400–1100: four struck words, Unbounded 900 at 150px (fit-to-width), white at 92%, line-height 170px. The strokes overshoot the words by 20–40px on each side and tilt slightly, each at a different angle (−3°, 2°, −1°, 4°).
- 1130–1250: green line, Unbounded 800, 72px.
- 1270–1400: a thin strip of the real dark app (header + EUR + USD rows, crop y 378–963) at 50% scale, rounded 32. It shows the clean UI with no banners.
- 1440–1560: CTA.

**Placeholder headline (the words are the headline)**
- EN: "ADS / ACCOUNT / TRACKING → Internet. That's it."
- RU: "РЕКЛАМА / АККАУНТ / СЛЕЖКА → Нужен только интернет."

**Why it stops the scroll:** Strike-through words are an instant "no", and massive type with gold slashes looks like a manifesto, not an app ad. It works well with privacy-tired audiences, especially Telegram.

---

## Concept 7: "ХВАТИТ ЛОМАТЬ МОЗГ" (chaos → calm)
*Added after the client's reference ad; see the "Client reference" section below.*

**Idea:** The top half is the mess in your head when you convert prices abroad. The bottom half is the same question already answered by FIXXE. A hard gold line separates the two.

**Visual device:** Chaos is rendered typographically, so no character or illustration is needed.
- Scattered math glyphs `÷ % × ? = ≈` fly across the upper half: Unbounded 900 at 80–260px, random rotation −35°…35°, opacity 10–60%. Most are white; a few are gold `#C9A55C`.
- Placement uses a seeded JS pseudo-random generator, so every render is identical and en/ru match.
- Between the glyphs are handwritten "pocket calculations" in **Caveat** 700 (Google Font, has Cyrillic), 56–72px, 85% white, slightly rotated. Each is crossed out with a scribbled gold SVG stroke:
  - `24,90 × 117,6 = ???`
  - `+1,5%… или 2?`
  - `÷ 0,92 ≈ ?`
  - `а в рублях сколько?!`
- The chaos stops dead at a single 3px gold horizontal line. Glyphs that cross it are clipped (`overflow:hidden` on the chaos layer), as if they hit glass.
- Below the line: calm, empty space and one real app crop that answers the scribble's question.
- No banknotes, coins or money rain: they read as gambling and scam ads and get flagged.

**Composition (dark `--night`; slightly warmer above the line, a radial `#1A1622` glow)**
- 0–250: the chaos layer starts at y=0, so glyphs drift under the progress bar (decoration only).
- 270–350: logo lockup (shared system).
- 380–580: **headline**, Unbounded 900, 104px.
  - Colour: gold gradient `linear-gradient(180deg, #F3DC9A, #C9A55C 55%, #8A6B2E)` via `background-clip: text`.
  - Effect: `0 0 40px rgba(232,199,122,.35)` glow.
  - This is the one place in the campaign where the reference ad's gold-glow lettering is used, kept to a single line or two.
- 600–960: chaos zone (glyphs + four crossed-out scribbles).
- 970: the gold line, x=64–1016, 3px, with a soft glow.
- 1010–1330: **real app crop**, dark theme, rows EUR `24.90` (base, blue outline) → RSD `2 929` → RUB → USD, 952px wide, radius 40. The crop answers the scribble `24,90 × 117,6 = ???`.
- 1340–1400: sub-line, Manrope 600, 34px, 75% white:
  - EN: "Type in any row. The rest are already done."
  - RU: «Вводите в любой строке — остальное уже посчитано».
- 1440–1560: CTA block.

**Optional character slot (client illustration)**
- Box x=600–1040, y=560–960 (440×400), bottom-anchored to the gold line, as if the character stands on it.
- Accepts a transparent PNG/WebP of the client's own illustration, e.g. a stressed traveller holding his head. Requirements: no banknotes in hand and no fake phone UI.
- Build it as a flag: `<body class="has-hero">` shows the image and drops the glyphs that would sit behind it. Without the class, those glyphs and a fifth scribble fill the space.
- The frame is designed to work, and is the default, without the illustration.

**Capture:** web app via `localStorage`:
- `fixe.theme="dark"`
- `fixe.lang="ru"` for the ru frame, `"en"` for the en frame
- `fixe.currencies=["EUR","RSD","RUB","USD"]`
- type 24.90 in EUR

Crop below the status line. Use the real figures from the capture. The `2 929` above is only an estimate from the screenshot rate 117.64.

**Placeholder headline (pain-first, in the user's own voice)**
- RU: «Хватит ломать мозг.» (from the client's reference; a period, not an exclamation mark, because the calm half below is the payoff)
- EN: "Stop doing currency math in your head." Shorter: "Stop the mental math."

**Why it stops the scroll:** The upper half is visual noise that looks like your own head at a shop till abroad. The eye falls down the frame until the gold line, where everything goes quiet. That before/after happens inside one still frame. The gold headline matches the compass icon.

**Compliance:** Nothing in the frame claims "best" or "#1". The only app UI is a real capture, and there is no money imagery.

### Bench (alternates if one above fails review)
- **Torn tag:** one paper price tag torn diagonally; the top half reads € 24.90 and the bottom half 2 929 RSD. Shows "type in any row, every currency updates".
- **Zero bars:** a big grey signal-strength glyph drawn in SVG (not Apple UI) over the dark screen, with "No signal. Still converts." Covers the offline feature.
- **Half/half:** the light and dark screenshots spliced on a diagonal. Pretty but weak as a hook; use only as a feature-tile background.

---

## Client reference (images/3.jpg): what we take and what we don't

The reference is a horizontal 16:9 banner: a cartoon traveller tearing his hair out among flying banknotes and `% ÷ ?` signs, the gold headline «ХВАТИТ ЛОМАТЬ МОЗГ!», a glowing phone with invented UI, and «Самое лучшее в мире приложение для валют!».

**We take:**
1. **A pain-first headline in the user's own voice.** «Хватит ломать мозг» becomes the headline of the new Concept 7. The same voice gives alternative RU/EN headlines for the other frames:
   - STAMP: «Сколько спишут на самом деле?» / "What will the bank actually take?"
   - MIDPOINT: «Какой из двух курсов настоящий?» / "Which of these two is the real rate?"
   - DEPARTURES: «А мою валюту он знает?» / "Does it even have my currency?"
2. **Chaos → calm (before/after) in one frame.** This is the core of Concept 7. The chaos is drawn typographically instead of with a character: scattered `÷ % × ?` glyphs and crossed-out hand-written sums. The real app answers below a gold line.
3. **Gold accents.** These match our compass icon. They were already the campaign's binding colour (rule, arrows, CTA arrow). The reference's gold-gradient glowing lettering is used once, on Concept 7's headline, and nowhere else, so it stays special.
4. **Energy.** We get it from scale and density: giant glyphs, a stamp at −9°, a number bleeding off the canvas. Clutter is avoided: every frame keeps one idea and a large calm area around the CTA.

**We don't take:**
- "Best in the world": the brief bans superlatives.
- The invented phone UI: we use only real screenshots and captures.
- Money rain, banknotes and casino sparkle: they read as a scam or gambling ad, hurt trust and get flagged by ad review.
- The clutter and the 16:9 format.

**Character illustration:** We can't draw a cartoon person in HTML, so only Concept 7 has an **optional** slot for the client's own illustration (box x=600–1040, y=560–960, transparent PNG, standing on the gold line, no banknotes in hand). The frame is designed and rendered complete without it.

## Top 4 for production

1. **ХВАТИТ ЛОМАТЬ МОЗГ (chaos → calm)**: a pain-first hook in the user's own voice. Instant before/after, gold glow, best for RU audiences. It is the series opener.
2. **THE STAMP**: the most original hook; it shows a feature most converters don't have and uses the app's own purple.
3. **MIDPOINT**: explains the core value (mid-market rate) visually and honestly.
4. **DEPARTURES**: the broadest emotional hook (travellers, expats, rare currencies). Strongest for RU audiences: RSD, GEL, TJS, KGS, RUB.

Reserve:
- **BLEED** (first reserve): the best pick for a "what's new in 1.69" push, once the web capture confirms the shrink behaviour.
- **LOUPE**: rounding.
- **CROSSED OUT**: for privacy-heavy channels like Telegram.

Concept 7 replaced BLEED in the top 4 for two reasons. Its pain-first hook speaks to a wider audience than a feature demo. It also already carries the "type in any row" message.

### How the four read as one campaign

**1. Fixed lockup (identical position on every frame)**
- Icon `icon-512.png` at 84×84, radius 20, at x=64, y=268.
- "FIXXE" in Manrope 800, 46px, letter-spacing .22em, green (`#81C784` dark / `#2E7D32` light), baseline-centred with the icon at x=168.
- A 120×4 gold rule `#C9A55C` under the wordmark at y=360. This gold hairline is the campaign's signature.

**2. Fixed CTA block (y=1440–1560, x=64)**
- Line 1: "Free · App Store · Google Play · Web", Manrope 700, 34px, 75% white (light frame: 70% ink). RU: «Бесплатно · App Store · Google Play · веб».
- Line 2: `telebimmer.com/fixxe`, Manrope 800, 44px, blue `#64B5F6` (light frame: `#1565C0`), with a small gold `→` before it.
- No badges and no fake buttons. Everything below y=1580 is background only, because the link sticker sits there.

**3. One hero accent per frame on a shared base**
- Base: `--night #0B0F17` and white Unbounded headlines, left aligned at x=64.
- Per-frame accent:
  - ХВАТИТ ЛОМАТЬ МОЗГ: gold, including the gold-gradient headline used only here
  - MIDPOINT: amber `#FFB547`
  - STAMP: purple `#6A1B9A`
  - DEPARTURES: flap yellow `#FFD54A` + green "ON BOARD"
  - (BLEED, if used: blue `#64B5F6`)
- Gold appears on every frame in small doses: the rule, the arrow or bracket, and the CTA arrow. It ties everything to the compass icon.
- THE STAMP is the single light (paper) frame. In a sequence it acts as the "flash" that resets attention.

**4. Same grammar in every frame**
- Headline top-left, at most two lines, at most 7 words.
- One big non-UI object in the middle: glyph storm, board, stamp or flight board.
- One real app crop as proof.
- CTA at the bottom.
- Real screenshots always sit in rounded cards (radius 32–48) with the same soft shadow, never in a fake phone frame.

**5. Order when run as a 4-card story sequence**
ХВАТИТ ЛОМАТЬ МОЗГ (the pain, then relief) → MIDPOINT (which rate is real) → THE STAMP (your bank's cut, made visible) → DEPARTURES (it covers your trip, plus CTA).
Each card also works alone.

All headlines should be written in the user's own voice: the question or complaint they actually have, never a superlative about the app.

### Production notes
- Load fonts with `display=block`. Render with `--virtual-time-budget=8000` and wait on `document.fonts.ready` before the screenshot.
- Flag emoji render with Apple Color Emoji in headless Chrome on macOS. Check them in the PNG, because they are the only non-font glyphs.
- Every number shown inside an app crop must come from the real screenshot or a fresh web capture.
- Illustrative numbers (the MIDPOINT board) carry a small "example" / «пример» caption and must agree mathematically with the app crop.
- Never let "FXR-API", "FXRatesAPI", or the chip row of `2-add-currency.png` / `4-sources.png` into a frame.
