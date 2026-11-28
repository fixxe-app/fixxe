#!/usr/bin/env bash
#
# Smoke-тест iOS перед выпуском: гоняет тесты на симуляторе.
#
#   RatesLoadTests (UI) — холодный запуск обязан показать курсы, а кнопка
#     «обновить» обязана пережить частые нажатия и остаться живой.
#   AmountMemoryUITests (UI) — введённая сумма после закрытия: 12 ч по
#     умолчанию, 24 ч, «всегда», «пока приложение открыто».
#   FIXXETests (юнит) — переключение строк не сдвигает суммы. Это ловит баг,
#     который проявлялся только на Mac: там UI-тесты Apple не запускает,
#     поэтому поведение Mac воспроизведено прямо в тесте модели.
#
set -euo pipefail
cd "$(dirname "$0")/../ios"

SIM="${SIM:-iPhone 17 Pro}"
fail() { echo "✗ $*" >&2; exit 1; }

command -v xcodebuild >/dev/null || fail "нет xcodebuild"
command -v xcodegen  >/dev/null && xcodegen generate --quiet

# Чистое состояние — как у нового пользователя, без кэша курсов. Удаляем
# приложение именно с того симулятора, на котором пойдут тесты: «booted» мог
# оказаться другим, и тогда тесты брали старые сохранённые курсы — ровно так
# прошла бы незамеченной поломка 1.57, при которой курсы вообще не грузились.
UDID=$(xcrun simctl list devices available | grep -F "    $SIM (" | head -1 | grep -oE '[0-9A-F-]{36}')
[ -n "$UDID" ] || fail "нет симулятора «$SIM»"
xcrun simctl boot "$UDID" >/dev/null 2>&1 || true          # уже запущен — не ошибка
# bootstatus иногда виснет навсегда, хотя симулятор уже Booted (так release.sh простоял 9 ч):
# ждём не дольше 5 минут, потом верим списку устройств
if ! perl -e 'alarm shift; exec @ARGV' 300 xcrun simctl bootstatus "$UDID" -b >/dev/null 2>&1; then
  xcrun simctl list devices | grep -F "($UDID)" | grep -q '(Booted)' || fail "симулятор «$SIM» не загрузился"
fi
if xcrun simctl get_app_container "$UDID" com.karpinity.fixxe >/dev/null 2>&1; then
  xcrun simctl uninstall "$UDID" com.karpinity.fixxe || fail "не удалось удалить приложение с «$SIM»"
fi

LOG=$(mktemp -t smoke-ios)
echo "→ тесты на «$SIM»"
set +e
xcodebuild test \
  -scheme FIXXE \
  -destination "platform=iOS Simulator,id=$UDID" \
  -only-testing:FIXXEUITests/RatesLoadTests \
  -only-testing:FIXXEUITests/AmountMemoryUITests \
  -only-testing:FIXXETests \
  > "$LOG" 2>&1
code=$?
# -quiet прятал, какой тест упал и почему — печатаем именно это
grep -E "error: -\[|: error:|Test Case.*failed" "$LOG" | cut -c1-300 | head -20
set -e
[ "$code" -eq 0 ] || fail "тесты iOS не прошли (полный лог: $LOG)"
rm -f "$LOG"
echo "✓ iOS smoke пройден"
