// FIXXE story — frame 1 "mozg" (chaos -> calm). Shared by mozg-en.html / mozg-ru.html.
// window.T = {headline, scribbles:[4], sub, cta1, cta2, crop}
(async function(){
  const T = window.T, $ = s => document.querySelector(s);
  const LINE_Y = 716;          // the gold line ("glass"); keep in sync with --line-y in mozg.css

  // fill text
  $('.headline').innerHTML = '<span>' + T.headline + '</span>';
  $('.sub').textContent = T.sub;
  $('.cta1').textContent = T.cta1;
  $('.cta2 .txt').textContent = T.cta2;
  const img = $('.shot img');
  img.src = T.crop;
  await img.decode().catch(()=>null);

  // fonts first — nothing measures text before they're in
  const sample = 'Stop the mental math ХВАТИТ ломать мозг Ищи «FIXXE» “” 0123456789 ÷%×?=≈…';
  await Promise.all([
    '900 100px Unbounded','800 46px Manrope','800 44px Manrope','700 40px Manrope','700 34px Manrope',
    '700 64px Caveat'
  ].map(f => document.fonts.load(f, sample).catch(()=>null)));
  await document.fonts.ready;

  // ---------- seeded RNG: identical storm in EN and RU ----------
  let seed = 0x7a11c0de;
  const rnd = () => { seed |= 0; seed = seed + 0x6D2B79F5 | 0;
    let t = Math.imul(seed ^ seed >>> 15, 1 | seed); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
    return ((t ^ t >>> 14) >>> 0) / 4294967296; };
  const R = (a,b) => a + (b-a)*rnd();

  // Fixed zones (identical for EN/RU). Scribble slots first: glyphs there stay soft so the
  // handwriting reads; lockup/headline: glyphs dim + out of focus behind the type.
  const soft = [
    [590, 262, 1030, 352],   // "÷ 0.912 ≈ ?" — right of the lockup
    [560, 398, 1030, 488],   // last scribble — right of headline line 1
    [50, 604, 600, 702],     // "24.90 × 117.63 = ???"
    [660, 604, 1030, 712],   // "+1.5%… or 2?"
  ];
  const dim = [[40, 250, 560, 380], [40, 384, 1040, 604]];
  const inR = (x,y,s) => ([x0,y0,x1,y1]) => x+s*.85 > x0 && x+s*.15 < x1 && y+s*.9 > y0 && y+s*.1 < y1;

  const chaos = $('.chaos');
  const CH = ['÷','%','×','?','=','≈','÷','%','?','×','?'];
  const placed = [];
  const add = (x, y, s, c, rot, op, kind, blur) => {
    const el = document.createElement('div');
    el.className = 'glyph' + (kind === 'g' ? ' g' : kind === 'o' ? ' o' : '');
    el.textContent = c;
    el.style.cssText = `left:${x.toFixed(0)}px;top:${y.toFixed(0)}px;font-size:${s.toFixed(0)}px;` +
      `opacity:${op.toFixed(2)};transform:rotate(${rot.toFixed(1)}deg);` + (blur > .4 ? `filter:blur(${blur.toFixed(1)}px)` : '');
    chaos.appendChild(el);
  };
  let n = 0, guard = 0;
  while (n < 44 && guard++ < 8000){
    const z = rnd();                                   // depth: 0 far, 1 near
    const s = 64 + 186 * z;
    const x = R(-110, 1080 - s*.3);
    // the storm peaks around the headline; the top band (avatar / "Sponsored") gets less
    const y = rnd() < .72 ? R(250 - s*.4, LINE_Y - s*.2) : R(-90, 250);
    if (placed.some(p => Math.hypot(p.x + p.s/2 - x - s/2, p.y + p.s/2 - y - s/2) < (p.s + s) * .33)) continue;
    const r = rnd(), kind = r < .22 ? 'g' : r < .40 ? 'o' : 'w';
    let op, blur;
    if (soft.some(inR(x,y,s)))      { op = .10 + .12*z; blur = 2 + (1-z)*3; }   // under handwriting
    else if (dim.some(inR(x,y,s)))  { op = .09 + .10*z; blur = 3 + (1-z)*4; }   // behind lockup/headline
    else { op = .16 + .38*z; blur = (1-z)*5;
      if (kind === 'g') op = Math.min(op*1.3, .62);
      if (kind === 'o') op = Math.min(op*1.4, .66); }
    add(x, y, s, CH[Math.floor(rnd()*CH.length)], R(-35, 35), op, kind, blur);
    placed.push({x,y,s}); n++;
  }
  // near ones that slam into the glass and get cut by it — kept in the gaps between scribbles
  add(-150, LINE_Y-104, 230, '%', 22, .46, 'g', 0);
  add(600, LINE_Y-66, 150, '×', 24, .30, 'w', 0);
  add(1046, LINE_Y-104, 180, '?', -20, .40, 'o', 0);

  // ---------- scribbles: hand-written pocket maths, crossed out in gold ----------
  // order of T.scribbles: [main sum, +1.5%, ÷ USD, last question]; [anchor x, top y, font px, rotate, align]
  const POS = [[70, 624, 64, 1.2, 'l'], [1010, 630, 54, -3, 'r'], [1004, 276, 58, -5, 'r'], [1012, 414, 60, 3, 'r']];
  T.scribbles.forEach((txt, i) => {
    const [ax, y, fs, rot, al] = POS[i];
    const el = document.createElement('div');
    el.className = 'scribble';
    el.textContent = txt;
    el.style.fontSize = fs + 'px';
    el.style.top = y + 'px';
    chaos.appendChild(el);
    const w = el.offsetWidth, h = el.offsetHeight;
    el.style.left = (al === 'l' ? ax : ax - w) + 'px';
    el.style.transform = `rotate(${rot}deg)`;
    const pass = (y0, y1, amp, steps) => {
      let d = `M ${-12} ${y0.toFixed(1)}`;
      for (let k = 1; k <= steps; k++){
        const t = k/steps, x = -12 + t*(w+24);
        const yy = y0 + (y1-y0)*t + (k%2 ? -amp : amp) * R(.5, 1);
        d += ` L ${x.toFixed(1)} ${yy.toFixed(1)}`;
      }
      return d;
    };
    // thinner + translucent: the digits read first, then you see they're crossed out
    el.insertAdjacentHTML('beforeend', `<svg width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">
      <path d="${pass(h*.58, h*.48, 4, Math.max(6, Math.round(w/42)))}" fill="none" stroke="#C9A55C" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round" opacity=".72"/>
      <path d="${pass(h*.50, h*.62, 3, Math.max(5, Math.round(w/60)))}" fill="none" stroke="#E8C77A" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" opacity=".45"/>
    </svg>`);
  });

  // ---------- fit-to-width headline: max 2 lines, shared layout for EN/RU ----------
  const hl = $('.headline');
  let fs = 104;
  const lines = () => Math.round(hl.getBoundingClientRect().height / (fs * 1.04));
  hl.style.fontSize = fs + 'px';
  while ((hl.scrollWidth > 952 || lines() > 2) && fs > 60){ fs -= 2; hl.style.fontSize = fs + 'px'; }

  // ---------- sub: 30 px under the card, one line, ≥ 90 px clear above the CTA (y=1440) ----------
  const shot = $('.shot').getBoundingClientRect();
  const sub = $('.sub');
  sub.style.top = Math.round(shot.bottom + 30) + 'px';
  let ss = 40; sub.style.whiteSpace = 'nowrap'; sub.style.fontSize = ss + 'px';
  while (sub.scrollWidth > 952 && ss > 30){ ss -= 1; sub.style.fontSize = ss + 'px'; }
  const subBottom = sub.getBoundingClientRect().bottom;

  // verification markers for --dump-dom
  document.body.dataset.fonts = ['900 100px Unbounded','800 46px Manrope','700 40px Manrope','700 64px Caveat']
    .map(f => f.split(' ').pop() + ':' + document.fonts.check(f, sample)).join(',');
  document.body.dataset.hl = fs + 'px/' + lines() + 'l';
  document.body.dataset.shot = Math.round(shot.top) + '-' + Math.round(shot.bottom);
  document.body.dataset.sub = ss + 'px/bottom ' + Math.round(subBottom) + '/gap ' + Math.round(1440 - subBottom);
  document.body.dataset.ready = '1';
})();
