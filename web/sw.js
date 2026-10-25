// FIXXE service worker — offline app shell + fresh rates
const CACHE = 'fixe-v64';
const SHELL = [
  './', './index.html', './styles.css', './app.js',
  './i18n.js', './currency-data.js', './manifest.webmanifest',
  './icons/icon-192.png', './icons/icon-512.png', './icons/icon-1024.png',
  './icons/icon-maskable-512.png', './icons/apple-touch-icon.png', './icons/favicon.png'
];

self.addEventListener('install', e=>{
  e.waitUntil(caches.open(CACHE).then(c=>c.addAll(SHELL)).then(()=>self.skipWaiting()));
});
self.addEventListener('activate', e=>{
  e.waitUntil(caches.keys().then(ks=>Promise.all(ks.filter(k=>k!==CACHE).map(k=>caches.delete(k)))).then(()=>self.clients.claim()));
});
self.addEventListener('fetch', e=>{
  const url = new URL(e.request.url);
  // Курсы — всегда из сети (не кэшируем котировки)
  if (url.origin !== location.origin){ return; }
  // APK и сведения о версии — только из сети. Иначе кэш отдаёт файл прошлой
  // версии: каждое скачивание APK отставало бы на релиз, а 6 МБ лежали бы
  // в хранилище браузера.
  if (/\.apk$|\/latest\.json$/.test(url.pathname)){ return; }
  // App shell — cache-first, с фоновым обновлением
  e.respondWith(
    caches.match(e.request).then(cached=>{
      const net = fetch(e.request).then(res=>{
        if (res && res.status===200){ const clone=res.clone(); caches.open(CACHE).then(c=>c.put(e.request, clone)); }
        return res;
      }).catch(()=>cached);
      return cached || net;
    })
  );
});
