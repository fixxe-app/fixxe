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

echo "→ 1/6 синтаксис скриптов"
for f in web/*.js; do node --check "$f" >/dev/null || fail "синтаксическая ошибка в $f"; done
echo "  ✓ $(ls web/*.js | wc -l | tr -d ' ') файлов разобраны"

echo "→ 2/6 страница в безголовом Chrome"
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

echo "→ 3/6 обработчик кнопки «обновить»"
grep -q "btnRefresh').onclick = () => refresh()" web/app.js \
  || fail "кнопка «обновить» должна вызывать refresh() без аргумента, иначе событие попадёт в параметр force и отключит тротлинг"
echo "  ✓ refresh() вызывается без аргумента"

echo "→ 4/6 переключение строк, удаление валюты, разбор сумм"
"$CHROME" --headless --disable-gpu --no-sandbox --virtual-time-budget=40000 \
  --dump-dom "http://127.0.0.1:$PORT/tools/web-tests/switch-rows.html" > "$WORK/switch.html" 2>/dev/null || true
RES=$(sed -n 's/.*<pre id="result">\([^<]*\)<\/pre>.*/\1/p' "$WORK/switch.html" | head -1)
if ! grep -q '<pre id="result">PASS</pre>' "$WORK/switch.html"; then
  echo "  результат:" >&2
  sed -n '/<pre id="result">/,/<\/pre>/p' "$WORK/switch.html" | sed 's/<[^>]*>//g; s/^/    /' >&2
  fail "сценарии ввода сумм не прошли"
fi
echo "  ✓ переключение строк ничего не сбрасывает и не сдвигает; удаление активной валюты переводит сумму; разбор сумм как на Android и iOS"

echo "→ 5/6 источники курсов: разбор ответов, порядок, резерв, перенос выбора"
"$CHROME" --headless --disable-gpu --no-sandbox --virtual-time-budget=40000 \
  --dump-dom "http://127.0.0.1:$PORT/tools/web-tests/sources.html" > "$WORK/sources.html" 2>/dev/null || true
if ! grep -q '<pre id="result">PASS</pre>' "$WORK/sources.html"; then
  echo "  результат:" >&2
  sed -n '/<pre id="result">/,/<\/pre>/p' "$WORK/sources.html" | sed 's/<[^>]*>//g; s/^/    /' >&2
  fail "источники курсов не прошли проверку"
fi
echo "  ✓ Coinbase первый, FXRatesAPI резерв; ответы разбираются; сохранённый выбор переносится"

echo "→ 6/6 поправка к курсу: полоса, пересчёт, переходы между строками, сброс"
"$CHROME" --headless --disable-gpu --no-sandbox --virtual-time-budget=60000 \
  --dump-dom "http://127.0.0.1:$PORT/tools/web-tests/adjust.html" > "$WORK/adjust.html" 2>/dev/null || true
if ! grep -q '^<pre id="result">PASS</pre>' "$WORK/adjust.html"; then
  echo "  результат:" >&2
  sed -n '/^<pre id="result">/,/<\/pre>/p' "$WORK/adjust.html" | sed 's/<[^>]*>//g; s/^/    /' >&2
  fail "поправка к курсу не прошла проверку"
fi
echo "  ✓ без поправки экран прежний; с поправкой полоса видна, базовая строка точная, остальные пересчитаны и помечены; переходы числа не двигают; сброс через 4 часа с сообщением"

echo "✓ Web smoke пройден"
