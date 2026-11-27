#!/usr/bin/env bash
# HTML-кадр → PNG ровно 1080×1920.  render.sh frame.html out.png
# Окно headless Chrome берём с запасом (Chrome отъедает ~90 px высоты и не бывает уже 500 px)
# и обрезаем. В HTML задавай html,body{width:1080px;height:1920px;margin:0;overflow:hidden}.
set -euo pipefail
IN="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"; OUT="$2"
PROFILE=$(mktemp -d); trap 'rm -rf "$PROFILE"' EXIT
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless --disable-gpu --hide-scrollbars \
  --user-data-dir="$PROFILE" --force-device-scale-factor=1 --window-size=1180,2120 \
  --virtual-time-budget=10000 --allow-file-access-from-files --screenshot="$OUT" "file://$IN" >/dev/null 2>&1 || true
python3 -c 'import sys;from PIL import Image;i=Image.open(sys.argv[1]);assert i.size[1]>=1920,i.size;i.crop((0,0,1080,1920)).save(sys.argv[1]);print(sys.argv[1],"1080x1920")' "$OUT"
