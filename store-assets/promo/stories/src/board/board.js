// FIXXE story — frame 3 "board". LANG is set by the host HTML.
const T = {
  en: {
    head: 'Dinar. Lari. Som.<br><em>All on board.</em>',
    title: 'DEPARTURES', ghost: 'DEPARTURES',
    labels: ['DESTINATION', 'CURRENCY', 'STATUS'],
    status: 'ON BOARD',
    cities: ['BELGRADE', 'TBILISI', 'BISHKEK', 'DUSHANBE', 'YEREVAN', 'ALMATY'],
    sub: '300+ currencies · precious metals',
    cta1: 'Free · App Store · Google Play · Web',
    cta2: 'Search “FIXXE”',
    proof: 'en',
  },
  ru: {
    head: 'Динар, лари, сом&nbsp;—<br><em>все на месте.</em>',
    title: 'ВЫЛЕТ', ghost: 'ВЫЛЕТ',
    labels: ['НАПРАВЛЕНИЕ', 'ВАЛЮТА', 'СТАТУС'],
    status: 'НА БОРТУ',
    cities: ['БЕЛГРАД', 'ТБИЛИСИ', 'БИШКЕК', 'ДУШАНБЕ', 'ЕРЕВАН', 'АЛМАТЫ'],
    sub: '300+ валют · драгоценные металлы',
    cta1: 'Бесплатно · App Store · Google Play · веб',
    cta2: 'Ищи «FIXXE» в магазине',
    proof: 'ru',
  },
}[LANG];

const FLAGS = ['🇷🇸', '🇬🇪', '🇰🇬', '🇹🇯', '🇦🇲', '🇰🇿'];
const CODES = ['RSD', 'GEL', 'KGS', 'TJS', 'AMD', 'KZT'];
const CITY_SLOTS = 8;
// the single tile frozen mid-flip: row 5 (ALMATY / KZT), code column, 3rd char (T), previous char shown on the falling flap
// motion cue on an EMPTY filler tile (no letter involved): BISHKEK/БИШКЕК row, 8th city slot
const FLIP = { row: 2, col: 'city', idx: 7, prev: ' ' };

const esc = s => s === ' ' ? '&nbsp;' : s;
function tile(ch, prev) {
  const c = ch || '';
  if (prev) {
    // second half of a flip: new top half already down, the flap carrying the new bottom half
    // is still falling over the previous character's bottom half.
    return `<div class="t flipping"><div class="h top"><span class="g">${esc(c)}</span></div>` +
      `<div class="h bot"><span class="g">${esc(prev)}</span></div>` +
      `<div class="flap"><span class="g">${esc(c)}</span></div></div>`;
  }
  return `<div class="t"><div class="h top"><span class="g">${esc(c)}</span></div>` +
    `<div class="h bot"><span class="g">${esc(c)}</span></div></div>`;
}
function tiles(str, n, flipIdx, prev) {
  let h = '<div class="tiles">';
  for (let i = 0; i < n; i++) h += tile(str[i] || '', i === flipIdx ? (prev || ' ') : null);
  return h + '</div>';
}

// geometry (relative to .rows, which sits at board-left + 22)
const X = { flag: 0, city: 74, code: 74 + 8 * 42 + 7 * 4 + 34, pill: 0 };
X.pill = X.code + 3 * 42 + 2 * 4 + 34;
const PITCH = 56;

function build() {
  const $ = id => document.getElementById(id);
  $('head').innerHTML = T.head;
  $('ttl').textContent = T.title;
  $('ghost').innerHTML = [...T.ghost.padEnd(10, ' ')].map(c => tile(c.trim())).join('');
  $('ghostb').innerHTML = Array(10).fill(0).map(() => tile('')).join('');
  let rows = '';
  T.cities.forEach((city, r) => {
    const f = FLIP.row === r ? FLIP : null;
    rows += `<div class="row" style="top:${r * PITCH}px">` +
      `<div class="flag" style="position:absolute;left:${X.flag}px">${FLAGS[r]}</div>` +
      `<div style="position:absolute;left:${X.city}px">${tiles(city, CITY_SLOTS, f && f.col === 'city' ? f.idx : -1, f && f.prev)}</div>` +
      `<div style="position:absolute;left:${X.code}px">${tiles(CODES[r], 3, f && f.col === 'code' ? f.idx : -1, f && f.prev)}</div>` +
      `<div class="pill" style="position:absolute;left:${X.pill}px"><i></i>${T.status}</div>` +
      `</div>`;
  });
  $('rows').innerHTML = rows;
  $('proof').innerHTML = ['rsd', 'gel', 'kgs'].map(c => `<img src="row-${T.proof}-${c}.png" alt="">`).join('');
  $('cta2').textContent = T.cta2;
  $('sub').textContent = T.sub;
  $('cta1').textContent = T.cta1;
}

function fit(el, maxPx, minPx, maxLines, width) {
  let s = maxPx;
  el.style.fontSize = s + 'px';
  const lh = () => parseFloat(getComputedStyle(el).lineHeight);
  while (s > minPx && (el.scrollWidth > width || el.getBoundingClientRect().height > lh() * maxLines + 2)) {
    s -= 1; el.style.fontSize = s + 'px';
  }
  return s;
}

build();
Promise.all([
  document.fonts.load('800 80px Unbounded', 'Динар Dinar'),
  document.fonts.load('800 46px Manrope', 'FIXXE НА БОРТУ'),
  document.fonts.load('700 34px Manrope', 'Бесплатно Free'),
  document.fonts.load('800 46px "JetBrains Mono"', 'БЕЛГРАД BELGRADE'),
  document.fonts.load('700 17px "JetBrains Mono"', 'НАПРАВЛЕНИЕ DESTINATION'),
]).then(() => document.fonts.ready).then(() => {
  const h = document.getElementById('head');
  const s = fit(h, 74, 50, 2, 952);
  fit(document.getElementById('sub'), 36, 26, 1, 952);
  // record what actually loaded (for QA)
  const ok = ['Unbounded', 'Manrope', 'JetBrains Mono'].map(f => f + ':' + document.fonts.check(`800 20px "${f}"`));
  document.body.dataset.qa = ok.join(' ') + ' head=' + s + ' h=' + Math.round(h.getBoundingClientRect().height);
  document.title = document.body.dataset.qa;
});
