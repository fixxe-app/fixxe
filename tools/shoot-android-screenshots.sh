#!/usr/bin/env bash
#
# Скриншоты Google Play с живого эмулятора.
#
#   tools/shoot-android-screenshots.sh phone    # → play/graphics/en-US/phone-N.png
#   tools/shoot-android-screenshots.sh tablet   # → play/graphics/en-US/tablet-N.png
#
# Запускать на эмуляторе нужного размера: телефон 1080×1920 (AVD fixxe),
# планшет 2560×1600 (AVD fixxe-tablet). Скрипт ставит отладочную сборку,
# задаёт список валют и настройки, вводит сумму и снимает кадры:
#   1 главный экран, светлая тема   2 то же, тёмная тема
#   3 добавление валюты             4 настройки   5 пояснение про курсы
#
# Раньше кадры снимали руками, и они отстали от приложения на полтора
# десятка версий: старая шапка, «ver. 1.44», настройки без оформления.
set -euo pipefail
cd "$(dirname "$0")/.."

KIND="${1:-phone}"
OUT="play/graphics/en-US"
: "${ANDROID_HOME:=$HOME/android-sdk}"; : "${JAVA_HOME:=/opt/homebrew/opt/openjdk@17}"
export ANDROID_HOME JAVA_HOME PATH="$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$PATH"
PKG=com.karpinity.fixxe; ACT=$PKG/com.example.currencyconverter.MainActivity
WORK=$(mktemp -d)
fail() { echo "✗ $*" >&2; exit 1; }
demo() { adb shell am broadcast -a com.android.systemui.demo -e command "$@" >/dev/null; }
cleanup() { demo exit >/dev/null 2>&1 || true; rm -rf "$WORK"; }
trap cleanup EXIT

adb devices | grep -q "device$" || fail "нет запущенного эмулятора"
SIZE=$(adb shell wm size | grep -oE '[0-9]+x[0-9]+' | tail -1)
case "$KIND" in
  phone)  [ "$SIZE" = "1080x1920" ] || fail "для телефона нужен эмулятор 1080x1920, а этот $SIZE" ;;
  tablet) [ "$SIZE" = "1600x2560" ] || [ "$SIZE" = "2560x1600" ] || fail "для планшета нужен 2560x1600, а этот $SIZE" ;;
  *) fail "первый аргумент: phone или tablet" ;;
esac

echo "→ сборка"
./gradlew assembleDebug -q
adb install -r app/build/outputs/apk/debug/app-debug.apk >/dev/null

# Строка состояния как на рекламных кадрах: 09:41, полный заряд, без уведомлений
adb shell settings put global sysui_demo_allowed 1
demo enter
demo clock -e hhmm 0941
demo battery -e level 100 -e plugged false
demo network -e wifi show -e level 4
demo network -e mobile show -e datatype none -e level 4
demo notifications -e visible false
[ "$KIND" = tablet ] && adb shell settings put system user_rotation 1 >/dev/null 2>&1 || true

screen() { adb shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1 || true
           adb shell cat /sdcard/ui.xml 2>/dev/null | tr '>' '\n' > "$WORK/ui.txt" || true
           # Только что загруженный эмулятор любит подвешивать системные службы,
           # и поверх всего встаёт окно «… isn't responding». Это не наше
           # приложение — жмём «Подождать» и снимаем экран заново.
           if grep -q 'resource-id="android:id/aerr_wait"' "$WORK/ui.txt"; then
             local b; b=$(grep 'resource-id="android:id/aerr_wait"' "$WORK/ui.txt" | grep -o 'bounds="\[[0-9]*,[0-9]*\]\[[0-9]*,[0-9]*\]"' | grep -o '[0-9]\+' | paste -sd' ' -)
             read -r x1 y1 x2 y2 <<<"$b"; adb shell input tap $(( (x1+x2)/2 )) $(( (y1+y2)/2 )); sleep 2
             adb shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1 || true
             adb shell cat /sdcard/ui.xml 2>/dev/null | tr '>' '\n' > "$WORK/ui.txt" || true
           fi; }
center() {  # center <resource-id>  → «x y» центра первого элемента
  screen
  local b; b=$(grep "resource-id=\"$PKG:id/$1\"" "$WORK/ui.txt" | head -1 | grep -o 'bounds="\[[0-9]*,[0-9]*\]\[[0-9]*,[0-9]*\]"' | grep -o '[0-9]\+' | paste -sd' ' -)
  [ -n "$b" ] || fail "нет элемента $1 на экране"
  read -r x1 y1 x2 y2 <<<"$b"; echo "$(( (x1+x2)/2 )) $(( (y1+y2)/2 ))"
}
# center вызывается в подстановке, и его fail завершал только её — скрипт
# шёл дальше и слал пустой тап. Проверяем результат здесь.
tap_id() { local c; c=$(center "$1") || fail "нет элемента $1 на экране"
           read -r x y <<<"$c"; adb shell input tap "$x" "$y"; sleep 1.5; }
# «Назад» в окне с полем поиска сначала прячет клавиатуру, а окно остаётся:
# жмём, пока снова не появится главный экран
close_dialog() { for i in 1 2 3; do adb shell input keyevent KEYCODE_BACK; sleep 1
                   screen; grep -q "resource-id=\"$PKG:id/btnSettings\"" "$WORK/ui.txt" && return 0; done
                 fail "окно не закрылось"; }
shot()   { adb exec-out screencap -p > "$OUT/$KIND-$1.png"; echo "  ✓ $KIND-$1.png"; }

start_with_theme() {  # start_with_theme <0|1|2>
  adb shell am force-stop $PKG
  adb shell pm clear $PKG >/dev/null
  # настройки — до первого запуска: список валют, тема, пробел между разрядами
  cat > "$WORK/prefs.xml" <<XML
<?xml version='1.0' encoding='utf-8' standalone='yes' ?>
<map>
    <!-- без крипты: основной источник её не знает, и строка просто не появилась бы -->
    <string name="currencies">EUR,USD,GBP,CHF,JPY,RSD,GEL,RUB</string>
    <int name="theme" value="$1" />
    <int name="grouping" value="1" />
    <int name="decimal_places" value="0" />
    <boolean name="lang_initialized" value="true" />
</map>
XML
  adb push "$WORK/prefs.xml" /data/local/tmp/fixxe-prefs.xml >/dev/null
  adb shell chmod 644 /data/local/tmp/fixxe-prefs.xml
  adb shell "run-as $PKG sh -c 'mkdir -p shared_prefs && cp /data/local/tmp/fixxe-prefs.xml shared_prefs/axe_prefs.xml'"
  adb shell cmd locale set-app-locales $PKG --locales en >/dev/null 2>&1 || true
  adb shell am start -n $ACT >/dev/null
  for i in $(seq 1 25); do sleep 1; screen; grep -q '1 EUR = ' "$WORK/ui.txt" && break; done
  grep -q '1 EUR = ' "$WORK/ui.txt" || fail "курсы не загрузились"
  # 100 EUR — на круглой сумме видно и разряды, и умное округление крипты
  tap_id etAmount
  adb shell input keyevent KEYCODE_MOVE_END
  for i in 1 2 3 4 5 6; do adb shell input keyevent KEYCODE_DEL; done
  adb shell input text 100
  adb shell input keyevent KEYCODE_BACK; sleep 1.5      # спрятать клавиатуру
}

echo "→ кадры ($KIND)"
start_with_theme 1;  shot 1
start_with_theme 2;  shot 2
start_with_theme 1
tap_id btnAddCurrency; shot 3; close_dialog
tap_id btnSettings;    shot 4; close_dialog
screen
INFO=$(grep -o 'text="Mid-market rates[^"]*"[^$]*bounds="\[[0-9]*,[0-9]*\]\[[0-9]*,[0-9]*\]"' "$WORK/ui.txt" | grep -o 'bounds=.*' | grep -o '[0-9]\+' | paste -sd' ' - || true)
[ -n "$INFO" ] || fail "нет ссылки «Mid-market rates»"
read -r x1 y1 x2 y2 <<<"$INFO"; adb shell input tap $(( (x1+x2)/2 )) $(( (y1+y2)/2 )); sleep 1.5
shot 5
adb shell input keyevent KEYCODE_BACK
[ "$KIND" = tablet ] && adb shell settings put system user_rotation 0 >/dev/null 2>&1 || true
echo "✓ готово: $OUT/$KIND-1..5.png"
