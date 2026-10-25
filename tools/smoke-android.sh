#!/usr/bin/env bash
#
# Smoke-тест Android перед выпуском: ловит поломки, которые не видно в сборке.
#
# Главная причина его существования: в 1.57 защита от частых нажатий отсекала
# самый первый запрос, приложение навсегда застревало на «Загрузка…», и
# ни один этап выпуска этого не заметил.
#
# Проверяет на живом эмуляторе, с чистыми данными (как у нового пользователя):
#   1. холодный старт загружает курсы и показывает их на экране — ровно 1 запрос
#   2. 12 быстрых нажатий «обновить» не дают ни одного лишнего запроса
#   3. после паузы кнопка «обновить» снова работает
#   4. без сети приложение считает по кэшу и честно пишет «офлайн»
#   5. свёрнутое приложение не ходит за курсами: автообновление в фоне стоит
#   6. клавиатуру можно убрать: клавишей «Готово», тапом по пустому месту,
#      значком в шапке — и при этом активная строка не меняется
#
set -euo pipefail
cd "$(dirname "$0")/.."

: "${ANDROID_HOME:=$HOME/android-sdk}"
: "${JAVA_HOME:=/opt/homebrew/opt/openjdk@17}"
export ANDROID_HOME JAVA_HOME
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"

PKG=com.karpinity.fixxe
ACT=$PKG/com.example.currencyconverter.MainActivity
TAG=FIXXE_FETCH
WORK=$(mktemp -d)
# Что бы ни случилось, сеть на эмуляторе возвращаем: иначе после упавшего
# прогона все следующие падали бы уже на первом шаге.
net_on() { adb shell svc wifi enable >/dev/null 2>&1; adb shell svc data enable >/dev/null 2>&1; true; }
trap 'net_on; rm -rf "$WORK"' EXIT
fail() {
  echo "✗ $*" >&2
  echo "  что на экране:" >&2
  grep -o 'text="[^"]\+"' "$WORK/ui.txt" 2>/dev/null | head -8 | sed 's/^/    /' >&2 || true
  echo "  запросов в логе: $(fetches)" >&2
  exit 1
}

command -v adb >/dev/null || fail "adb не найден (ANDROID_HOME=$ANDROID_HOME)"
# У каждой команды adb — предел времени. Если эмулятор закроется посреди
# прогона, adb ждёт его вечно, и вместе с тестом навсегда повис бы release.sh.
ADB_BIN=$(command -v adb)
adb() { perl -e 'alarm shift; exec @ARGV' 90 "$ADB_BIN" "$@"; }
adb devices | grep -q "device$" || fail "нет запущенного эмулятора/устройства: запусти, например, 'emulator -avd fixxe &'"

# Свежезагруженный эмулятор иногда показывает «не отвечает» от системного
# Digital Wellbeing — окно перекрывает приложение, и тест падал не из-за нас
# (выпуски 1.62 и 1.64). На тестовом эмуляторе это приложение не нужно.
# Чужое окно ANR закрываем; если не отвечает сама FIXXE — тест падает как надо.
adb shell pm disable-user --user 0 com.google.android.apps.wellbeing >/dev/null 2>&1 || true
clear_foreign_anr() {
  local w; w=$(adb shell dumpsys window 2>/dev/null | grep -m1 mCurrentFocus || true)
  case "$w" in
    *"Not Responding: $PKG"*) ;;
    *"Not Responding: "*)
      pkg=$(echo "$w" | sed -E 's/.*Not Responding: ([^}]+)}.*/\1/')
      echo "  (закрываю зависшее системное приложение $pkg)"
      adb shell am force-stop "$pkg" >/dev/null 2>&1 || true
      adb shell input keyevent KEYCODE_BACK >/dev/null 2>&1 || true; sleep 2 ;;
  esac
}
clear_foreign_anr
echo "→ собираю debug"
./gradlew assembleDebug -q
adb install -r app/build/outputs/apk/debug/app-debug.apk >/dev/null
# Снимок экрана и логов кладём в файлы и ищем уже по ним. Через конвейер
# нельзя: grep -q закрывает его на первом совпадении, adb получает SIGPIPE,
# и pipefail объявляет упавшей проверку, которая на самом деле нашла текст.
# grep -c при нуле совпадений печатает «0» и выходит с ошибкой — `|| echo 0`
# допечатывал второй ноль, и в счётчике оказывалось «0⏎0».
fetches() { adb logcat -d -s "$TAG" > "$WORK/log.txt" 2>/dev/null || true
            local n; n=$(grep -c "rates fetch" "$WORK/log.txt" 2>/dev/null || true)
            echo "${n:-0}"; }
# Дамп через файл на устройстве: вывод в /dev/tty иногда приходит пустым.
screen()  { adb shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1 || true
            adb shell cat /sdcard/ui.xml 2>/dev/null | tr '>' '\n' > "$WORK/ui.txt" || true; }
onscreen() { grep -q "$1" "$WORK/ui.txt" 2>/dev/null; }
wake()    { adb shell input keyevent KEYCODE_WAKEUP >/dev/null 2>&1 || true
            adb shell wm dismiss-keyguard >/dev/null 2>&1 || true; }

# ── 1. холодный старт: ни кэша, ни настроек ────────────────────────────────
echo "→ 1/8 холодный старт"
adb shell pm clear $PKG >/dev/null
adb logcat -c
wake
adb shell am start -n $ACT >/dev/null
for i in $(seq 1 25); do
  sleep 1
  screen
  onscreen "1 EUR = " && break
done
onscreen "1 EUR = " || fail "курсы не появились за 25 с после чистой установки (экран застрял на загрузке?)"
# Чтение журнала через adb изредка возвращается пустым — ждём, пока запрос
# в нём появится, а затем убеждаемся, что он так и остался единственным.
n=0
for i in $(seq 1 10); do n=$(fetches); [ "$n" -ge 1 ] && break; sleep 1; done
sleep 2; n=$(fetches)
[ "$n" -eq 1 ] || fail "холодный старт сделал $n запросов вместо одного"
echo "  ✓ курсы на экране, запросов: 1"

# ── 2. частые нажатия не должны долбить API ────────────────────────────────
echo "→ 2/8 защита от частых нажатий"
screen
BTN=$(grep -o 'resource-id="[^"]*btnRefresh"[^$]*bounds="\[[0-9]*,[0-9]*\]\[[0-9]*,[0-9]*\]"' "$WORK/ui.txt" | grep -o 'bounds="\[[0-9]*,[0-9]*\]\[[0-9]*,[0-9]*\]"' | head -1)
[ -n "$BTN" ] || fail "не нашёл кнопку «обновить» на экране"
read -r X1 Y1 X2 Y2 <<<"$(echo "$BTN" | grep -o '[0-9]\+' | paste -sd' ' -)"
TX=$(( (X1 + X2) / 2 )); TY=$(( (Y1 + Y2) / 2 ))
# Тротлинг считает 10 секунд от последнего запроса. Чтобы проверка не
# зависела от того, сколько прошло со старта и как быстро отвечает adb:
# ждём, пока окно точно закроется, первым нажатием открываем новое (оно
# законно даёт ровно один запрос), а остальные 11 шлём одной командой —
# они обязаны уложиться в окно и не дать ни одного.
sleep 11
base=$(fetches)
adb shell input tap $TX $TY; sleep 1
opened=$(fetches)
[ "$opened" -eq $((base + 1)) ] || fail "нажатие после паузы дало $((opened-base)) запросов вместо одного"
t0=$SECONDS
adb shell "for i in 1 2 3 4 5 6 7 8 9 10 11; do input tap $TX $TY; done"
spent=$(( SECONDS - t0 ))
[ "$spent" -lt 9 ] || fail "11 нажатий заняли ${spent} с — дольше окна тротлинга, проверка была бы нечестной"
sleep 3
after=$(fetches)
[ "$after" -eq "$opened" ] || fail "11 быстрых нажатий дали $((after-opened)) лишних запросов — тротлинг не работает"
echo "  ✓ 1 нажатие → 1 запрос, следующие 11 за ${spent} с → 0 лишних"

# ── 3. но кнопка не должна умирать насовсем ────────────────────────────────
echo "→ 3/8 кнопка жива после паузы"
sleep 11
adb shell input tap $TX $TY
sleep 6
[ "$(fetches)" -gt "$after" ] || fail "после паузы кнопка «обновить» не сработала — запрос не ушёл"
echo "  ✓ после паузы запрос уходит"

# ── 4. без сети работаем по кэшу ───────────────────────────────────────────
echo "→ 4/8 поведение без сети"
adb shell svc wifi disable; adb shell svc data disable
# Убеждаемся, что сеть действительно пропала: если команда не сработала,
# приложение возьмёт свежие курсы, и проверка «работает по кэшу» прошла бы зря.
for i in $(seq 1 10); do
  adb shell ping -c1 -W1 8.8.8.8 >/dev/null 2>&1 || break
  sleep 1
done
adb shell ping -c1 -W1 8.8.8.8 >/dev/null 2>&1 && fail "не удалось отключить сеть на эмуляторе"
adb shell am force-stop $PKG; wake; adb shell am start -n $ACT >/dev/null
sleep 10
screen
offline_ok=0; onscreen "1 EUR = " && onscreen "Offline" && offline_ok=1
net_on
[ "$offline_ok" -eq 1 ] || fail "без сети приложение не показало курсы из кэша с пометкой «Offline»"
echo "  ✓ без сети считает по кэшу и пишет «Offline»"

echo "→ 5/8 в фоне автообновление стоит"
# Ждём запись в журнале с опросом, а не фиксированной паузой: медленному
# эмулятору иногда не хватало трёх секунд, и тест падал через раз.
wait_log() {   # wait_log <текст> <файл>
  for i in $(seq 1 15); do
    adb logcat -d -s "$TAG" > "$2" 2>/dev/null || true
    grep -q "$1" "$2" && return 0
    sleep 1
  done
  return 1
}
adb logcat -c
adb shell input keyevent KEYCODE_HOME
wait_log "auto-refresh off" "$WORK/bg.txt" \
  || fail "после сворачивания автообновление не остановилось — свёрнутое приложение продолжало бы ходить в сеть"
adb logcat -c
wake; adb shell am start -n $ACT >/dev/null
wait_log "auto-refresh on" "$WORK/fg.txt" || fail "после возврата автообновление не включилось"
echo "  ✓ свернули — остановилось, вернули — включилось"

echo "→ 6/8 клавиатура убирается"
# В эмуляторе включена аппаратная клавиатура (hw.keyboard=yes): стоит нажать
# клавишу на клавиатуре Mac, и Android прячет экранную — шаг проверял бы
# пустоту. Просим показывать экранную и при подключённой физической.
adb shell settings put secure show_ime_with_hard_keyboard 1
# Три валюты, чтобы под списком было пустое место и при открытой клавиатуре
adb shell am force-stop $PKG; adb shell pm clear $PKG >/dev/null
printf '%s\n' "<?xml version='1.0' encoding='utf-8' standalone='yes' ?>" "<map>" \
  '    <string name="currencies">EUR,USD,RSD</string>' '    <boolean name="lang_initialized" value="true" />' "</map>" > "$WORK/p3.xml"
adb push "$WORK/p3.xml" /data/local/tmp/fixxe-p3.xml >/dev/null; adb shell chmod 644 /data/local/tmp/fixxe-p3.xml
adb shell "run-as $PKG sh -c 'mkdir -p shared_prefs && cp /data/local/tmp/fixxe-p3.xml shared_prefs/axe_prefs.xml'"
wake; adb shell am start -n $ACT >/dev/null
for i in $(seq 1 25); do sleep 1; screen; onscreen "1 EUR = " && break; done
onscreen "1 EUR = " || fail "курсы не загрузились"
kb_shown() { adb shell dumpsys input_method > "$WORK/ime.txt" 2>/dev/null || true; grep -q "mInputShown=true" "$WORK/ime.txt"; }
bounds() { grep "$1" "$WORK/ui.txt" | sed -n "${2:-1}p" | grep -o 'bounds="\[[0-9]*,[0-9]*\]\[[0-9]*,[0-9]*\]"' | grep -o '[0-9]\+' | paste -sd' ' -; }
screen; read -r x1 y1 x2 y2 <<<"$(bounds etAmount 2)"; UX=$(( (x1+x2)/2 )); UY=$(( (y1+y2)/2 ))
open_usd() { adb shell input tap $UX $UY; sleep 1.5; kb_shown || fail "клавиатура не открылась по тапу на сумму"; }
still_usd() { screen; grep -q 'text="1 USD = ' "$WORK/ui.txt" || fail "после закрытия клавиатуры активной стала другая строка"; }
# «Готово». Без imeOptions на этом месте была «Далее», и она прыгала в соседнюю строку
open_usd; adb shell input keyevent KEYCODE_ENTER; sleep 1.5
kb_shown && fail "клавиша «Готово» не закрыла клавиатуру"
still_usd
# тап по пустому месту — между последней строкой и подвалом (не по самой клавиатуре!)
open_usd; screen
read -r _ _ _ RB <<<"$(bounds 'id/recyclerView')"
LB=$(grep 'etAmount' "$WORK/ui.txt" | grep -o '\]\[[0-9]*,[0-9]*\]' | grep -o ',[0-9]*' | tr -d , | sort -n | tail -1)
[ $(( RB - LB )) -gt 120 ] || fail "под списком нет пустого места для проверки (низ строки $LB, низ списка $RB)"
adb shell input tap $(( (x1+x2)/2 )) $(( (LB + 60 + RB) / 2 )); sleep 1.5
kb_shown && fail "тап по пустому месту не закрыл клавиатуру"
still_usd
# ЭКСПЕРИМЕНТ: значок в шапке (оставлять ли его — решает владелец)
open_usd; screen
B=$(bounds 'id/btnHideKeyboard'); [ -n "$B" ] || fail "при открытой клавиатуре нет значка «спрятать клавиатуру»"
read -r a b c d <<<"$B"; adb shell input tap $(( (a+c)/2 )) $(( (b+d)/2 )); sleep 1.5
kb_shown && fail "значок в шапке не закрыл клавиатуру"
screen; grep -q 'id/btnHideKeyboard' "$WORK/ui.txt" && fail "значок остался на экране после закрытия клавиатуры"
still_usd
echo "  ✓ «Готово», тап по пустому месту и значок в шапке закрывают клавиатуру; активная строка не меняется"

echo "→ 7/8 после клавиатуры список встаёт на место"
# Клавиатура прокручивает список, чтобы строка ввода была видна. После её
# закрытия список раньше так и оставался сдвинутым вверх. Валют много, чтобы
# нижнюю строку клавиатура точно накрывала и список был вынужден сдвинуться.
adb shell am force-stop $PKG; adb shell pm clear $PKG >/dev/null
printf '%s\n' "<?xml version='1.0' encoding='utf-8' standalone='yes' ?>" "<map>" \
  '    <string name="currencies">EUR,USD,RSD,GBP,CHF,JPY,CNY,TRY,GEL,ILS,PLN,CZK</string>' \
  '    <boolean name="lang_initialized" value="true" />' "</map>" > "$WORK/p12.xml"
adb push "$WORK/p12.xml" /data/local/tmp/fixxe-p12.xml >/dev/null; adb shell chmod 644 /data/local/tmp/fixxe-p12.xml
adb shell "run-as $PKG sh -c 'mkdir -p shared_prefs && cp /data/local/tmp/fixxe-p12.xml shared_prefs/axe_prefs.xml'"
wake; adb shell am start -n $ACT >/dev/null
for i in $(seq 1 25); do sleep 1; screen; onscreen "1 EUR = " && break; done
onscreen "1 EUR = " || fail "курсы не загрузились"
# «как стоит список» — код и место первой видимой строки
layout() { screen; grep 'id/tvCode' "$WORK/ui.txt" | head -1 | grep -oE '(text="[A-Z]+"|bounds="[^"]*")' | paste -sd' ' -; }
BEFORE=$(layout)
# нижняя целиком видимая строка ввода
LAST=$(grep 'id/etAmount' "$WORK/ui.txt" | grep -o 'bounds="\[[0-9]*,[0-9]*\]\[[0-9]*,[0-9]*\]"' | grep -o '[0-9]\+' | paste - - - - | tail -1)
read -r lx1 ly1 lx2 ly2 <<<"$LAST"
open_last() {
  adb shell input tap $(( (lx1+lx2)/2 )) $(( (ly1+ly2)/2 )); sleep 2
  kb_shown || fail "клавиатура не открылась по тапу на нижнюю сумму"
  [ "$(layout)" != "$BEFORE" ] || fail "клавиатура не сдвинула список — проверять нечего (строка не у низа?)"
}
back_in_place() {   # $1 — чем закрывали
  sleep 1.5; kb_shown && fail "$1: клавиатура не закрылась"
  NOW=$(layout)
  [ "$NOW" = "$BEFORE" ] || fail "$1: список остался сдвинутым (было: $BEFORE; стало: $NOW)"
}
open_last; adb shell input keyevent KEYCODE_ENTER; back_in_place "«Готово»"
open_last; adb shell input keyevent KEYCODE_BACK;  back_in_place "системное «Назад»"
open_last; screen; read -r a b c d <<<"$(bounds 'id/btnHideKeyboard')"
adb shell input tap $(( (a+c)/2 )) $(( (b+d)/2 )); back_in_place "значок в шапке"
echo "  ✓ после «Готово», «Назад» и значка в шапке список стоит как до клавиатуры"

echo "→ 8/8 тап по любому месту карточки открывает ввод"
# Тач-экран: целиться в само число незачем. Тап по названию валюты в
# неактивной строке должен сделать её активной, открыть клавиатуру и выделить
# число целиком — набранная цифра заменяет его, а не дописывается.
adb shell am force-stop $PKG
adb shell "run-as $PKG sh -c 'cp /data/local/tmp/fixxe-p3.xml shared_prefs/axe_prefs.xml'"
wake; adb shell am start -n $ACT >/dev/null
for i in $(seq 1 25); do sleep 1; screen; onscreen "1 EUR = " && break; done
onscreen "1 EUR = " || fail "курсы не загрузились"
read -r a b c d <<<"$(bounds 'id/tvName' 3)"
[ -n "$d" ] || fail "нет названия третьей валюты на экране"
adb shell input tap $(( (a+c)/2 )) $(( (b+d)/2 )); sleep 1.5
kb_shown || fail "тап по названию валюты не открыл клавиатуру"
screen; onscreen 'text="1 RSD = ' || fail "тап по названию RSD не сделал её строку активной"
adb shell input text 5; sleep 1; screen
T=$(grep 'id/etAmount' "$WORK/ui.txt" | sed -n 3p | grep -o 'text="[^"]*"')
[ "$T" = 'text="5"' ] || fail "после тапа по карточке число не выделено целиком: ввод «5» дал $T"
adb shell input keyevent KEYCODE_BACK
echo "  ✓ тап по названию валюты: строка активна, клавиатура открыта, число выделено целиком"

echo "✓ Android smoke пройден"
