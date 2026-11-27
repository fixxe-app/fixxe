#!/usr/bin/env python3
"""Generates stamp-en.html and stamp-ru.html from one template (same layout, only copy differs).
Round 2: captures at 360 CSS px wide (×3 = 1080), decimals 2 + grouping 1, adjusted + unadjusted pair."""
from pathlib import Path

HERE = Path(__file__).resolve().parent

# Numbers read from the back-to-back captures (14:19): cap-*.png (adjust 1.5) and cap-*-noadj.png (adjust 0).
USD_MARKET, USD_ADJ = "109.69", "111.34"

COPY = {
    "en": dict(
        LANG="en",
        CAP="cap-en.png",
        H1A="Exchange booths take a cut.",
        H1B="Know it first.",
        SUB="Set your % once. Every amount includes it.",
        STAMP_CAP="YOUR FEE",
        CALL_LBL="100 EUR → USD",
        CALL_MKT="market",
        CALL_ADJ="with +1.5%",
        CTA1="Free · App Store · Google Play · Web",
        CTA2="Search “FIXXE”",
    ),
    "ru": dict(
        LANG="ru",
        CAP="cap-ru.png",
        H1A="Обменник своё возьмёт.",
        H1B="Посчитай заранее.",
        SUB="Поставь свой процент один&nbsp;раз&nbsp;— и все суммы сразу с&nbsp;ним.",
        STAMP_CAP="ТВОЯ КОМИССИЯ",
        CALL_LBL="100 EUR → USD",
        CALL_MKT="по рынку",
        CALL_ADJ="с +1,5%",
        CTA1="Бесплатно · App Store · Google Play · веб",
        CTA2="Ищи «FIXXE» в магазине",
    ),
}

# Capture 1080×2100 (360×700 CSS @3x). Crop: purple banner top (y=300) .. gap under the USD row (y=918).
CAP_W, CROP_Y0, CROP_Y1 = 1080, 300, 918
CARD_W = 952
SCALE = CARD_W / CAP_W            # 0.8815 → app 22px amount ≈ 58px, 10px rate line ≈ 26.4px
CARD_H = round((CROP_Y1 - CROP_Y0) * SCALE)
IMG_TOP = -round(CROP_Y0 * SCALE)

ST_W, ST_H = 570, 320
GEOM = dict(
    CARD_W=CARD_W, CARD_H=CARD_H, IMG_TOP=IMG_TOP, CARD_LEFT=64, CARD_TOP=584,
    ST_W=ST_W, ST_H=ST_H, ST_W_PAD=ST_W + 80, ST_H_PAD=ST_H + 80,
    ST_LEFT=53, ST_TOP=952,
    ST_W1=ST_W - 18, ST_H1=ST_H - 18, ST_W2=ST_W - 64, ST_H2=ST_H - 64,
    ST_CX=ST_W // 2, ST_TXT_W=ST_W - 120,
    ST_BAND_TOP=44, ST_BAND_BOT=226, ST_LINE_Y=234, ST_LINE_X2=ST_W - 58,
    ST_CAP_TOP=246, ST_CAP_BOT=292, ST_CAP_LEN=ST_W - 140,
    USD_MARKET=USD_MARKET, USD_ADJ=USD_ADJ,
)

TEMPLATE = r"""<!doctype html>
<html lang="LANG">
<head>
<meta charset="utf-8">
<title>FIXXE story · stamp · LANG</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Unbounded:wght@700;800;900&family=Manrope:wght@500;600;700;800&family=JetBrains+Mono:wght@700;800&display=block" rel="stylesheet">
<style>
  :root{--paper:#F3EFE7;--ink:#14121A;--gold:#C9A55C;--gold-hi:#E8C77A;--green:#2E7D32;--blue:#1565C0;--purple:#6A1B9A}
  html,body{width:1080px;height:1920px;margin:0;overflow:hidden}
  body{position:relative;background:var(--paper);color:var(--ink);
       font-family:Manrope,-apple-system,"SF Pro Display",system-ui,sans-serif;-webkit-font-smoothing:antialiased}
  .abs{position:absolute}
  #paper{left:0;top:0;width:1080px;height:1920px}
  #icon{left:64px;top:268px;width:84px;height:84px;border-radius:20px;display:block;box-shadow:0 6px 16px rgba(20,18,26,.18)}
  #word{left:168px;top:268px;height:84px;display:flex;align-items:center;font:800 46px/1 Manrope,sans-serif;letter-spacing:.22em;color:var(--green)}
  #rule{left:64px;top:360px;width:120px;height:4px;background:var(--gold)}
  #h1{left:64px;top:404px;width:952px;margin:0;font-family:Unbounded,sans-serif;font-weight:800;font-size:84px;
      line-height:1.08;letter-spacing:-.02em;color:var(--ink)}
  #h1 span{display:block;white-space:nowrap}
  #h1 .b{color:var(--purple)}
  #card{left:CARD_LEFTpx;top:CARD_TOPpx;width:CARD_Wpx;height:CARD_Hpx;border-radius:40px;overflow:hidden;
        transform:rotate(2deg);transform-origin:50% 50%;background:#F2F3F5;
        box-shadow:0 40px 80px rgba(60,20,80,.18),0 6px 18px rgba(60,20,80,.10),0 0 0 1px rgba(60,20,80,.06)}
  #card img{position:absolute;left:0;top:IMG_TOPpx;width:CARD_Wpx;display:block}
  #stamp{left:ST_LEFTpx;top:ST_TOPpx;width:ST_Wpx;height:ST_Hpx;transform:rotate(-9deg);transform-origin:50% 50%;
         mix-blend-mode:multiply;overflow:visible}
  /* the cut: market vs adjusted, outside the card under the USD amount */
  #call{right:64px;top:1172px;display:grid;grid-template-columns:auto auto auto;column-gap:14px;row-gap:0;align-items:baseline;justify-items:end}
  #call .lbl{grid-column:1/4}
  #call .t{font:700 25px/1.3 Manrope,sans-serif;color:rgba(20,18,26,.5)}
  #call .t.adj{color:#6A1B9A}
  #call .lbl{font:700 26px/1.2 Manrope,sans-serif;color:rgba(20,18,26,.55);letter-spacing:.02em}
  #call .row{display:flex;align-items:baseline;gap:14px;white-space:nowrap}
  #call .was{font:700 38px/1.15 Manrope,sans-serif;color:#8C8794;text-decoration:line-through;
             text-decoration-thickness:3px;text-decoration-color:rgba(20,18,26,.55)}
  #call .arr{font:800 36px/1 Manrope,sans-serif;color:var(--gold)}
  #call .now{font:800 54px/1.1 Manrope,sans-serif;color:var(--purple);letter-spacing:-.01em}
  #call .tags{display:flex;gap:14px;font:600 22px/1.2 Manrope,sans-serif;color:rgba(20,18,26,.5)}
  #sub{left:64px;top:1330px;width:952px;margin:0;font:700 34px/1.25 Manrope,sans-serif;color:var(--purple);text-wrap:balance}
  #cta1{left:64px;top:1440px;font:700 34px/1.2 Manrope,sans-serif;color:rgba(20,18,26,.70);white-space:nowrap}
  #cta2{left:64px;top:1494px;font:800 44px/1.2 Manrope,sans-serif;color:var(--blue);white-space:nowrap;display:flex;align-items:center;gap:16px}
  #cta2 .arr{color:var(--gold);font-weight:800;font-size:40px;transform:translateY(-2px)}
</style>
</head>
<body>
<svg id="paper" class="abs" viewBox="0 0 1080 1920" aria-hidden="true">
  <defs>
    <filter id="fibre" x="0" y="0" width="100%" height="100%">
      <feTurbulence type="fractalNoise" baseFrequency="0.9 0.06" numOctaves="3" seed="4"/>
      <feColorMatrix type="matrix" values="0 0 0 0 0.35  0 0 0 0 0.28  0 0 0 0 0.20  0 0 0 0.9 -0.25"/>
    </filter>
    <filter id="grain" x="0" y="0" width="100%" height="100%">
      <feTurbulence type="fractalNoise" baseFrequency="1.6" numOctaves="1" seed="9"/>
      <feColorMatrix type="matrix" values="0 0 0 0 0.3  0 0 0 0 0.25  0 0 0 0 0.2  0 0 0 0.6 -0.1"/>
    </filter>
    <radialGradient id="vig" cx="50%" cy="50%" r="75%">
      <stop offset="60%" stop-color="#5a4630" stop-opacity="0"/>
      <stop offset="100%" stop-color="#5a4630" stop-opacity=".10"/>
    </radialGradient>
    <!-- calm the top 250 px (platform avatar/"Sponsored" sit there) -->
    <linearGradient id="top" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#3a3040" stop-opacity=".22"/>
      <stop offset="1" stop-color="#3a3040" stop-opacity="0"/>
    </linearGradient>
  </defs>
  <rect width="1080" height="1920" filter="url(#fibre)" opacity=".05"/>
  <rect width="1080" height="1920" filter="url(#grain)" opacity=".05"/>
  <rect width="1080" height="1920" fill="url(#vig)"/>
  <rect width="1080" height="250" fill="url(#top)"/>
</svg>

<img id="icon" class="abs" src="icon-512.png" alt="">
<div id="word" class="abs">FIXXE</div>
<div id="rule" class="abs"></div>

<h1 id="h1" class="abs"><span class="a">H1A</span><span class="b">H1B</span></h1>

<div id="card" class="abs"><img src="CAP" alt=""></div>

<div id="call" class="abs">
  <div class="lbl">CALL_LBL</div>
  <span class="was">USD_MARKET</span><span class="arr">→</span><span class="now">USD_ADJ</span>
  <span class="t">CALL_MKT</span><span></span><span class="t adj">CALL_ADJ</span>
</div>

<svg id="stamp" class="abs" viewBox="0 0 ST_W ST_H" aria-hidden="true">
  <defs>
    <filter id="ink" x="-6%" y="-10%" width="112%" height="120%" color-interpolation-filters="sRGB">
      <feTurbulence type="fractalNoise" baseFrequency="0.05" numOctaves="2" seed="21" result="w1"/>
      <feDisplacementMap in="SourceGraphic" in2="w1" scale="5" xChannelSelector="R" yChannelSelector="G" result="d1"/>
      <feTurbulence type="fractalNoise" baseFrequency="0.6" numOctaves="1" seed="8" result="w2"/>
      <feDisplacementMap in="d1" in2="w2" scale="3.5" xChannelSelector="G" yChannelSelector="R" result="rough"/>
      <feTurbulence type="fractalNoise" baseFrequency="0.42" numOctaves="2" seed="5" result="sp"/>
      <feColorMatrix in="sp" type="matrix" values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  -17 0 0 0 12.6" result="speck"/>
      <feTurbulence type="fractalNoise" baseFrequency="0.008 0.014" numOctaves="3" seed="13" result="pt"/>
      <feColorMatrix in="pt" type="matrix" values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  1.5 0 0 0 0.22" result="patch"/>
      <feTurbulence type="fractalNoise" baseFrequency="0.035 0.08" numOctaves="3" seed="44" result="sc"/>
      <feColorMatrix in="sc" type="matrix" values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  -7 0 0 0 5.3" result="scuff"/>
      <feComposite in="speck" in2="patch" operator="arithmetic" k1="1" result="m1"/>
      <feComposite in="m1" in2="scuff" operator="arithmetic" k1="1" result="mask"/>
      <feComposite in="rough" in2="mask" operator="in" result="inked"/>
      <feGaussianBlur in="inked" stdDeviation="0.5"/>
    </filter>
    <linearGradient id="pressG" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#fff"/><stop offset=".6" stop-color="#f4f4f4"/><stop offset="1" stop-color="#a6a6a6"/>
    </linearGradient>
    <mask id="press" maskUnits="userSpaceOnUse" x="-40" y="-40" width="ST_W_PAD" height="ST_H_PAD">
      <rect x="-40" y="-40" width="ST_W_PAD" height="ST_H_PAD" fill="url(#pressG)"/>
    </mask>
  </defs>
  <g mask="url(#press)"><g filter="url(#ink)" fill="#6A1B9A" stroke="#6A1B9A" opacity=".92">
    <rect x="9" y="9" width="ST_W1" height="ST_H1" rx="36" fill="none" stroke-width="13"/>
    <rect x="32" y="32" width="ST_W2" height="ST_H2" rx="18" fill="none" stroke-width="4"/>
    <text id="stTxt" x="ST_CX" y="200" text-anchor="middle" stroke="none"
          font-family="Unbounded" font-weight="900" font-size="150" letter-spacing="-3">+1.5%</text>
    <line x1="58" y1="ST_LINE_Y" x2="ST_LINE_X2" y2="ST_LINE_Y" stroke-width="5"/>
    <text id="stCap" x="ST_CX" y="290" text-anchor="middle" stroke="none"
          font-family="Unbounded" font-weight="800" font-size="40" letter-spacing="6">STAMP_CAP</text>
  </g></g>
</svg>

<p id="sub" class="abs">SUB</p>

<div id="cta1" class="abs">CTA1</div>
<div id="cta2" class="abs"><span class="arr">→</span><span>CTA2</span></div>

<script>
document.fonts.ready.then(() => {
  const h = document.getElementById('h1');
  let fs = 84;
  const fits = () => [...h.children].every(s => s.scrollWidth <= 952);
  while (!fits() && fs > 40) { fs -= 1; h.style.fontSize = fs + 'px'; }

  const cv = document.createElement('canvas').getContext('2d');
  const t = document.getElementById('stTxt');
  let size = 150;
  for (let i = 0; i < 4; i++) { size *= ST_TXT_W / t.getComputedTextLength(); t.setAttribute('font-size', size.toFixed(1)); }
  cv.font = '900 ' + size + 'px Unbounded';
  const m = cv.measureText('+1.5%');
  const gh = m.actualBoundingBoxAscent + m.actualBoundingBoxDescent;
  t.setAttribute('y', (ST_BAND_TOP + (ST_BAND_BOT - ST_BAND_TOP - gh) / 2 + m.actualBoundingBoxAscent).toFixed(1));

  const c = document.getElementById('stCap');
  let cs = 40;
  let ls = 6;
  while (c.getComputedTextLength() > ST_CAP_LEN && ls > 2) { ls -= 0.5; c.setAttribute('letter-spacing', ls); }
  while (c.getComputedTextLength() > ST_CAP_LEN && cs > 22) { cs -= 1; c.setAttribute('font-size', cs); }
  cv.font = '800 ' + cs + 'px Unbounded';
  const mc = cv.measureText(c.textContent);
  const ch = mc.actualBoundingBoxAscent + mc.actualBoundingBoxDescent;
  c.setAttribute('y', (ST_CAP_TOP + (ST_CAP_BOT - ST_CAP_TOP - ch) / 2 + mc.actualBoundingBoxAscent).toFixed(1));

  // sub: max two lines, shrink if needed
  const s = document.getElementById('sub');
  let ss = 34;
  while (s.offsetHeight > 2 * 34 * 1.25 + 2 && ss > 26) { ss -= 1; s.style.fontSize = ss + 'px'; }

  document.body.dataset.fonts = ['Unbounded','Manrope'].map(f => f + ':' + document.fonts.check('800 40px ' + f)).join(',');
  document.body.dataset.sizes = fs + '/' + size.toFixed(0) + '/' + cs + '/' + ss + '/sub-h' + s.offsetHeight;
});
</script>
</body>
</html>
"""

for key, c in COPY.items():
    html = TEMPLATE
    # longest keys first so ST_W1 doesn't get eaten by ST_W, etc.
    for k, v in sorted({**c, **GEOM}.items(), key=lambda kv: -len(kv[0])):
        html = html.replace(k, str(v))
    (HERE / f"stamp-{key}.html").write_text(html, encoding="utf-8")
    print("wrote", HERE / f"stamp-{key}.html")
