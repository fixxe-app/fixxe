#!/usr/bin/env bash
#
# Smoke-тест PWA перед выпуском: поднимает локальный сервер и открывает
# страницу в безголовом Chrome — ровно так, как её увидит человек.
#
# Проверяет:
#   1. скрипты разбираются без синтаксических ошибок
#   2. страница отдаёт курсы, а не застревает на «загрузке»
#   3. кнопка «обновить» вызывает refresh() без аргумента
#   4. переключение строк не сбрасывает и не сдвигает суммы
#   5. источники курсов
#   6. поправка к курсу: полоса, пересчёт, переходы между строками, сброс
#   7. введённая сумма после закрытия: по сроку из настроек
#   8. длинная сумма уменьшается, а не обрезается
#   9. страница About: ссылка #install открывает способы установки, источник курсов — только в подвале
#  10. в Terms и Privacy перечислены все источники курсов (веб, Android и iOS)
#  11. значки App Store и Google Play в нижней строке: ссылки, рост, ничего не налезает
#  12. узкий экран (от 320 px): строка валюты целиком в карточке, суммы подгоняются при сужении окна
#
# Пункт 3 — статическая проверка, и она не придирка: присваивание
# `onclick = refresh` передаёт в refresh объект события, тот оказывается
# в параметре force, и защита от частых нажатий молча перестаёт работать.
#
set -euo pipefail
cd "$(dirname "$0")/.."

CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
[ -x "$CHROME" ] || { echo "✗ не найден Chrome: $CHROME" >&2; exit 1; }
WORK=$(mktemp -d); PORT=$(( 20000 + RANDOM % 10000 ))
cleanup() { [ -n "${SRV:-}" ] && kill "$SRV" 2>/dev/null || true; rm -rf "$WORK"; }
trap cleanup EXIT
fail() { echo "✗ $*" >&2; exit 1; }

echo "→ 1/13 синтаксис скриптов"
for f in web/*.js; do node --check "$f" >/dev/null || fail "синтаксическая ошибка в $f"; done
echo "  ✓ $(ls web/*.js | wc -l | tr -d ' ') файлов разобраны"

echo "→ 2/13 страница в безголовом Chrome"
# корень сервера — репозиторий: так рядом с сайтом доступны и тестовые страницы
python3 -m http.server "$PORT" --directory . >/dev/null 2>&1 &
SRV=$!
for i in $(seq 1 20); do curl -fsS "http://127.0.0.1:$PORT/web/" >/dev/null 2>&1 && break; sleep 0.5; done
"$CHROME" --headless --disable-gpu --no-sandbox --virtual-time-budget=20000 \
  --dump-dom "http://127.0.0.1:$PORT/web/" > "$WORK/dom.html" 2>"$WORK/chrome.err" || true
grep -q "1 EUR = " "$WORK/dom.html" || {
  echo "  фрагмент страницы:" >&2
  grep -o 'id="status"[^<]*<[^<]*' "$WORK/dom.html" 2>/dev/null | head -3 | sed 's/^/    /' >&2 || true
  fail "на странице нет курсов — застряла на загрузке?"
}
echo "  ✓ курсы отрисованы"

echo "→ 3/13 обработчик кнопки «обновить»"
grep -q "btnRefresh').onclick = () => refresh()" web/app.js \
  || fail "кнопка «обновить» должна вызывать refresh() без аргумента, иначе событие попадёт в параметр force и отключит тротлинг"
echo "  ✓ refresh() вызывается без аргумента"

echo "→ 4/13 переключение строк, удаление валюты, разбор сумм"
"$CHROME" --headless --disable-gpu --no-sandbox --virtual-time-budget=40000 \
  --dump-dom "http://127.0.0.1:$PORT/tools/web-tests/switch-rows.html" > "$WORK/switch.html" 2>/dev/null || true
RES=$(sed -n 's/.*<pre id="result">\([^<]*\)<\/pre>.*/\1/p' "$WORK/switch.html" | head -1)
if ! grep -q '<pre id="result">PASS</pre>' "$WORK/switch.html"; then
  echo "  результат:" >&2
  sed -n '/<pre id="result">/,/<\/pre>/p' "$WORK/switch.html" | sed 's/<[^>]*>//g; s/^/    /' >&2
  fail "сценарии ввода сумм не прошли"
fi
echo "  ✓ переключение строк ничего не сбрасывает и не сдвигает; удаление активной валюты переводит сумму; разбор сумм как на Android и iOS"

echo "→ 5/13 источники курсов: разбор ответов, порядок, резерв, перенос выбора"
"$CHROME" --headless --disable-gpu --no-sandbox --virtual-time-budget=40000 \
  --dump-dom "http://127.0.0.1:$PORT/tools/web-tests/sources.html" > "$WORK/sources.html" 2>/dev/null || true
if ! grep -q '<pre id="result">PASS</pre>' "$WORK/sources.html"; then
  echo "  результат:" >&2
  sed -n '/<pre id="result">/,/<\/pre>/p' "$WORK/sources.html" | sed 's/<[^>]*>//g; s/^/    /' >&2
  fail "источники курсов не прошли проверку"
fi
echo "  ✓ Coinbase первый, FXRatesAPI резерв; ответы разбираются; сохранённый выбор переносится"

echo "→ 6/13 поправка к курсу: полоса, пересчёт, переходы между строками, сброс"
"$CHROME" --headless --disable-gpu --no-sandbox --virtual-time-budget=60000 \
  --dump-dom "http://127.0.0.1:$PORT/tools/web-tests/adjust.html" > "$WORK/adjust.html" 2>/dev/null || true
if ! grep -q '^<pre id="result">PASS</pre>' "$WORK/adjust.html"; then
  echo "  результат:" >&2
  sed -n '/^<pre id="result">/,/<\/pre>/p' "$WORK/adjust.html" | sed 's/<[^>]*>//g; s/^/    /' >&2
  fail "поправка к курсу не прошла проверку"
fi
echo "  ✓ без поправки экран прежний; с поправкой полоса видна, базовая строка точная, остальные пересчитаны и помечены; переходы числа не двигают; сброс через 4 часа с сообщением; FIXXE и «О приложении» ведут на About, Privacy — в новой вкладке"

echo "→ 7/13 введённая сумма после закрытия: 12 ч по умолчанию, 24 ч, «всегда», «пока открыто»"
"$CHROME" --headless --disable-gpu --no-sandbox --virtual-time-budget=90000 \
  --dump-dom "http://127.0.0.1:$PORT/tools/web-tests/memory.html" > "$WORK/memory.html" 2>/dev/null || true
if ! grep -q '<pre id="result">PASS</pre>' "$WORK/memory.html"; then
  echo "  результат:" >&2
  sed -n '/<pre id="result">/,/<\/pre>/p' "$WORK/memory.html" | sed 's/<[^>]*>//g; s/^/    /' >&2
  fail "память суммы не прошла проверку"
fi
echo "  ✓ сумма переживает перезагрузку по сроку; «пока открыто» её стирает; после срока — снова 42, и без перезагрузки"

echo "→ 8/13 длинная сумма уменьшается, а не обрезается"
"$CHROME" --headless --disable-gpu --no-sandbox --virtual-time-budget=60000 \
  --dump-dom "http://127.0.0.1:$PORT/tools/web-tests/fit.html" > "$WORK/fit.html" 2>/dev/null || true
if ! grep -q '<pre id="result">PASS</pre>' "$WORK/fit.html"; then
  echo "  результат:" >&2
  sed -n '/<pre id="result">/,/<\/pre>/p' "$WORK/fit.html" | sed 's/<[^>]*>//g; s/^/    /' >&2
  fail "длинная сумма не влезает в поле"
fi
echo "  ✓ «150 000 000» и пересчитанные суммы видны целиком; стёрли — размер обычный; не меньше половины"

echo "→ 9/13 страница About: значки магазинов вверху, ссылка #install, источник курсов в подвале"
"$CHROME" --headless --disable-gpu --no-sandbox --virtual-time-budget=40000 \
  --dump-dom "http://127.0.0.1:$PORT/tools/web-tests/anchor.html" > "$WORK/anchor.html" 2>/dev/null || true
if ! grep -q '<pre id="result">PASS</pre>' "$WORK/anchor.html"; then
  echo "  результат:" >&2
  sed -n '/<pre id="result">/,/<\/pre>/p' "$WORK/anchor.html" | sed 's/<[^>]*>//g; s/^/    /' >&2
  fail "страница About не прошла проверку"
fi
echo "  ✓ about/#install — раздел вверху экрана после отрисовки описания; без якоря — страница сверху; источник курсов только в подвале; значки App Store и Google Play вверху (320–900 px, RU и арабский); логотип ведёт в калькулятор; Privacy/Terms в новой вкладке"

echo "→ 10/13 в Terms и Privacy перечислены все источники курсов, подвал одинаковый"
# Источник добавили в приложение, а условия о нём молчат — так Terms и
# Privacy уже однажды отстали на три источника. Имена — из кода всех трёх платформ.
python3 - <<'PY' || fail "Terms или Privacy не называют все источники курсов — допиши web/terms.html и web/privacy.html"
import re, pathlib, sys
names = set(re.findall(r"\{ name:'([^']+)',\s+short:", pathlib.Path("web/app.js").read_text()))
names |= set(re.findall(r'SourceInfo\("([^"]+)"', pathlib.Path(
    "app/src/main/java/com/example/currencyconverter/data/CurrencyRepository.kt").read_text()))
for f in pathlib.Path("ios/FIXXE").rglob("*.swift"):
    names |= set(re.findall(r'RateSource\(name: "([^"]+)"', f.read_text()))
ALIAS = {"F.A.": "Fawaz Ahmed", "Frankfurter (ECB)": "Frankfurter"}   # в тексте — полным именем
if len(names) < 5: sys.exit(f"  нашлось слишком мало источников в коде: {sorted(names)}")
bad = []
for page in ("terms", "privacy"):
    text = pathlib.Path(f"web/{page}.html").read_text()
    miss = [n for n in sorted(names) if ALIAS.get(n, n) not in text]
    if miss: bad.append(f"  нет в {page}.html: " + ", ".join(miss))
if bad: sys.exit("\n".join(bad))
print("  ✓ все " + str(len(names)) + ": " + ", ".join(sorted(names)))
PY
# Внизу Privacy и Terms — один и тот же подвал со ссылками на все страницы
python3 - <<'PY' || fail "подвал Privacy и Terms разный или без нужных ссылок"
import re, pathlib, sys
feet = [re.findall(r'<p class="links">.*?</p>', pathlib.Path(f"web/{p}.html").read_text()) for p in ("privacy", "terms")]
if not all(len(f) == 1 for f in feet) or feet[0] != feet[1]: sys.exit("  подвалы различаются или их нет")
hrefs = re.findall(r'href="([^"]+)"', feet[0][0])
if hrefs != ["privacy.html", "terms.html", "about/", "./"]: sys.exit(f"  ссылки в подвале: {hrefs}")
print("  ✓ подвал Privacy · Terms · About · Web version FIXXE — одинаковый на обеих страницах")
PY

echo "→ 11/13 значки App Store и Google Play в нижней строке"
"$CHROME" --headless --disable-gpu --no-sandbox --virtual-time-budget=240000 \
  --dump-dom "http://127.0.0.1:$PORT/tools/web-tests/stores.html" > "$WORK/stores.html" 2>/dev/null || true
if ! grep -q '<pre id="result">PASS</pre>' "$WORK/stores.html"; then
  echo "  результат:" >&2
  sed -n '/<pre id="result">/,/<\/pre>/p' "$WORK/stores.html" | sed 's/<[^>]*>//g; s/^/    /' >&2
  fail "значки магазинов не прошли проверку"
fi
echo "  ✓ оба значка ведут в FIXXE, одного роста, в строке «Добавить валюту»; 320–768 px, 6 языков вкл. арабский — ничего не налезает и не вылезает"

echo "→ 12/13 узкий экран: строка валюты целиком в карточке"
"$CHROME" --headless --disable-gpu --no-sandbox --virtual-time-budget=90000 \
  --dump-dom "http://127.0.0.1:$PORT/tools/web-tests/narrow.html" > "$WORK/narrow.html" 2>/dev/null || true
if ! grep -q '<pre id="result">PASS</pre>' "$WORK/narrow.html"; then
  echo "  результат:" >&2
  sed -n '/<pre id="result">[A-Z]/,/<\/pre>/p' "$WORK/narrow.html" | sed 's/<[^>]*>//g; s/^/    /' >&2
  fail "строка валюты не помещается на узком экране"
fi
echo "  ✓ 320–430 px: код не слипается с символом, ручка и сумма в карточке, название под кодом; сузили окно — суммы подогнаны заново"

echo "→ 13/13 service worker берёт страницы из сети, а не старые из кэша"
# В безголовом Chrome service worker не запускается — проверяем код: для
# страниц сначала fetch, кэш — только в .catch (без связи)
python3 - <<'PY' || fail "service worker отдаёт страницы из кэша — после выкладки люди видят старые"
import re, pathlib, sys
s = pathlib.Path("web/sw.js").read_text()
m = re.search(r"if \(e\.request\.mode === 'navigate'[^\n]*\{(.*?)\n    return;\n  \}", s, re.S)
if not m: sys.exit("  в sw.js нет отдельной ветки для страниц (navigate)")
body = m.group(1)
f, c = body.find("fetch("), body.find("caches.match")
if f < 0 or c < 0 or c < f or ".catch(" not in body[f:c]: sys.exit("  страницы не из сети: кэш раньше fetch или не только без связи")
PY
echo "  ✓ страницы (index, About, Privacy, Terms) — сначала из сети, кэш только без связи"

echo "✓ Web smoke пройден"
