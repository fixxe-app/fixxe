#!/usr/bin/env bash
# Снимок настоящего веб-приложения FIXXE в заданном состоянии (живые курсы из сети).
#   capture.sh OUT.png '<json настроек>' [ширина=430] [высота=932]
# Результат — (ширина×3)×(высота×3), по умолчанию 1290×2796 (iPhone Pro Max).
# Ключи JSON → localStorage fixe.<ключ>: currencies ["EUR","USD",…], theme 1 светлая / 2 тёмная,
# lang "ru"/"en"/…, saved_code "EUR" + saved_amount 250 + amount_memory 3 — введённая сумма,
# adjust_pct 1.5 + adjust_keep true + adjust_left_at "NOW" — поправка к курсу, grouping 1 — пробелы,
# decimals 0..3, round_up true/false.
set -euo pipefail
OUT="$1"; STATE="${2:-{\}}"; W="${3:-430}"; H="${4:-932}"
DIR="$(cd "$(dirname "$0")" && pwd)/site"
REPO="$(cd "$(dirname "$0")/../../../.." && pwd)"
ln -sfn "$REPO/web" "$DIR/web"   # приложение — из этого репозитория
PORT=$(( 30000 + RANDOM % 9000 ))
python3 -m http.server "$PORT" --directory "$DIR" >/dev/null 2>&1 & SRV=$!
PROFILE=$(mktemp -d)
trap 'kill $SRV 2>/dev/null; rm -rf "$PROFILE"' EXIT
for i in $(seq 1 20); do curl -fs "http://127.0.0.1:$PORT/web/" >/dev/null && break; sleep 0.3; done
ENC=$(python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1]))' "$STATE")
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless --disable-gpu --hide-scrollbars \
  --user-data-dir="$PROFILE" --force-device-scale-factor=3 --window-size="$((W+100)),$((H+200))" \
  --virtual-time-budget=15000 --screenshot="$OUT" \
  "http://127.0.0.1:$PORT/frame.html?w=$W&h=$H&s=$ENC" >/dev/null 2>&1 || true
python3 -c 'import sys;from PIL import Image;i=Image.open(sys.argv[1]);w,h=int(sys.argv[2])*3,int(sys.argv[3])*3;i.crop((0,0,w,h)).save(sys.argv[1]);print(sys.argv[1],w,"x",h)' "$OUT" "$W" "$H"
