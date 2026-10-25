#!/usr/bin/env bash
#
# Выпуск iPhone/iPad/Mac-версии FIXXE в App Store одной командой.
# Запускать ПОСЛЕ ./release.sh N — он ставит версию 1.N в ios/project.yml,
# гоняет тесты и ставит тег. Этот скрипт:
#   1. собирает и загружает сборку (testflight-ops ship --upload-only —
#      у Apple загрузка идёт только через TestFlight, но тестеры и бета-ревью
#      не нужны: сборка сразу идёт в App Store);
#   2. создаёт версию 1.N в App Store и прикрепляет сборку;
#   3. заливает тексты и «Что нового» на всех языках (store-locales → appstore/);
#      если какая-то локаль осталась пустой — заливает ещё раз;
#   4. отправляет на ревью с выпуском сразу после одобрения.
# Повторный запуск безопасен: готовые шаги пропускаются.
#
# Usage: ./tools/ship-ios.sh
set -euo pipefail
cd "$(dirname "$0")/.."

# shellcheck disable=SC1091
[ -f .release.local ] && . ./.release.local
export TESTFLIGHT_OPS_PROFILE="${TESTFLIGHT_OPS_PROFILE:-}"   # профиль с ключом ASC (см. образец)
PY=$HOME/.local/share/uv/tools/appstore-ops/bin/python   # в нём есть cryptography и yaml
VER=$(grep -E 'MARKETING_VERSION:' ios/project.yml | grep -oE '[0-9]+\.[0-9]+')
[ -n "$VER" ] || { echo "✗ не нашёл MARKETING_VERSION в ios/project.yml"; exit 1; }
TAG="v${VER#1.}"
git rev-parse -q --verify "refs/tags/$TAG" >/dev/null || git fetch -q --tags origin 2>/dev/null || true
git rev-parse -q --verify "refs/tags/$TAG" >/dev/null \
  || { echo "✗ нет тега $TAG — сначала ./release.sh ${VER#1.}"; exit 1; }
echo "▶ App Store: FIXXE $VER"

STATE=$($PY -I tools/asc_release.py state "$VER")
echo "  сейчас в App Store Connect: $STATE"
case "$STATE" in
  WAITING_FOR_REVIEW|IN_REVIEW|READY_FOR_SALE|PENDING_DEVELOPER_RELEASE)
    echo "✓ $VER уже отправлена ($STATE) — делать нечего"; exit 0 ;;
esac

# 1. Сборка — только если версии ещё нет (иначе сборка уже загружена).
#    «Что тестировать» для TestFlight не нужен, но пусть будет английским.
if [ "$STATE" = "NONE" ]; then
  NOTES=$(mktemp -t fixxe-notes)
  $PY -c "import yaml;print(yaml.safe_load(open('store-locales/en.yaml'))['whats_new'])" > "$NOTES"
  echo "→ 1/4 сборка и загрузка"
  (cd ios && testflight-ops ship --upload-only --yes --notes-file "$NOTES") | tail -4
  echo "→ 2/4 версия $VER в App Store"
  (cd ios && appstore-ops version create) | tail -1
else
  echo "→ 1-2/4 версия $VER уже есть ($STATE) — сборку не пересобираю"
fi

# 3. Тексты: из единого источника переводов в манифест, потом в App Store.
echo "→ 3/4 тексты и «Что нового»"
$PY tools/store-locales.py sync >/dev/null
for attempt in 1 2 3; do
  (cd ios && appstore-ops metadata push) > /tmp/fixxe-meta.log 2>&1 || true
  echo "  залито локалей: $(grep -c '^  metadata: ' /tmp/fixxe-meta.log || true)"
  # 4. Проверка и отправка; код 3 — остались пустые «Что нового»
  [ "$attempt" = 1 ] && echo "→ 4/4 проверка и отправка на ревью"
  set +e; $PY -I tools/asc_release.py finish "$VER"; code=$?; set -e
  [ "$code" = 0 ] && exit 0
  [ "$code" = 3 ] || exit "$code"
  echo "  заливаю тексты ещё раз (попытка $((attempt + 1)))"; sleep 20
done
echo "✗ «Что нового» так и не залилось во все локали — см. /tmp/fixxe-meta.log"; exit 1
