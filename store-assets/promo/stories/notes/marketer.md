# FIXXE story ads: what to say, and to whom

The old story fails for one reason: it opens with the product ("335 currencies") and ends with four bullets. A story gets about 1.5 seconds. Frame 1 has to name a moment the viewer recognises, show one real screen that solves it, and give one CTA. Each concept below is built around one moment.

## Asset hygiene (read before cropping)
- **Provider names show up in the real screenshots.** The main-screen status line reads "Market rate · 14:50 · **FXR-API**", Settings has a "Rate source: **FXRatesAPI**" row, and screen `4-sources.png` shows Coinbase / FXRates / ECB chips. Crop below the status line, or capture from the web app and crop. Don't use `4-sources.png` in ads at all.
- Settings shows "Version 1.68", which predates shrink-to-fit (1.69). Crop it out.
- The old story says "3 sources". The brief now says 5 sources with fallback, so don't reuse that line.
- Every number in the copy (11 764 RSD, €86.28, …) must come from the actual capture used in that frame. The numbers below are placeholders that show the shape.
- Russian frames use the Russian UI (`6-dark-ru.png` or the web app with `fixe.lang="ru"`). Real RU strings: «Поправка к курсу», «Курсы с поправкой», «С поправкой», «Рыночный курс», «Добавить валюту», «Вверх».
- Layout: hook at y≈260–620 in huge type, real screen crop in the middle, CTA line at y≈1440–1580. Nothing important below 1580.

---

## C1 · "The fee you don't see" (exchange office / card abroad)
- **Who & when:** a tourist or relocant looking at a price tag abroad, or standing at an exchange kiosk, who knows the bank or kiosk takes something but not how much it adds up to. Also anyone paying abroad with a card that charges a 1–3% FX fee.
- **Insight:** a converter shows the clean mid-market number. You never get that number. The gap is the fee, and right now you work it out in your head, badly.
- **Hook:** EN **"Add their cut. See your number."** · RU **«Обменник своё возьмёт. Посчитай заранее.»**
- **Subhead:** EN "Set +1.5% once. Every amount shows what it really costs." · RU «Поставь +1.5% один раз — и все суммы уже с комиссией.»
- **CTA:** EN "Get FIXXE before your next exchange" · RU «Скачай FIXXE до следующего обменника»
- **Proof screen:** rate adjustment **+1.5% on**, adjusted amounts in **purple** with the **% badge**, and the "Adjusted rates" / «Курсы с поправкой» banner visible. Strongest version: two real states of the same row stacked. Price 10 000 RSD → EUR at mid-market (black), then the same row with +1.5% (purple). Both are real app states, nothing invented.
- **Why it works:** it's the only concept that shows something a plain converter can't, and it hits the moment of highest intent, when money is about to change hands. Purple next to black reads as before/after in under a second.
- **Risk check:** don't say kiosks or banks "rip you off", and don't claim "best rate" or "beats your bank". We only say the user adds their own % and sees the result. The purple marking shows these are adjusted figures, not mid-market. Don't name any card or bank. ✅

## C2 · "Your currency isn't 'Other'" (relocants & expats)
- **Who & when:** people who have moved to Belgrade, Tbilisi, Bishkek, Dushanbe or Yerevan, plus their families back home. Every day they deal with rent in dinars, salary in euros and transfers home in rubles, and their currency is often missing or buried in converters. This is a strong Russian-speaking segment with cheap reach.
- **Insight:** "This was made for people like me." Seeing your own flag at the top of an ad stops the scroll better than any feature.
- **Hook:** EN **"Dinar. Lari. Som. All here."** · RU **«Динар, лари, сом — все на месте.»**
- **Subhead:** EN "300+ currencies with flags, including the ones converters often skip." · RU «Больше 300 валют с флагами — и те, которых обычно нет.»
- **CTA:** EN "Find your currency in FIXXE" · RU «Найди свою валюту в FIXXE»
- **Proof screen:** the main list with **RSD and GEL flags** (real, in `1-main` / `6-dark-ru`). For KGS/TJS, capture the web app with `fixe.currencies=["EUR","RUB","RSD","GEL","KGS","TJS"]`. Crop tight on the flag rows.
- **Why it works:** geo-targeted versions (lead with RSD in Serbia, GEL in Georgia, KGS in Kyrgyzstan) make it feel personal. Hyper-specific creative is usually the cheapest install source for utility apps.
- **Risk check:** "ones converters often skip" is a fact from the brief, and we name no converter. Don't write "the only app with…". ✅

## C3 · "Landed. No signal." (offline, install before you fly)
- **Who & when:** someone who has just landed with no local SIM and roaming off, while a taxi driver or market seller quotes a price. Also the evening before a trip, which is when the ad should catch them.
- **Insight:** your converter fails at exactly the moment you need it, because it needs internet.
- **Hook:** EN **"Landed. No signal. Still converts."** · RU **«Прилетел без связи? Курс уже в телефоне.»**
- **Subhead:** EN "The last rates stay on your phone. It tells you if they're over a day old." · RU «Последние курсы хранятся в телефоне. Если им больше суток — честно предупредит.»
- **CTA:** EN "Install before you fly" · RU «Поставь до вылета»
- **Proof screen:** the web app or phone in airplane mode, with the real status line **"Offline · rates from …"** visible above the currency rows. Optionally put a large real airplane-mode toggle next to the crop. The status line itself must stay real.
- **Why it works:** the CTA is tied to a time ("before you fly"), so a passive scroller has a reason to install now. That's the one thing utility ads usually lack.
- **Risk check:** never suggest the rates are live while offline. The subhead says they're the last saved rates and that the app warns about stale ones. ✅

## C4 · "No 'from'. No 'to'." (type in any row, bill splitting)
- **Who & when:** a group dinner abroad. The bill is in lari, one friend thinks in euros, another in rubles, a third in dollars. Or a freelancer quoting one price to clients in three countries.
- **Insight:** the from/to/swap pattern is the daily irritation of every converter. People think in different currencies at the same time.
- **Hook:** EN **"No 'from'. No 'to'. Just type."** · RU **«Никаких «из» и «в». Просто вводи.»**
- **Subhead:** EN "Type in any row. Every other currency updates instantly." · RU «Вводишь сумму в любой валюте — остальные пересчитываются сразу.»
- **CTA:** EN "Split your next bill with FIXXE" · RU «Следующий счёт делите в FIXXE»
- **Proof screen:** the **GEL row active** (blue focus frame) with an amount like 240, and the EUR / USD / RUB rows below already filled in. For video stories, show 2 seconds of typing into the GEL row and then into the EUR row.
- **Why it works:** it breaks a habit pattern and shows the core product in one look. It also targets everyone, so it's the best concept for broad audiences.
- **Risk check:** "instantly" and "no switching" come from the brief. Don't say "one tap", because the user types. ✅

## C5 · "Rounded up. Never short." (invoices, transfers, cash)
- **Who & when:** paying a foreign invoice, topping up a foreign account, or withdrawing cash for rent, worried about sending slightly too little.
- **Insight:** most rounding is cosmetic. You want rounding that's on your side, where the figure you send is never below what's needed.
- **Hook:** EN **"Rounded up. So the money's enough."** · RU **«Округляем вверх — денег точно хватит.»**
- **Subhead:** EN "Smart rounding never shifts an amount by more than 2%, and 0.94 never becomes '1'." · RU «Округление не искажает сумму больше чем на 2% — и 0,94 никогда не станет «1».»
- **CTA:** EN "Pay foreign bills without guessing" · RU «Плати счета без «а вдруг не хватит»»
- **Proof screen:** a Settings crop showing **"Rounding · Up"** (cut above the Rate source row and the version line), next to a main-screen row like **CHF 0.93** (rate 0.923399) that shows decimals instead of a fake round number. Best paired with C1's +% for invoice-plus-fee.
- **Why it works:** it speaks to a real worry ("will it be enough?"). It's subtle, though, and needs a second frame to land.
- **Risk check:** "never short" must mean the shown amount, not the bank's final debit. Keep the subhead, which makes it clear this is about display rounding, and pair it with the +% adjustment for fees. ⚠️ Medium risk if used without the subhead.

## C6 · "Just the number." (no ads, no account, no tracking)
- **Who & when:** someone who opens a converter for a two-second number and gets a full-screen ad or a sign-up wall instead. This group is tired of ad-stuffed utilities, especially in the Russian-speaking segment.
- **Insight:** a calculator shouldn't need your email or show you a casino ad.
- **Hook:** EN **"No ads. No account. Just the number."** · RU **«Без рекламы, регистрации и слежки. Просто курс.»**
- **Subhead:** EN "Free. The only permission it asks for is internet." · RU «Бесплатно. Единственное разрешение — доступ в интернет.»
- **CTA:** EN "Free on App Store · Google Play · web" · RU «Бесплатно: App Store · Google Play · веб»
- **Proof screen:** the clean main screen (dark theme reads more premium), cropped from the FIXXE wordmark down, with nothing else on it. The emptiness is the proof.
- **Why it works:** it's the best trust and objection-killer frame, and it carries the "free" line. As a cold-audience opener it's weaker, because privacy rarely triggers an install on its own. It works as the closing frame and for retargeting.
- **Risk check:** all three "no" claims come from the brief. Don't show or mimic a competitor's ad screen. ✅

**Reserve (frame-only, crypto and big-number currencies):** EN "Every zero. On screen." · RU «Все нули влезут.» Proof: **150 000 000** shrunk to fit in a VND/IRR/KPW row (new in 1.69), plus "150+ crypto". It's fun and a strong visual, but niche. Use it as an extra frame for crypto-interest targeting, not as a main concept.

---

## Ranking
| # | Concept | Why |
|---|---|---|
| 1 | **C1 Fee you don't see** | Highest-intent moment, unique and provable (purple before/after), different from every converter ad |
| 2 | **C2 Your currency** | Geo- and language-targeted, gives a "made for me" reaction, likely the cheapest CPI in RU/relocant geos |
| 3 | **C3 Landed, no signal** | Gives a reason to install today, ties into travel season and pre-trip targeting |
| 4 | **C4 No from / no to** | Universal core-product demo with a pattern interrupt, best for broad audiences |
| 5 | C6 Just the number | Use it as the end card and for retargeting, not as an opener |
| 6 | C5 Rounded up | Too subtle for 1.5 s and needs a qualifier. Use it as an extra frame in an "invoices and transfers" sequence |

**Top 4 for production: C1, C2, C3, C4.** Each needs EN + RU, with C2 also in per-geo versions (RSD / GEL / KGS hero currency). C6's copy becomes the shared end card.

## Multi-frame sequence order
1. **Hook / pain: C1** "Add their cut. See your number." It's the strongest stop, and if frame 1 doesn't hold the viewer, nothing after it gets seen. In relocant geos, swap C2 into this slot.
2. **How it works: C4** "No 'from'. No 'to'. Just type." This turns curiosity into "this is easy".
3. **Relevance: C2** "Dinar. Lari. Som. All here." This turns "easy" into "it's for me".
4. **Objection and urgency: C3** "Landed. No signal. Still converts." / "Install before you fly."
5. **End card: C6** "No ads. No account. Just the number." with the icon, the FIXXE wordmark, "App Store · Google Play" as text and telebimmer.com/fixxe, with the link sticker placed below y=1580.

Put the small FIXXE icon and wordmark plus the link sticker on every frame, because people tap through and drop off at any point. Keep the frames visually consistent (dark theme, the same crop scale and the same purple/blue accents) so the five frames read as one ad.
