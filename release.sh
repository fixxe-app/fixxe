#!/usr/bin/env bash
#
# Единая точка выпуска релиза FIXXE.
# Всё выводится из ОДНОГО числа N → рассинхрон versionCode/тега невозможен.
#
# ВАЖНО: всё, что видит пользователь магазина, должно быть НА АНГЛИЙСКОМ — в том числе
# «что нового». play-ops по умолчанию берёт текст последнего коммита, а коммиты у нас
# русские, поэтому заметки для магазинов лежат в store-release-notes.txt и передаются
# в ship явно через --notes-file (см. подсказку в конце скрипта).
#
# APK наружу НЕ публикуется: приложение распространяется только через Google Play
# (Android developer verification требует регистрации ключей для раздачи вне Play,
# а отладочный ключ для этого не годится). Вне магазина остаётся PWA:
# публичный адрес https://telebimmer.com/fixxe/ , зеркало — см. .release.local.
#
# Usage:
#   ./release.sh            # авто-инкремент: берёт текущий versionCode и +1
#   ./release.sh 8          # явно выпустить версию 8
#   ./release.sh 8 "текст"  # с произвольным описанием релиза
#
set -euo pipefail

cd "$(dirname "$0")"

# Всё, что относится к НАШЕЙ инфраструктуре (ключ подписи, зеркало сайта),
# лежит в .release.local — он вне git, репозиторий открытый. Без него скрипт
# работает, но пропускает подпись APK и деплой зеркала. Образец: .release.local.example
# shellcheck disable=SC1091
[ -f .release.local ] && . ./.release.local
FIXXE_UPLOAD_KEYSTORE="${FIXXE_UPLOAD_KEYSTORE:-}"       # путь к upload.jks
FIXXE_KEYSTORE_PASSWORD="${FIXXE_KEYSTORE_PASSWORD:-}"   # пароль к нему (или команда, см. образец)
FIXXE_MIRROR_SSH="${FIXXE_MIRROR_SSH:-}"                 # user@host зеркала PWA
FIXXE_MIRROR_DIR="${FIXXE_MIRROR_DIR:-/var/www/fixe}"    # каталог сайта на зеркале
FIXXE_MIRROR_URL="${FIXXE_MIRROR_URL:-}"                 # его адрес, для сообщения

# 0. Тексты, которые увидит пользователь магазина, обязаны быть английскими.
#    Проверяем до сборки: дешевле поймать здесь, чем вычищать из Play и App Store.
python3 - <<'PYCHK' || exit 1
import re, sys, pathlib
CYR = re.compile('[\u0400-\u04FF]')

def user_visible(path, line):
    """Комментарии — для разработчика, пользователь магазина их не видит."""
    if path.suffix == ".yaml":
        line = re.sub(r"(^|\s)#.*$", "", line)
    return line

bad = []
# Заметки к версии уезжают в английскую карточку как есть.
p = pathlib.Path("store-release-notes.txt")
if p.exists():
    for i, line in enumerate(p.read_text(encoding="utf-8").splitlines(), 1):
        if CYR.search(line):
            bad.append(f"  store-release-notes.txt:{i}: {line.strip()[:70]}")
# В манифестах магазинов кириллица законна — но только не в en-US:
# её карточку видят все страны, у которых нет своей.
for f in ["appstore/manifest.yaml", "play/manifest.yaml"]:
    p = pathlib.Path(f)
    if not p.exists():
        continue
    in_en = False
    for i, line in enumerate(p.read_text(encoding="utf-8").splitlines(), 1):
        # имя локали может быть в кавычках: 'no' YAML иначе прочёл бы как false
        m = re.match(r"""^  ['"]?([A-Za-z]{2}(?:-[A-Za-z0-9]+)?)['"]?:\s*$""", line)
        if m:
            in_en = m.group(1).startswith("en")
        if in_en and CYR.search(user_visible(p, line)):
            bad.append(f"  {f}:{i}: {line.strip()[:70]}")
if bad:
    print("\u2717 Кириллица там, где магазин ждёт английский:")
    print("\n".join(bad))
    sys.exit(1)
PYCHK

GRADLE="app/build.gradle.kts"

# Текущий versionCode из gradle
CURRENT=$(grep -E 'versionCode = [0-9]+' "$GRADLE" | grep -oE '[0-9]+')

# Новый номер: аргумент или +1
N="${1:-$((CURRENT + 1))}"
NOTE="${2:-Релиз v$N}"

echo "▶ Выпускаю версию $N (versionCode=$N, versionName=1.$N, тег=v$N)"

# 0b. Менялся ли Android с прошлого выпуска. Номер версии общий, но если в
#     app/ изменились только versionCode/versionName, в Google Play уехала бы
#     прежняя версия под новым номером — пустое обновление (так вышло с 1.64).
#     Тогда Android-тесты, APK и подсказка про Play пропускаются. Тег прошлого
#     выпуска не найден — считаем, что менялся: лишняя проверка безопаснее.
PREV_TAG="v$CURRENT"
git fetch -q --tags origin 2>/dev/null || true
ANDROID_CHANGED=1
if git rev-parse -q --verify "refs/tags/$PREV_TAG" >/dev/null; then
  CHANGES=$(git diff "$PREV_TAG" -- app/ | grep -E '^[+-][^+-]' | grep -vE 'versionCode = [0-9]+|versionName = "' || true)
  NEW_FILES=$(git status --porcelain --untracked-files=all -- app/ | grep '^??' || true)
  [ -z "$CHANGES" ] && [ -z "$NEW_FILES" ] && ANDROID_CHANGED=0
fi
if [ "$ANDROID_CHANGED" = "0" ]; then
  echo "ℹ Android с $PREV_TAG не менялся: Google Play и APK этой версии не выпускаются"
fi

# 1. Синхронно меняем ОБА поля в gradle — единственный источник истины
sed -i '' -E "s/versionCode = [0-9]+/versionCode = $N/" "$GRADLE"
sed -i '' -E "s/versionName = \"[^\"]*\"/versionName = \"1.$N\"/" "$GRADLE"

# 1a. iOS — та же 1.N. Раньше её правили руками и забывали: App Store отверг
#     сборку 1.62, потому что в ней стояла уже одобренная 1.61.
sed -i '' -E "s/MARKETING_VERSION: \"[^\"]*\"/MARKETING_VERSION: \"1.$N\"/" ios/project.yml
sed -i '' -E "s/CURRENT_PROJECT_VERSION: \"[^\"]*\"/CURRENT_PROJECT_VERSION: \"$N\"/" ios/project.yml
(cd ios && xcodegen generate -q)

# 1c. Версия внизу страницы-описания — та же 1.N
sed -i '' -E "s|id=\"app-version\">FIXXE [0-9.]+<|id=\"app-version\">FIXXE 1.$N<|" web/about/index.html

# 1b. Синхронизируем версию PWA-веб-версии с Android (та же 1.N) + бампим кэш SW
sed -i '' -E "s/const APP_VERSION = '[^']*'/const APP_VERSION = '1.$N'/" web/app.js
sed -i '' -E "s/const CACHE = 'fixe-[^']*'/const CACHE = 'fixe-v$N'/" web/sw.js

# 2. Сборка
export JAVA_HOME="$(brew --prefix openjdk@17)"
export ANDROID_HOME="$HOME/android-sdk"
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$JAVA_HOME/bin:$PATH"
./gradlew assembleDebug

APK="app/build/outputs/apk/debug/app-debug.apk"
[ -f "$APK" ] || { echo "✗ APK не собрался"; exit 1; }

# 2b. Smoke-тесты на всех трёх платформах — обязательный рубеж перед выпуском.
#     Поводом стала 1.57: защита от частых нажатий отсекла самый первый запрос,
#     приложение навсегда застряло на «Загрузка…», и ни один этап выпуска
#     этого не заметил — потому что проверять было нечем.
#     SKIP_SMOKE=1 пропускает их; это аварийный ход, а не рабочий режим.
if [ "${SKIP_SMOKE:-0}" = "1" ]; then
  echo "⚠ Smoke-тесты пропущены (SKIP_SMOKE=1) — версия выходит непроверенной"
else
  echo "▶ Smoke-тесты перед выпуском"
  python3 tools/check-contrast.py || { echo "✗ выпуск остановлен: цвета не проходят норму контраста"; exit 1; }
  ./tools/smoke-web.sh     || { echo "✗ выпуск остановлен: PWA не прошла проверку"; exit 1; }
  if [ "$ANDROID_CHANGED" = "1" ]; then
    ./tools/smoke-android.sh || { echo "✗ выпуск остановлен: Android не прошёл проверку"; exit 1; }
    # Эмулятор больше не нужен, а рядом с ним iOS-симулятор не успевает:
    # при нагрузке ~60 UI-тесты iOS падали по таймаутам (выпуск 1.63).
    "${ANDROID_HOME:-$HOME/android-sdk}/platform-tools/adb" emu kill >/dev/null 2>&1 || true
    sleep 10
  else
    echo "  Android smoke пропущен: код Android не менялся"
  fi
  ./tools/smoke-ios.sh     || { echo "✗ выпуск остановлен: iOS не прошёл проверку"; exit 1; }
fi

# 2c. APK для устройств без Google Play (Huawei, кастомные прошивки, AOSP).
#    Это отдельный тип сборки: в нём есть проверка новых версий, которой НЕТ
#    в Play-сборке — там обновлять себя помимо магазина запрещено политикой.
#    Universal APK из самого Play для этого не годится: в нём остаются
#    split-метаданные, и без Play Store Android его не запускает.
APK_OUT=""
PW="$FIXXE_KEYSTORE_PASSWORD"
KS="$FIXXE_UPLOAD_KEYSTORE"
if [ "$ANDROID_CHANGED" = "0" ]; then
  # прежние web/FIXXE.apk и latest.json остаются: пользователи APK не получат
  # предложение обновиться на ту же самую версию
  echo "ℹ APK не пересобирается: на сайте остаётся прежний FIXXE.apk со своим latest.json"
elif [ -n "$PW" ] && [ -f "$KS" ]; then
  ./gradlew assembleStandalone -q \
    -Pandroid.injected.signing.store.file="$KS" \
    -Pandroid.injected.signing.store.password="$PW" \
    -Pandroid.injected.signing.key.alias=upload \
    -Pandroid.injected.signing.key.password="$PW"
  APK_OUT="/tmp/FIXXE-1.$N.apk"
  cp app/build/outputs/apk/standalone/app-standalone.apk "$APK_OUT"
  # Раздаём APK со своего домена — и сайт, и приложение ссылаются только туда.
  # Файл кладём рядом с веб-версией: он уедет и на зеркало, и в архив для
  # telebimmer. Это делается ДО коммита: раньше latest.json писался после,
  # и в репозиторий всегда уезжала прошлая версия. Сейчас и APK, и latest.json
  # вне git — это результаты сборки, а не исходники.
  cp "$APK_OUT" web/FIXXE.apk
  cat > web/latest.json <<JSON
{
  "versionCode": $N,
  "versionName": "1.$N",
  "url": "https://telebimmer.com/fixxe/about/",
  "apk": "https://telebimmer.com/fixxe/FIXXE.apk"
}
JSON
  echo "✓ APK для раздачи вне Play: $APK_OUT → web/FIXXE.apk"
else
  echo "⚠ нет ключа подписи — APK не собран: на сайте останется прежний FIXXE.apk"
  echo "  вместе со своим latest.json (оба вне git, так что пара не разъедется)"
fi

# 3. Коммит + пуш
git add -A
git commit -m "v$N: $NOTE"
git push

# 5. Метка версии в репозитории. APK отсюда больше не раздаётся — только со
#    своего домена: ни адреса репозитория, ни имени учётной записи посетителю
#    видеть незачем.
gh release create "v$N" --title "FIXXE v$N" --notes "versionName=1.$N

$NOTE"

echo "✓ v$N помечен. versionCode=$N == тег v$N."
echo
echo "  Заметки для магазинов (АНГЛИЙСКИЙ) — обнови store-release-notes.txt, затем:"
if [ "$ANDROID_CHANGED" = "1" ]; then
  echo "    play-ops ship --track production --yes --notes-file store-release-notes.txt"
else
  echo "    Google Play: НЕ выпускать — Android с $PREV_TAG не менялся"
fi
# --upload-only: сборка идёт сразу в App Store — тестеры и бета-ревью не нужны
echo "    (cd ios && testflight-ops ship --upload-only --yes --notes-file ../store-release-notes.txt)"

# 6. Деплой веб-версии на зеркало (best-effort — если задано и хост доступен)
VM="$FIXXE_MIRROR_SSH"
if [ -z "$VM" ]; then
  echo "ℹ зеркало PWA не задано (FIXXE_MIRROR_SSH в .release.local) — деплой пропущен"
elif tar czf /tmp/fixe-web.tgz -C web . 2>/dev/null && \
   scp -q -o BatchMode=yes -o ConnectTimeout=8 /tmp/fixe-web.tgz "$VM:/tmp/" 2>/dev/null; then
  if ssh -o BatchMode=yes -o ConnectTimeout=8 "$VM" \
      "sudo tar xzf /tmp/fixe-web.tgz -C '$FIXXE_MIRROR_DIR' 2>/dev/null && sudo systemctl reload nginx"; then
    echo "✓ PWA-зеркало задеплоено: ${FIXXE_MIRROR_URL:-$VM} (версия 1.$N)"
  else
    echo "✗ PWA-зеркало НЕ обновлено: архив доехал, но на сервере не распаковался"
  fi
  echo "  ⚠ публичную копию https://telebimmer.com/fixxe/ обновить вручную —"
  echo "    доступа к этому хостингу у скрипта нет"
else
  echo "⚠ PWA не задеплоена (VM недоступна) — задеплой вручную позже"
fi
