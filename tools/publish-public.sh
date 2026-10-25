#!/usr/bin/env bash
#
# Снимок исходников в открытый репозиторий.
#
# Рабочий репозиторий остаётся закрытым: в его истории — рабочие адреса
# авторов и внутренние документы (store-assets/PUBLISHING.md). Наружу уходит
# чистое дерево одним коммитом на версию, от имени FIXXE_PUBLIC_AUTHOR,
# после проверки, что в нём нет ничего лишнего: ни чужих логинов, ни адресов
# серверов, ни путей с этого Mac, ни ключей.
#
# После push — релиз vN на GitHub с APK этой версии (web/FIXXE.apk, собран
# release.sh): так его находят и люди, и каталоги вроде IzzyOnDroid. Нужен
# токен аккаунта (FIXXE_GITHUB_TOKEN в .release.local) — SSH-ключ умеет
# только пушить код.
#
# Usage: tools/publish-public.sh            # собрать снимок и проверить (без push)
#        tools/publish-public.sh --push     # и отправить в FIXXE_PUBLIC_REMOTE + релиз с APK
set -euo pipefail
cd "$(dirname "$0")/.."
MAIN=$(pwd)
# shellcheck disable=SC1091
[ -f .release.local ] && . ./.release.local
OUT="${FIXXE_PUBLIC_DIR:-$HOME/fixxe-public}"
AUTHOR="${FIXXE_PUBLIC_AUTHOR:-Karpinity <noreply@example.com>}"
REMOTE="${FIXXE_PUBLIC_REMOTE:-}"
NAME="${AUTHOR%% <*}"; EMAIL="${AUTHOR#*<}"; EMAIL="${EMAIL%>}"
N=$(grep -oE 'versionCode = [0-9]+' app/build.gradle.kts | grep -oE '[0-9]+')

# 1. Снимок последнего коммита (всё, что вне git — ключи, APK, .release.local, — не попадает)
mkdir -p "$OUT"
[ -d "$OUT/.git" ] || git init -q -b main "$OUT"
find "$OUT" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
git archive HEAD | tar x -C "$OUT"
# внутренняя документация издателя — не для публикации
rm -f "$OUT/store-assets/PUBLISHING.md"
# контакт для App Review (имя, почта, телефон живого человека) — только Apple
sed -i '' -E '/^  (first_name|last_name|email|phone):/d' "$OUT/appstore/manifest.yaml"

# 2. Ничего лишнего. Здесь — только общие признаки (ключи, пути этого Mac,
#    адреса серверов). Имена людей, почты, хосты и прочее личное — в
#    FIXXE_PUBLIC_DENY в .release.local: иначе список запрещённых слов сам
#    оказался бы в открытом репозитории вместе со всем, что он запрещает.
#    Скобки вроде [s] — чтобы сама эта строка под свои шаблоны не подходила:
#    скрипт тоже уходит в снимок и проверяется наравне со всем.
PATTERNS='/User[s]/[a-z]+|ubunt[u]@|[a-z]+@[0-9]{1,3}(\.[0-9]{1,3}){3}|BEGIN (RSA |EC )?PRIVAT[E] KEY|AIz[a][0-9A-Za-z_-]{20,}|gh[p]_[A-Za-z0-9]{20,}|"private_ke[y]"'
[ -n "${FIXXE_PUBLIC_DENY:-}" ] && PATTERNS="$PATTERNS|$FIXXE_PUBLIC_DENY"
if BAD=$(grep -rnI -E "$PATTERNS" "$OUT" --exclude-dir=.git); then
  echo "✗ в снимке осталось лишнее — публиковать нельзя:"; echo "$BAD" | cut -c1-160; exit 1
fi
for f in "$OUT"/**/*.jks "$OUT"/**/*.p8 "$OUT"/**/*.p12 "$OUT"/**/service-account*.json "$OUT"/keystore.properties; do
  [ -e "$f" ] && { echo "✗ секретный файл в снимке: $f"; exit 1; }
done
echo "✓ снимок 1.$N чистый: $(find "$OUT" -type f ! -path '*/.git/*' | wc -l | tr -d ' ') файлов в $OUT"

# 3. Коммит от имени издателя
cd "$OUT"
git add -A
if git diff --cached --quiet; then
  echo "ℹ изменений с прошлого снимка нет"
else
  git -c user.name="$NAME" -c user.email="$EMAIL" commit -q -m "FIXXE 1.$N" --author="$AUTHOR"
  echo "✓ коммит «FIXXE 1.$N» от $AUTHOR"
fi
git tag -f "v$N" >/dev/null

# 4. Push — только по явной просьбе и только если репозиторий задан
if [ "${1:-}" = "--push" ]; then
  [ -n "$REMOTE" ] || { echo "✗ FIXXE_PUBLIC_REMOTE не задан в .release.local"; exit 1; }
  git remote get-url origin >/dev/null 2>&1 || git remote add origin "$REMOTE"
  git push -q -u origin main
  # тег текущей версии указывает на её последний снимок (внутри одной версии
  # снимок может пересобираться); теги прошлых версий не двигаются
  git push -q -f origin "refs/tags/v$N"
  echo "✓ отправлено в $REMOTE"

  # 5. Релиз на GitHub с APK этой версии
  TOKEN="${FIXXE_GITHUB_TOKEN:-}"
  REPO=$(echo "$REMOTE" | sed -E 's#.*[:/]([^/]+/[^/]+)$#\1#; s#\.git$##')
  APK="$MAIN/web/FIXXE.apk"
  AAPT=$(ls -d "${ANDROID_HOME:-$HOME/android-sdk}"/build-tools/*/aapt2 2>/dev/null | tail -1)
  APK_N=$([ -f "$APK" ] && [ -n "$AAPT" ] && "$AAPT" dump badging "$APK" 2>/dev/null | grep -oE "versionCode='[0-9]+'" | grep -oE '[0-9]+' || true)
  if [ -z "$TOKEN" ]; then
    echo "ℹ релиз на GitHub не создан: нет FIXXE_GITHUB_TOKEN в .release.local"
  elif [ "$APK_N" != "$N" ]; then
    echo "⚠ релиз на GitHub не создан: web/FIXXE.apk — версия ${APK_N:-?}, а нужна $N (собери release.sh)"
  else
    NOTES="$MAIN/store-release-notes.txt"
    if GH_TOKEN="$TOKEN" gh release view "v$N" -R "$REPO" >/dev/null 2>&1; then
      GH_TOKEN="$TOKEN" gh release upload "v$N" "$APK#FIXXE-1.$N.apk" -R "$REPO" --clobber >/dev/null
      echo "✓ релиз v$N уже был — APK обновлён"
    else
      GH_TOKEN="$TOKEN" gh release create "v$N" "$APK#FIXXE-1.$N.apk" -R "$REPO" \
        -t "FIXXE 1.$N" -F "$NOTES" --latest >/dev/null
      echo "✓ релиз FIXXE 1.$N с APK: https://github.com/$REPO/releases/tag/v$N"
    fi
  fi
else
  echo "  push не делался (добавь --push, когда репозиторий на GitHub создан)"
fi
