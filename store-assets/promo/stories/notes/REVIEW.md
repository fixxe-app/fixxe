# FIXXE story series: pre-client review

Checked all 10 PNGs at full size, at phone size (390 px wide; see `review/phone-en.png` and `phone-ru.png`), and in zoomed crops. I also checked the source captures behind each crop.

**Verdict:** the series looks like one campaign. The lockup, CTA block, palette and safe zone are all consistent, and every app crop is real. It isn't ready to send yet. There are 3 ad-policy problems, 1 claim that misleads, and several "proof" elements you can't read on a phone. All of them can be fixed in a day.

---

## 1. `mozg`: "Stop the mental math." / «Хватит ломать мозг.»

| | EN | RU |
|---|---|---|
| Thumb-stop | 7 | 7 |
| 1.5 s clarity | 6 | 6 |

**Fixes, in priority order**
1. **Separate the sub from the CTA.** "Type in any row. The rest is already done." sits at y≈1397, only 64 px above "Free · App Store…". The two lines are almost the same size and colour, so at phone size they merge into one grey block and the benefit line gets lost. Make the sub Manrope 700, 100 % white, about 40 px, and move it up so it sits about 30 px under the card. That leaves at least 90 px before the CTA. The other frames already have roughly this gap.
2. **Turn down the glyph storm at y=0–250.** The brightest chaos (the large "?" outline, "%", the gold "o/o") sits right where the avatar, "Sponsored" label and progress bar go. That adds clutter to the one spot nobody reads, and it fights the sponsor name. Fade that band to about 40 % and let the chaos peak at y≈380–820, behind and around the headline.
3. **The "÷ 0.92 ≈ ?" scribble matches nothing on screen.** 1 / 1.0961 = 0.912. Every other scribble uses numbers from the crop (24.90, 117.63), so this one sticks out to anyone who checks. Use "÷ 0.912 ≈ ?" (RU «÷ 0,912 ≈ ?»).
4. **Clear space around the last scribble.** The big gold "%" on the left and the grey "?" on the right overlap "and in dollars?!" / «а в рублях сколько?!». That scribble carries the most meaning, especially in RU. Move both glyphs about 60 px outward so the line reads cleanly.
5. Minor: the scribble strikes are gold over gold-tinted noise, so at 390 px "24.90 × 117.63" blurs into "24.90 × 1??.63". Make the strike 1–2 px thinner, or 70 % opacity, so the digits read first and then look crossed out.

**Do not touch:** the gold gradient headline (the best type in the series), the gold divider between chaos and calm at y≈826, and the 3-row crop. The crop is large, sharp and readable at phone size, and its numbers match the scribble. Keep the EN/RU change in the third row too (USD for "and in dollars?!", RUB for «а в рублях сколько?!»). That's a smart detail.

---

## 2. `stamp`: "They'll take their cut. Know it first." / «Обменник своё возьмёт. Посчитай заранее.»

| | EN | RU |
|---|---|---|
| Thumb-stop | 8 | 8 |
| 1.5 s clarity | 5 | 6 |

**Fixes, in priority order**
1. **Misleading claim on the stamp and the sub (fix before any review).** "FEE INCLUDED" / «С КОМИССИЕЙ» and "Every amount includes the fee" / «все суммы уже с комиссией» suggest the app knows the real fee. It doesn't. It applies a % the user types in. A reviewer or a user who feels misled can treat that as a misleading claim. Change to:
   EN sub: "Set your +1.5% once. Every amount includes it." Stamp bottom line: "YOUR FEE" (or just drop that line).
   RU sub: «Поставь свои +1,5% один раз — и все суммы сразу с ними.» Stamp: «ТВОЯ КОМИССИЯ».
2. **The stamp's bottom line collides with the UI text under it.** "INCLUDED" runs into "din.", and "Serbian Dinar" crosses "INCLUDED" / «КОМИССИЕЙ». In the RU version "din." lands inside «КОМИССИЕЙ». At 390 px this is noise. Either move the stamp about 40 px left and 30 px down so its text line sits on the empty left part of the rows, or knock the UI out to about 15 % under the stamp's text band. The "+1.5%" can keep overlapping (that's the realism). The small text line can't.
3. **The ad never shows the cut.** Nothing on screen shows the difference between mid-market and adjusted, so the "+1.5%" is only a decoration. Add a callout outside the card, next to the USD row: a small grey "109.61" struck through, then "→ 111.26". Take both numbers from one moment's capture (adjusted plus a matching unadjusted capture). This is an annotation, not fake UI, and it turns the frame from "a purple stamp" into "oh, that's what I lose."
4. **Rounding works against the message.** The capture uses whole numbers with round-up, so 100 × 1.1126 shows as **112** (not 111.26), and 2.8813 GEL as **289** (not 288.13). On a frame about precise fees, that looks like the app can't do arithmetic. Re-capture with `decimals 2` and `grouping 1`. That also fixes "11939". It's the only frame in the series without the "11 763"-style thousands spacing.
5. **EN headline: "They" refers to no one.** RU names the culprit (Обменник). EN doesn't. Use "Exchange booths take a cut. Know it first." It fits the same 2 lines and stays within the brief (it names no competitor and claims no "best rate").

**Do not touch:** the light paper background. It's the only light frame and the best feed interrupt in the set. Also keep the purple second headline line, the real "Adjusted rates" / «Курсы с поправкой» banner with % badges, the slight card tilt, and the stamp's ink texture and −9° angle. The RU headline is the most natural copy in the series.

---

## 3. `board`: "Dinar. Lari. Som. All on board." / «Динар, лари, сом — все на месте.»

| | EN | RU |
|---|---|---|
| Thumb-stop | 8 | 9 |
| 1.5 s clarity | 7 | 8 |

**Fixes, in priority order**
1. **Policy: remove "crypto" from the sub.** "300+ currencies · 150+ crypto · metals" / «…150+ криптовалют…». TikTok bans crypto-related ads in most markets. Meta's automated review flags crypto mentions under its crypto policy, which needs prior written permission. One word can get this frame rejected or shadow-limited, and it's the best frame in the set. Use "300+ currencies, even the rare ones · metals" / «300+ валют, даже редкие · металлы». If crypto has to stay, keep it out of the TikTok cut entirely.
2. **The proof strip is unreadable on a phone and leaves out the Som.** The two rows are scaled to about 40 %. At 390 px "11 763" is about 9 px high and the rate lines are about 4 px. Also, the headline promises the Som and the strip shows only RSD and GEL, even though the capture has a KGS row (9 585). Rebuild the strip as a full-width card under the board (x=64–1016) with 3 rows: RSD, GEL, KGS. Use the same scale as `mozg`'s crop and give the rows about 330 px of height by tightening the board's row pitch from about 68 px to 60 px.
3. **Drop "in the real app" / «в настоящем приложении».** It sounds defensive. It practically admits the board above is fake, and the RU wording is awkward. Use a single gold "100 EUR →" next to the strip, or "Live in FIXXE" / «Так в FIXXE».
4. **The half-flipped "T" in KZT looks like a broken render on a still image.** It's the last tile, which is exactly where the eye stops. Delete the mid-flip, or move it to an empty filler tile, where it reads as motion and not as a bug.
5. **The RU ghost header at the top says «ВЫЛЕТВЫЛЕТ» with no break.** It's out of the safe zone, but sloppy. Use one word, or put a gap tile between the repeats.
6. **Brand-safety note for the client, not a rejection risk.** In RU, Belgrade / Tbilisi / Bishkek / Dushanbe / Yerevan / Almaty under «ВЫЛЕТ» reads exactly as the 2022 relocation map. For a diaspora audience that's a strength (it's why this is the top performer). But the client should choose it on purpose, and should avoid running it into Russia-geo placements, where it can read as political.

**Do not touch:** the split-flap board itself (letters, empty trailing tiles, flag column, six identical green "ON BOARD" / «НА БОРТУ» pills; the repetition is the joke), the white-plus-yellow two-line headline, and the "All on board" pun. This is the series' signature image.

---

## 4. `bleed`: "Every zero fits." / «Все нули влезут.»

| | EN | RU |
|---|---|---|
| Thumb-stop | 5 | 5 |
| 1.5 s clarity | 7 | 6 |

**Fixes, in priority order**
1. **Policy: swap IRR for VND.** The Iranian flag and rial (an OFAC-sanctioned country) in a paid finance-adjacent ad is an avoidable review flag, and a brand-safety question for some advertisers. Your own capture `frames/bleed/cap-en.png` already has the fix: **VND ₫ 2 816 112 697 600**, "Vietnamese Dong", 1 EUR = 28161. That number is also better on its own terms. IRR's "211 484 000 000 000" ends in nine zeros because the rate has few significant digits, so it looks made up. VND's digits look real. Rebuild the background giant number from the VND amount ("2 816 112…"). Never use KPW, even though the brief allows it.
2. **RU sub reads as "your money shrinks."** «Длинные суммы уменьшаются» literally means "long amounts decrease". That's a bad line in a money app. Use «Длинные числа не обрезаются — просто становятся мельче.» or «Длинная сумма ужмётся, но влезет целиком.» EN has the same risk to a lesser degree. Use "Long numbers shrink to fit, never cut off."
3. **Make the giant number the hero, or drop it.** At about 18 % blue, mostly hidden behind the card, "211 48" reads as a texture, not a joke. Either push it to about 35–40 % and let one full line run across y≈650–880 with nothing on top of it (move the card down about 40 px), or drop it. A half measure doesn't stop the thumb.
4. **Delete the outlined "84 00" at y=1620–1870.** It sits entirely under the reply field and the Install button. It isn't decoration anyone sees, it adds clutter behind the platform CTA, and it confuses the story's bottom edge.
5. **Small row text.** The shrunk amount ("211 484 000 000 000") is about 30 px, about 11 px on a phone. That's acceptable for showing the shrink. But the gold outline plus side arrows look like a real UI focus state, competing with the blue one. Make the arrows bigger (they're the explanation) and the outline thinner (2 px, 60 %), so nobody reads it as app UI.

**Do not touch:** the headline (both languages are short, funny and accurate), and the honest, real shrink in the crop: the EUR row at full size and the long row visibly smaller. The capture really behaves this way (the app hides the name on long rows). Don't "fix" the missing currency name.

**Bigger question:** this is the weakest benefit in the set. Display overflow matters to VND, IDR or IRR users and to almost no one else. See the cut recommendation below.

---

## 5. `nothing`: "ADS / ACCOUNT / SMS → Just the number." / «РЕКЛАМА / РЕГИСТРАЦИЯ / СМС → Просто курс.»

| | EN | RU |
|---|---|---|
| Thumb-stop | 6 | 6 |
| 1.5 s clarity | 6 | 4 |

**Fixes, in priority order**
1. **RU: you can't read the struck words.** The brush is about 30 px thick with a dark halo (`feMorphology dilate r=3` flooded with #0B0F17) that cuts a further band out of each word. It also sits at different heights per word. On «РЕГИСТРАЦИЯ» it runs through the upper third, exactly through the bowls of Р and the middle bars of Е and Г, so at 390 px it reads as "PEIИCTPAЦИЯ". «РЕКЛАМА» loses its lower half. Fixes: (a) put every stroke at 50–55 % of cap height, (b) make it about 18 px thick, (c) set the halo dilate to 1 or remove it. EN has the same problem in milder form ("ACCOUNT" loses its middle).
2. **Hierarchy is backwards.** The crossed-out negatives are 150 px Unbounded 900. The payoff, "Just the number." / «Просто курс.», is 88 px. In 1.5 s the viewer takes in three negative words and only half-sees the answer. Bring the struck words down to about 110–120 px and the green line up to about 110 px (RU «Просто курс.» has room for 120). The struck words become the setup and the green line the punchline.
3. **"Free" appears twice.** The sub starts "Free." / «Бесплатно.» and the CTA line under it starts "Free · …" / «Бесплатно · …». Remove it from the sub. EN sub: "The only permission it asks for: internet." RU: «Из разрешений — только интернет.»
4. **The EN app strip is narrower than the RU one** (it ends at x≈946 vs 1016), so the EN text is visibly smaller. Match the RU width so both strips are x=64–1016.
5. **"110" for 100 EUR when the rate is 1.0962.** Round-up whole numbers again. On the end card for a "just the number" message, show "109.62" (re-capture with `decimals 2`). Otherwise anyone comparing with frame 2 sees 110 → 112 and works out a 1.8 % "cut", not 1.5 %.
6. Optional, and the client's call: EN "SMS" works much worse than RU «СМС». English-speaking users don't link SMS codes to converter apps the way RU users do (СМС-подтверждение). The client asked for it, so keep it in RU. For EN, "TRACKING" is a stronger and fully supported claim. Raise it with the client once and don't push.

**Do not touch:** the third word «СМС» in RU (client decision, and it lands well), the green glow on «Просто курс.», the real app strip with the header and the localised «Очистить», and the slightly larger closing CTA.

---

## Series decisions

**Best order for a multi-frame story (4 frames, about 5 s each):**
1. `mozg`: the universal pain and the strongest headline. It opens the sequence well.
2. `stamp`: the light frame breaks the dark rhythm right when attention dips, and it adds a second, money-related pain.
3. `board`: proof that the app covers *your* currency. The highest-intent frame.
4. `nothing`: the close. No ads, no account, CTA.

**Strongest single ad: `board`** (especially RU for the diaspora audience), once you fix the crypto line and the proof strip. It's the only frame that tells the viewer in under a second that this app is *for them*, and the split-flap board is the most thumb-stopping image in the set. Runner-up for broad EN targeting: `stamp`, once the "includes the fee" claim and the stamp collision are fixed.

**Cut: `bleed`** from the paid sequence. It carries the weakest benefit, the IRR policy risk, and the lowest thumb-stop. Keep a VND version for organic or "what's new in 1.69" posts to existing users. If the client insists it stays, it goes 4th, before the end card, and only after fixes 1–3.

## Top 3 series-wide issues
1. **Policy and claim landmines, each a one-line fix:** the IRR/Iranian flag (`bleed`), "150+ crypto" (`board`, which TikTok rejects outright and Meta flags), and "FEE INCLUDED / includes the fee" (`stamp`, which implies the app knows the real fee). Fix all three before anything goes to the client.
2. **The proof is unreadable at phone size, and the numbers look sloppy.** The board proof strip (about 9 px figures), the stamp's small text line, the struck RU words and every rate line (8–9 px) don't survive at 390 px. Number formatting is also inconsistent: "11939" vs "11 763", and whole-number round-up gives 112 for 111.26 and 110 for 109.62. For an app whose whole promise is the exact number, re-capture everything with `grouping 1, decimals 2`. Show fewer rows, bigger.
3. **The CTA URL works against the brand.** "telebimmer.com/fixxe" is the most saturated element in the lower third of every frame, and its domain doesn't match the product. To a cold viewer, "telebimmer" next to "FIXXE" looks like a different app, or a scam. In paid stories the platform's Install button does the conversion anyway. On frames 1–4, replace line 2 with "Search “FIXXE”" / «Найди FIXXE в магазине» (same style) and keep the URL only on the end card. Also remove the duplicate "Free" on `nothing` (see above).
