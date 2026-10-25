'use strict';
const APP_VERSION = '1.64';

/* ---------- Persistence ---------- */
const store = {
  get(k, d){ try{ const v = localStorage.getItem('fixe.'+k); return v===null?d:JSON.parse(v);}catch(e){return d;} },
  set(k, v){ try{ localStorage.setItem('fixe.'+k, JSON.stringify(v)); }catch(e){} }
};

/* ---------- State ---------- */
let displayCurrencies = (()=>{
  const raw = store.get('currencies', DEFAULT_CURRENCIES.slice());
  const uniq = [...new Set(raw)];
  if (uniq.length !== raw.length) store.set('currencies', uniq); // чистим сохранённые дубли
  return uniq;
})();
let decimalPlaces = store.get('decimals', 0);
// разделитель разрядов: 0 — нет, 1 — пробел, 2 — запятая
let grouping = store.get('grouping', 0);
// оформление: 0 — как в системе, 1 — светлое, 2 — тёмное
let theme = store.get('theme', 0);
let sourceMode = store.get('source', 0);          // 0=auto, 1..3 forced
// null = ничего не выбрано → английский (дефолт всех платформ);
// 'system' = автоопределение по языку устройства
const SYSTEM_LANG = 'system';
let lang = store.get('lang', null);
let allRates = {};
let activeCurrency = displayCurrencies[0] || 'EUR';
let activeAmount = 1;
let currentSource = '';
let lastUpdated = '';
let fromCache = false;   // данные из кэша (сеть недоступна)
let stale = false;       // кэшу больше суток — курсы могли устареть
const CACHE_AGE_MS = 24*60*60*1000;

/* ---------- i18n ---------- */
function resolveLang(){
  if (lang && lang !== SYSTEM_LANG && I18N[lang]) return lang;
  if (lang === SYSTEM_LANG){
    const cands = (navigator.languages || [navigator.language || 'en']);
    for (const l of cands){
      const base = (l||'').toLowerCase().split('-')[0];
      if (I18N[base]) return base;
    }
  }
  return 'en'; // по умолчанию и при неизвестном языке устройства — English
}
function t(key, ...args){
  const L = resolveLang();
  let s = (I18N[L] && I18N[L][key]) || I18N.en[key] || key;
  s = s.replace(/%(\d+)\$[sd]/g, (_,n)=> args[+n-1] !== undefined ? args[+n-1] : '');
  return s;
}
function applyDir(){
  const L = resolveLang();
  document.documentElement.lang = L;
  document.documentElement.dir = RTL_LANGS.includes(L) ? 'rtl' : 'ltr';
}

/* ---------- Currency helpers ---------- */
const cName = c => NAMES[c] || c;
// название рядом с кодом: пусто, если названия нет (иначе дубль «BTC  BTC»)
const cDisplayName = c => NAMES[c] || '';
const cFlag = c => FLAGS[c] || '🌐';
const cSym  = c => SYMBOLS[c] || c;

function fmtRate(r){
  if (r >= 10000) return r.toFixed(0);
  if (r >= 100)   return r.toFixed(2);
  if (r >= 1)     return r.toFixed(4);
  return r.toFixed(6);
}
// Умное округление вверх: выбранная точность — минимум, но если она искажает
// абсолютное значение больше чем на TOL (2%), добавляем знаки (мелкие валюты
// не превращаются в «1»).
function fmtAmount(v){
  const n = decimalPlaces;
  if (v <= 0) return n===0 ? '0' : (0).toFixed(n);
  const TOL = 0.02;
  let d = n;
  while (d < 8){
    const f = Math.pow(10, d);
    const ceiled = Math.ceil(v*f - 1e-9)/f;
    if (ceiled - v <= TOL*v) break;
    d++;
  }
  const f = Math.pow(10, d);
  const ceiled = Math.ceil(v*f - 1e-9)/f;
  return groupDigits(d===0 ? String(Math.round(ceiled)) : ceiled.toFixed(d));
}
// Группируем только целую часть. В поле, которое сейчас редактируют,
// группировки нет — она мешала бы набору и прыгала бы под курсором.
function applyTheme(){
  const root = document.documentElement;
  if (theme === 1)      root.setAttribute('data-theme','light');
  else if (theme === 2) root.setAttribute('data-theme','dark');
  else                  root.removeAttribute('data-theme');   // решает система
  // строка состояния браузера под цвет шапки
  const dark = theme===2 || (theme===0 && matchMedia('(prefers-color-scheme: dark)').matches);
  let meta = document.querySelector('meta[name="theme-color"]');
  if (!meta){ meta = document.createElement('meta'); meta.name='theme-color'; document.head.appendChild(meta); }
  meta.content = dark ? '#1E1E1E' : '#FFFFFF';
}

// Название источника не должно рваться переносом посередине
// («ExchangeRate-» / «API»): дефис в нём делаем неразрывным.
const nbHyphen = s => String(s).replace(/-/g, '\u2011');
// Короткое имя источника для строки статуса: в шапке мало места, и полное
// «ExchangeRate-API» вытесняет дату — строка обрывается многоточием. В
// настройках, где источник выбирают, имена остаются полными.
const shortSource = s => nbHyphen(({
  'ExchangeRate-API':  'ER-API',
  'Frankfurter (ECB)': 'Fra.ECB',
}[s]) || s);
// строка не должна начинаться с разделителя «·» — привязываем его к слову слева
const tidy = s => String(s).replace(/ · /g, '\u00A0· ');

function groupDigits(text){
  if (!grouping) return text;
  const sep = grouping===1 ? '\u00A0' : ',';   // неразрывный пробел, чтобы число не рвалось
  const dot = text.indexOf('.');
  const intPart = dot>=0 ? text.slice(0,dot) : text;
  const rest    = dot>=0 ? text.slice(dot)   : '';
  if (intPart.length <= 3) return text;
  return intPart.replace(/\B(?=(\d{3})+(?!\d))/g, sep) + rest;
}

// Разбор суммы. Те же правила на всех трёх платформах.
// Десятичный знак на цифровой клавиатуре зависит от региона: в России,
// Сербии, Германии это запятая. Поэтому запятую нельзя слепо считать
// разделителем разрядов, даже если он выбран, — иначе «1,5» молча станет 15.
//  - есть и точка, и запятая — десятичный знак тот, что правее;
//  - один знак встречается несколько раз — это разряды;
//  - одна запятая — десятичная, кроме случая, когда выбрана группировка
//    запятой и за ней ровно группы по три цифры («1,500» = 1500);
//  - пробелы и неразрывные пробелы — всегда разряды.
function parseAmount(s){
  let t = String(s).replace(/[\s  ]/g, '');
  const dot = t.lastIndexOf('.'), comma = t.lastIndexOf(',');
  if (dot >= 0 && comma >= 0){
    t = comma > dot ? t.replace(/\./g,'').replace(',', '.') : t.replace(/,/g,'');
  } else if (comma >= 0){
    const many = (t.match(/,/g) || []).length > 1;
    const thousands = grouping===2 && /^\d{1,3}(,\d{3})+$/.test(t);
    t = (many || thousands) ? t.replace(/,/g,'') : t.replace(',', '.');
  } else if ((t.match(/\./g) || []).length > 1){
    t = t.replace(/\./g,'');
  }
  const v = Number(t);
  return Number.isFinite(v) ? v : 0;
}

/* ---------- Rate sources (fallback chain) ---------- */
const SOURCES = [
  { name:'ExchangeRate-API', urls:['https://open.er-api.com/v6/latest/EUR'],
    parse:j => { if(j.result!=='success') throw 0; return j.rates; } },
  { name:'F.A.', urls:[
      'https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/eur.json',
      'https://latest.currency-api.pages.dev/v1/currencies/eur.json'],
    parse:j => { const o={}; for(const k in j.eur){ const v=+j.eur[k]; if(v>0) o[k.toUpperCase()]=v; } return o; } },
  { name:'Frankfurter (ECB)', urls:['https://api.frankfurter.dev/v1/latest?base=EUR'],
    parse:j => { const o=Object.assign({}, j.rates); o.EUR=1; return o; } },
];

// Метаданные источников для UI (индекс+1 = sourceMode при принудительном выборе)
const SOURCE_META = [
  { name:'ExchangeRate-API', short:'er-api', color:'#1565C0' },
  { name:'F.A.',             short:'F.A.',   color:'#43A047' },
  { name:'Frankfurter (ECB)',short:'ECB',    color:'#FB8C00' },
];
// Наборы кодов валют по каждому источнику (какая валюта где есть)
let sourceCodes = { 'ExchangeRate-API':null, 'F.A.':null, 'Frankfurter (ECB)':null };

async function loadSourceCodes(){
  // с таймаутом: без него зависший источник держал бы загрузку списка валют бесконечно
  const j = async (u,f)=>{
    const ctrl = new AbortController();
    const to = setTimeout(()=>ctrl.abort(), 8000);
    try{ const r = await fetch(u,{cache:'no-store', signal:ctrl.signal}); return f(await r.json()); }
    catch(e){ return null; }
    finally{ clearTimeout(to); }
  };
  const [a,b,c] = await Promise.all([
    j('https://open.er-api.com/v6/latest/EUR', d=> d.result==='success'? Object.keys(d.rates):null),
    j('https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies.json', d=> Object.keys(d).map(k=>k.toUpperCase()))
      .then(x=> x || j('https://latest.currency-api.pages.dev/v1/currencies.json', d=> Object.keys(d).map(k=>k.toUpperCase()))),
    j('https://api.frankfurter.dev/v1/currencies', d=> [...Object.keys(d),'EUR']),
  ]);
  if (a) sourceCodes['ExchangeRate-API'] = new Set(a);
  if (b) sourceCodes['F.A.'] = new Set(b);
  if (c) sourceCodes['Frankfurter (ECB)'] = new Set(c);
}

// В каких источниках есть код (массив индексов SOURCE_META)
function sourcesWith(code){
  const out=[];
  SOURCE_META.forEach((s,i)=>{ if (sourceCodes[s.name] && sourceCodes[s.name].has(code)) out.push(i); });
  return out;
}

async function fetchRates(){
  const ordered = (sourceMode>=1 && sourceMode<=SOURCES.length)
    ? [SOURCES[sourceMode-1], ...SOURCES.filter((_,i)=>i!==sourceMode-1)]
    : SOURCES;
  let lastErr;
  for (const src of ordered){
    for (const url of src.urls){
      try{
        const ctrl = new AbortController();
        const to = setTimeout(()=>ctrl.abort(), 8000);
        const r = await fetch(url, {signal:ctrl.signal, cache:'no-store'});
        clearTimeout(to);
        if(!r.ok) throw new Error('HTTP '+r.status);
        const rates = src.parse(await r.json());
        if (Object.keys(rates).length < 2) throw new Error('too few');
        return { rates, source:src.name };
      }catch(e){ lastErr = e; }
    }
  }
  throw lastErr || new Error('no sources');
}

function fmtTime(d){
  const pad = n => String(n).padStart(2,'0');
  const mon = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][d.getMonth()];
  return `${pad(d.getDate())} ${mon} ${d.getFullYear()} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

// Курсы держим в кэше: без сети приложение всё равно считает,
// а если кэшу больше суток — интерфейс об этом предупреждает.
function cacheRates(rates, source){
  store.set('rates', { rates, source, at: Date.now() });
}
function showCached(){
  const c = store.get('rates', null);
  if (!c || !c.rates || !Object.keys(c.rates).length) return false;
  allRates = c.rates; currentSource = c.source || '';
  lastUpdated = fmtTime(new Date(c.at));
  fromCache = true;
  stale = Date.now() - c.at > CACHE_AGE_MS;
  return true;
}

// Курсы обновляются раз в сутки: чаще раза в 10 секунд дёргать API незачем,
// а повторные нажатия во время запроса просто игнорируем.
let refreshing = false, lastFetchAt = 0;
const MIN_FETCH_INTERVAL = 10000;

let pendingForce = false;   // попросили принудительно, пока шёл запрос

// После обновления курсов список строится заново, и поле, в котором
// человек как раз печатал, теряло фокус: клавиатура закрывалась посреди ввода.
function renderKeepingFocus(){
  const el = document.activeElement;
  const code = el && el.classList && el.classList.contains('amount')
             ? el.closest('.card')?.dataset.code : null;
  render();
  if (!code) return;
  const again = document.querySelector(`.card[data-code="${code}"] .amount`);
  if (!again) return;
  again.focus({preventScroll: true});
  const n = again.value.length; again.setSelectionRange(n, n);   // курсор в конец, не выделение
}

async function refresh(force){
  // пока запрос идёт, повторные нажатия игнорируем — но принудительный
  // не выбрасываем: его ответ нужен с новым источником
  if (refreshing){ if (force) pendingForce = true; return; }
  if (!force && Date.now() - lastFetchAt < MIN_FETCH_INTERVAL) return;
  refreshing = true; lastFetchAt = Date.now();
  $('#btnRefresh').classList.add('loading');
  setStatus(t('loading'));
  try{
    const { rates, source } = await fetchRates();
    allRates = rates; currentSource = source;
    lastUpdated = fmtTime(new Date());
    fromCache = false; stale = false;
    cacheRates(rates, source);
    renderKeepingFocus();
  }catch(e){
    // сеть недоступна — считаем по последним известным курсам
    if (showCached()) renderKeepingFocus();
    else setStatus('⚠ ' + t('network_error'));
  }finally{
    refreshing = false;
    $('#btnRefresh').classList.remove('loading');
    if (pendingForce){ pendingForce = false; refresh(true); }
  }
}

/* ---------- Rendering ---------- */
const $ = s => document.querySelector(s);
const listEl = () => $('#list');

function setStatus(txt){ $('#status').textContent = txt; }

// Иконки Material вместо символов «✕» и «⠿»: экранный диктор читал их как
// «знак умножения» и «шрифт Брайля», а рисовались они по-разному в каждом шрифте.
const ICON_CLOSE = '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M19 6.41 17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z"/></svg>';
const ICON_DRAG  = '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M11 18a2 2 0 1 1-4 0 2 2 0 0 1 4 0zM9 10a2 2 0 1 0 0 4 2 2 0 0 0 0-4zm0-6a2 2 0 1 0 0 4 2 2 0 0 0 0-4zm6 4a2 2 0 1 0 0-4 2 2 0 0 0 0 4zm0 2a2 2 0 1 0 0 4 2 2 0 0 0 0-4zm0 6a2 2 0 1 0 0 4 2 2 0 0 0 0-4z"/></svg>';

function render(){
  applyDir();
  // Защита от дублей: чистим список и сохраняем, если что-то повторилось
  const uniq = [...new Set(displayCurrencies)];
  if (uniq.length !== displayCurrencies.length){ displayCurrencies = uniq; store.set('currencies', displayCurrencies); }
  // static labels
  $('#btnClear').textContent = t('clear');
  $('#btnAdd').textContent = t('add_currency');
  $('#btnInfo').textContent = t('mid_market');
  $('#attribution').textContent = t('attribution');
  $('#version').textContent = t('version', APP_VERSION);
  $('#badge').textContent = t('selected', displayCurrencies.length);
  if (lastUpdated){
    const el = $('#status');
    if (stale){
      setStatus(tidy(t('rates_stale', lastUpdated, shortSource(currentSource))));
      el.style.color = '#D84315';           // устаревшие курсы — заметно
    } else if (fromCache){
      setStatus(tidy(t('rates_offline', lastUpdated, shortSource(currentSource))));
      el.style.color = '#8D6E63';
    } else {
      setStatus(tidy(t('updated', lastUpdated, shortSource(currentSource))));
      el.style.color = '';
    }
  }

  const list = listEl();
  list.innerHTML = '';
  if (Object.keys(allRates).length === 0) return;

  const activeRate = allRates[activeCurrency] || 1;
  const amountInEur = activeRate ? activeAmount/activeRate : 0;
  const pivot = allRates[activeCurrency] ? activeCurrency : 'EUR';
  const pivotRate = allRates[pivot] || 1;

  displayCurrencies.forEach(code => {
    const rInEur = allRates[code];
    if (rInEur === undefined) return;
    const converted = amountInEur * rInEur;
    const isActive = code === activeCurrency;

    const card = document.createElement('div');
    card.className = 'card' + (isActive?' active':'');
    card.dataset.code = code;

    // У активной строки подписи нет: курс валюты к себе самой равен единице
    // и ничего не сообщает, а что в ней вводят — видно по рамке.
    const rateText = (code === pivot)
      ? ''
      : `1 ${pivot} = ${fmtRate(rInEur/pivotRate)} ${code}`;

    const r1 = document.createElement('div'); r1.className='row1';
    r1.innerHTML =
      `<button class="del" data-code="${code}" aria-label="${t('delete')}">${ICON_CLOSE}</button>`+
      `<span class="flag">${cFlag(code)}</span>`+
      `<span class="code">${code}</span>`+
      `<span class="spacer"></span>`+
      `<span class="sym">${cSym(code)}</span>`+
      `<input class="amount" inputmode="decimal" value="${fmtAmount(converted)}" placeholder="0">`+
      `<button class="handle" data-code="${code}" aria-label="${t('reorder')}" title="${t('reorder')}">${ICON_DRAG}</button>`;

    const r2 = document.createElement('div'); r2.className='row2';
    r2.innerHTML = `<span class="name">${cDisplayName(code)}</span><span class="rate">${rateText}</span>`;

    card.appendChild(r1); card.appendChild(r2);

    const input = r1.querySelector('.amount');
    if (!isActive) input.value = fmtAmount(converted);
    input.addEventListener('focus', ()=>{
      // Сумму берём по текущему состоянию, а не из замыкания: `converted`
      // посчитан при создании строки и с тех пор мог устареть — recompute()
      // обновляет только показанное значение. Из-за этого клик по строке
      // пересчитывал всё от давно неактуального числа.
      activeAmount = amountIn(code);   // считаем ДО смены активной валюты
      activeCurrency = code; input.select();
      markActive(code);
      // Клавиатура выезжает не мгновенно: подтягиваем строку, когда список
      // уже ужался, иначе прокрутка посчитается по старой высоте.
      setTimeout(()=>card.scrollIntoView({block:'center', behavior:'smooth'}), 320);
    });
    input.addEventListener('input', ()=>{
      activeCurrency = code; activeAmount = parseAmount(input.value);
      recompute();
    });
    r1.querySelector('.del').addEventListener('click', e=>{ e.stopPropagation(); confirmDelete(code); });
    attachDrag(r1.querySelector('.handle'), card);

    list.appendChild(card);
  });
}

// Экранная клавиатура на телефоне.
//
// #app прибит к окну (position:fixed), а окно при выезде клавиатуры не
// меняется — поэтому клавиатура просто накрывает нижние строки, включая ту,
// в которую сейчас вводят сумму. visualViewport знает настоящую видимую
// высоту, по ней и сжимаем контейнер; список внутри него ужимается сам.
if (window.visualViewport){
  const vv = window.visualViewport;
  const app = document.getElementById('app');
  const fit = ()=>{
    // Масштаб — это не клавиатура: при увеличении пальцами видимая область
    // тоже становится меньше, и без этой проверки окно ужималось бы вдвое.
    if (Math.abs(vv.scale - 1) > 0.01){ app.style.top = app.style.bottom = ''; return; }
    const hidden = Math.max(0, window.innerHeight - vv.height - vv.offsetTop);
    // iOS Safari при выезде клавиатуры ещё и сдвигает видимую область вниз
    // (offsetTop > 0) — без верхнего отступа шапка уезжала бы за край.
    app.style.top    = vv.offsetTop > 0 ? vv.offsetTop + 'px' : '';
    app.style.bottom = hidden > 0 ? hidden + 'px' : '';
  };
  vv.addEventListener('resize', fit);
  vv.addEventListener('scroll', fit);
  fit();
}

// Сколько сейчас в указанной валюте — по текущей активной сумме.
// Считается из курсов, а не из того, что написано в поле: показанное
// значение округлено, и перенос его в расчёт сдвигал бы суммы при каждом
// переключении строк.
function amountIn(code){
  const rate = allRates[activeCurrency] || 1;
  const inEur = rate ? activeAmount / rate : 0;
  return inEur * (allRates[code] ?? 0);
}

// Update only amounts (не трогаем поле в фокусе) — при вводе
function recompute(){
  const activeRate = allRates[activeCurrency] || 1;
  const amountInEur = activeRate ? activeAmount/activeRate : 0;
  const pivot = allRates[activeCurrency] ? activeCurrency : 'EUR';
  const pivotRate = allRates[pivot] || 1;
  document.querySelectorAll('.card').forEach(card=>{
    const code = card.dataset.code;
    const rInEur = allRates[code]; if(rInEur===undefined) return;
    const conv = amountInEur * rInEur;
    const input = card.querySelector('.amount');
    if (document.activeElement !== input) input.value = fmtAmount(conv);
    const rate = card.querySelector('.rate');
    rate.textContent = (code===pivot) ? '' : `1 ${pivot} = ${fmtRate(rInEur/pivotRate)} ${code}`;
    card.classList.toggle('active', code===activeCurrency);
  });
}
function markActive(code){
  document.querySelectorAll('.card').forEach(c=> c.classList.toggle('active', c.dataset.code===code));
  recompute();
}

/* ---------- Drag reorder (pointer-based) ---------- */
function attachDrag(handle, card){
  handle.addEventListener('pointerdown', e=>{
    e.preventDefault();
    const list = listEl();
    card.classList.add('dragging');
    const move = ev=>{
      const cards = [...list.querySelectorAll('.card:not(.dragging)')];
      const after = cards.find(c=>{
        const r = c.getBoundingClientRect();
        return ev.clientY < r.top + r.height/2;
      });
      if (after) list.insertBefore(card, after); else list.appendChild(card);
    };
    const up = ()=>{
      card.classList.remove('dragging');
      document.removeEventListener('pointermove', move);
      document.removeEventListener('pointerup', up);
      displayCurrencies = [...list.querySelectorAll('.card')].map(c=>c.dataset.code);
      store.set('currencies', displayCurrencies);
    };
    document.addEventListener('pointermove', move);
    document.addEventListener('pointerup', up);
  });
}

/* ---------- Modals ---------- */
function closeModal(){ $('#modal-root').innerHTML=''; }
function modal(html){
  const root = $('#modal-root');
  root.innerHTML = `<div class="overlay">${html}</div>`;
  root.querySelector('.overlay').addEventListener('click', e=>{ if(e.target.classList.contains('overlay')) closeModal(); });
  return root.querySelector('.modal');
}

function confirmDelete(code){
  if (displayCurrencies.length <= 2) return;
  modal(`<div class="modal">
    <h3>${t('delete_currency_title')}</h3>
    <div class="msg">${t('delete_currency_msg', code, cName(code))}</div>
    <div class="actions"><button data-x>${t('cancel')}</button><button data-ok>${t('delete')}</button></div>
  </div>`);
  $('#modal-root [data-x]').onclick = closeModal;
  $('#modal-root [data-ok]').onclick = ()=>{
    displayCurrencies = displayCurrencies.filter(c=>c!==code);
    if (activeCurrency===code){
      // Сумму переводим в новую валюту, а не переносим как есть:
      // иначе 1000 JPY после удаления JPY становились 1000 EUR.
      const next = displayCurrencies[0];
      activeAmount = amountIn(next);
      activeCurrency = next;
    }
    store.set('currencies', displayCurrencies); closeModal(); render();
  };
}

function confirmClear(){
  modal(`<div class="modal">
    <h3>${t('clear_confirm_title')}</h3>
    <div class="msg">${t('clear_confirm_msg')}</div>
    <div class="actions"><button data-x>${t('cancel')}</button><button data-ok>${t('clear')}</button></div>
  </div>`);
  $('#modal-root [data-x]').onclick = closeModal;
  $('#modal-root [data-ok]').onclick = ()=>{ closeModal(); clearAll(); };
}

function clearAll(){
  activeAmount = 0;
  if(document.activeElement) document.activeElement.blur();
  document.querySelectorAll('.card .amount').forEach(i=> i.value = fmtAmount(0));
  document.querySelectorAll('.card').forEach(c=> c.classList.remove('active'));
}

function showAdd(){
  let filter = 'all';   // 'all' | 0 | 1 | 2 (индекс источника)
  const m = modal(`<div class="modal">
    <div class="search-box">🔍<input id="psearch" placeholder="${t('search_hint')}"></div>
    <div class="src-filter" id="chips"></div>
    <div class="pick-list" id="picks"></div>
    <div class="actions"><button data-x>${t('cancel')}</button></div>
  </div>`);
  const chips = m.querySelector('#chips');
  const picks = m.querySelector('#picks');
  const inp   = m.querySelector('#psearch');

  const allCodes = ()=>{
    const u = new Set(Object.keys(allRates));
    SOURCE_META.forEach(s=>{ const set=sourceCodes[s.name]; if(set) set.forEach(c=>u.add(c)); });
    return [...u].sort();
  };

  const drawChips = ()=>{
    const mk = (key,label,color,on)=>
      `<button class="chip${on?' on':''}" data-f="${key}" style="${on&&color?`background:${color}`:''}">`+
      `${color?`<span class="cdot" style="background:${on?'#fff':color}"></span>`:''}${label}</button>`;
    chips.innerHTML = mk('all', t('filter_all'), '', filter==='all') +
      SOURCE_META.map((s,i)=> mk(String(i), s.short, s.color, filter===i)).join('');
    chips.querySelectorAll('.chip').forEach(b=> b.onclick=()=>{
      const f=b.dataset.f; filter = f==='all'?'all':(+f);
      drawChips(); draw(inp.value.trim().toLowerCase());
    });
  };

  const draw = q=>{
    let list = allCodes();
    if (filter!=='all'){ const set=sourceCodes[SOURCE_META[filter].name]; list = list.filter(c=> set && set.has(c)); }
    if (q) list = list.filter(c=> c.toLowerCase().includes(q) || cName(c).toLowerCase().includes(q));
    picks.innerHTML = list.map(c=>{
      const added = displayCurrencies.includes(c);
      const inActive = allRates[c]!==undefined;
      const dots = sourcesWith(c).map(i=>`<span class="dot" style="background:${SOURCE_META[i].color}" title="${SOURCE_META[i].short}"></span>`).join('');
      return `<div class="pick-row${added?' added':''}${(!inActive&&!added)?' unavail':''}" data-code="${c}">`+
        `<span class="pf">${cFlag(c)}</span><span class="pc">${c}</span>`+
        `<span class="pn">${cDisplayName(c)}</span>`+
        `<span class="src-dots">${dots}</span>`+
        `${added?'<span class="added-tag" title="'+t('already_added')+'">✓</span>':''}</div>`;
    }).join('');
    picks.querySelectorAll('.pick-row:not(.added)').forEach(row=> row.onclick=()=>{
      const c=row.dataset.code;
      if (allRates[c]!==undefined){          // есть в активном источнике — добавляем сразу
        displayCurrencies.push(c); store.set('currencies', displayCurrencies); closeModal(); render();
      } else {                               // есть только в другом — предлагаем переключиться
        const srcs = sourcesWith(c);
        if (srcs.length) confirmSwitch(c, srcs[0]);
      }
    });
  };

  drawChips(); draw('');
  // если списки источников ещё не загрузились — подтянуть и перерисовать
  if (!sourceCodes['F.A.']) loadSourceCodes().then(()=>{ drawChips(); draw(inp.value.trim().toLowerCase()); });
  inp.addEventListener('input', ()=> draw(inp.value.trim().toLowerCase()));
  m.querySelector('[data-x]').onclick = closeModal;
  setTimeout(()=>inp.focus(), 50);
}

function confirmSwitch(code, srcIdx){
  const s = SOURCE_META[srcIdx];
  const m = modal(`<div class="modal">
    <h3>${t('switch_source_title')}</h3>
    <div class="msg">${t('switch_source_msg', code, s.name)}</div>
    <div class="actions"><button data-x>${t('back')}</button><button data-ok>${t('switch_and_add')}</button></div>
  </div>`);
  m.querySelector('[data-x]').onclick = showAdd;   // назад к списку
  m.querySelector('[data-ok]').onclick = ()=>{
    sourceMode = srcIdx+1; store.set('source', sourceMode);
    if(!displayCurrencies.includes(code)){ displayCurrencies.push(code); store.set('currencies', displayCurrencies); }
    closeModal(); refresh(true);
  };
}

function showInfo(){
  modal(`<div class="modal">
    <h3>${t('source_info_title')}</h3>
    <div class="msg">${t('source_info_message')}</div>
    <div class="actions"><button data-x>${t('ok')}</button></div>
  </div>`);
  $('#modal-root [data-x]').onclick = closeModal;
}

function sourceOptions(){ return [t('source_auto'),'ExchangeRate-API','F.A.','Frankfurter (ECB)']; }

function showSettings(){
  const dec = decimalPlaces===0 ? t('precision_value_int') : t('precision_value_n', decimalPlaces);
  const src = sourceOptions()[Math.min(Math.max(sourceMode,0),3)];
  const grp = groupingOptions()[Math.min(Math.max(grouping,0),2)];
  const thm = themeOptions()[Math.min(Math.max(theme,0),2)];
  const langLabel = (lang && lang !== SYSTEM_LANG)
    ? (LANGUAGES.find(l=>l[0]===lang)?.[1]||lang)
    : (lang === SYSTEM_LANG ? t('language_system') : (LANGUAGES.find(l=>l[0]==='en')?.[1]||'English'));
  const m = modal(`<div class="modal">
    <h3>${t('settings')}</h3>
    <div class="list-choice">
      <button class="choice" data-i="0">${t('setting_theme', thm)}</button>
      <button class="choice" data-i="1">${t('setting_precision', dec)}</button>
      <button class="choice" data-i="2">${t('setting_grouping', grp)}</button>
      <button class="choice" data-i="3">${t('setting_source', src)}</button>
      <button class="choice" data-i="4">${t('setting_language', langLabel)}</button>
    </div>
    <div class="actions"><button data-x>${t('close')}</button></div>
  </div>`);
  m.querySelector('[data-x]').onclick = closeModal;
  m.querySelector('[data-i="0"]').onclick = showTheme;
  m.querySelector('[data-i="1"]').onclick = showPrecision;
  m.querySelector('[data-i="2"]').onclick = showGrouping;
  m.querySelector('[data-i="3"]').onclick = showSource;
  m.querySelector('[data-i="4"]').onclick = showLanguage;
}

function choiceList(title, items, checkedIdx, onPick){
  const m = modal(`<div class="modal">
    <h3>${title}</h3>
    <div class="list-choice">${items.map((it,i)=>`<button class="choice ${i===checkedIdx?'sel':''}" data-i="${i}"><span class="radio">${i===checkedIdx?'◉':'○'}</span>${it}</button>`).join('')}</div>
    <div class="actions"><button data-x>${t('back')}</button></div>
  </div>`);
  m.querySelector('[data-x]').onclick = closeModal;
  m.querySelectorAll('.choice').forEach(b=> b.onclick=()=>{ onPick(+b.dataset.i); });
}

function showPrecision(){
  const opts=[t('prec_0'),t('prec_1'),t('prec_2'),t('prec_4')]; const vals=[0,1,2,4];
  choiceList(t('precision_title'), opts, vals.indexOf(decimalPlaces), i=>{
    decimalPlaces = vals[i]; store.set('decimals', decimalPlaces); closeModal(); render();
  });
}
function themeOptions(){ return [t('theme_system'), t('theme_light'), t('theme_dark')]; }

function showTheme(){
  choiceList(t('theme_title'), themeOptions(), theme, i=>{
    theme = i; store.set('theme', theme); applyTheme(); closeModal(); render();
  });
}
function groupingOptions(){ return [t('group_none'), t('group_space'), t('group_comma')]; }

function showGrouping(){
  choiceList(t('grouping_title'), groupingOptions(), grouping, i=>{
    grouping = i; store.set('grouping', grouping); closeModal(); render();
  });
}
function showSource(){
  choiceList(t('source_title'), sourceOptions(), sourceMode, i=>{
    sourceMode = i; store.set('source', sourceMode); closeModal(); refresh(true);
  });
}
function showLanguage(){
  const items = [t('language_system'), ...LANGUAGES.map(l=>l[1])];
  // ничего не выбрано → отмечен English, а не «системный»
  const effective = lang || 'en';
  const checked = effective === SYSTEM_LANG ? 0 : (LANGUAGES.findIndex(l=>l[0]===effective)+1);
  choiceList(t('language_title'), items, checked<0?0:checked, i=>{
    lang = i===0 ? SYSTEM_LANG : LANGUAGES[i-1][0];
    store.set('lang', lang); closeModal(); render();
  });
}

/* ---------- Wire up ---------- */
$('#btnRefresh').onclick = () => refresh();
$('#btnClear').onclick = confirmClear;
$('#btnAdd').onclick = showAdd;
$('#btnInfo').onclick = showInfo;
$('#btnSettings').onclick = showSettings;

applyTheme();
// при режиме «как в системе» следим за сменой системной темы на лету
matchMedia('(prefers-color-scheme: dark)').addEventListener('change', ()=>{ if (theme===0) applyTheme(); });

render();
showCached() && render();   // мгновенный старт с последними известными курсами
refresh();
loadSourceCodes();   // подтягиваем списки валют всех источников (для значков в поиске)
setInterval(() => refresh(), 30*60*1000);
document.addEventListener('visibilitychange', ()=>{ if(!document.hidden) refresh(); });

/* ---------- PWA ---------- */
if ('serviceWorker' in navigator){
  window.addEventListener('load', ()=> navigator.serviceWorker.register('sw.js').catch(()=>{}));
}
