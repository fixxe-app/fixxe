#!/usr/bin/env python3
"""Контраст цветов во всех трёх приложениях — рубеж выпуска.

Норма WCAG AA: текст не бледнее 4.5:1 к фону, значки и другие нетекстовые
элементы — 3:1. Каждый цвет проверяется в обеих темах и против обоих фонов
(карточка и экран), берётся худший случай.

Проверка появилась после аудита по правилам Impeccable: строка курса под
суммой была 2.3–2.4:1, подвал — 1.7:1, а строка статуса на Android в тёмной
теме — 2.9:1 из-за цвета, зашитого в код одним на обе темы.

    python3 tools/check-contrast.py
"""
import re, sys, pathlib
ROOT = pathlib.Path(__file__).resolve().parent.parent
TEXT, ICON = 4.5, 3.0

def h2(h):
    h = h.lstrip("#"); h = "".join(c*2 for c in h) if len(h) == 3 else h[-6:]
    return [int(h[i:i+2], 16) for i in (0, 2, 4)]
def lum(h):
    c = [x/255 for x in h2(h)]; c = [x/12.92 if x <= 0.03928 else ((x+0.055)/1.055)**2.4 for x in c]
    return 0.2126*c[0] + 0.7152*c[1] + 0.0722*c[2]
def ratio(a, b):
    la, lb = sorted([lum(a), lum(b)], reverse=True); return (la+0.05)/(lb+0.05)

problems, checked = [], 0
def check(platform, name, purpose, need, light, dark, bg_light, bg_dark):
    global checked
    if not light or not dark:
        problems.append(f"{platform}: нет цвета {name} ({purpose}) — его должны задавать ресурсы темы"); return
    for theme, fg, bgs in (("светлая", light, bg_light), ("тёмная", dark, bg_dark)):
        r = min(ratio(fg, b) for b in bgs); checked += 1
        if r < need:
            problems.append(f"{platform}: {name} ({purpose}) в теме «{theme}» — {r:.2f}:1, нужно {need}:1")

# ── Android ───────────────────────────────────────────────────────────────
res = ROOT / "app/src/main/res"
def colors(p): return {m[0]: m[1] for m in re.findall(r'<color name="([^"]+)">#([0-9A-Fa-f]{6,8})</color>', p.read_text())}
day, night = colors(res/"values/colors.xml"), colors(res/"values-night/colors.xml")
n = lambda k: night.get(k, day.get(k))
A_BG = ([day["surface"], day["background"]], [n("surface"), n("background")])
for k, purpose, need in [("text_primary","основной текст",TEXT),("text_secondary","статус, названия",TEXT),
                         ("text_tertiary","строка курса",TEXT),("hint","версия, плейсхолдер",TEXT),
                         ("icon_muted","«Rates By…»",TEXT),("accent","ссылки и кнопки",TEXT),
                         ("status_offline","статус «офлайн»",TEXT),("status_stale","статус «устарели»",TEXT),
                         ("icon_faint","крестик и ручка",ICON)]:
    check("Android", k, purpose, need, day.get(k), n(k), *A_BG)
# цвет текста, зашитый в код, не меняется вместе с темой — его быть не должно
for f in (ROOT/"app/src/main/java").rglob("*.kt"):
    for i, line in enumerate(f.read_text().splitlines(), 1):
        if re.search(r"setTextColor\(\s*0x[0-9A-Fa-f]{8}", line) or re.search(r"->\s*0xFF[0-9A-Fa-f]{6}\.toInt\(\)", line):
            problems.append(f"Android: цвет зашит в код (одинаков в обеих темах) — {f.relative_to(ROOT)}:{i}")

# ── iOS ───────────────────────────────────────────────────────────────────
ui = (ROOT/"ios/FIXXE/Support/UIHelpers.swift").read_text()
pal = {m[0]: (m[1], m[2]) for m in re.findall(r'static let (\w+)\s*= adaptive\("([0-9A-Fa-f]{6})", "([0-9A-Fa-f]{6})"\)', ui)}
I_BG = ([pal["surface"][0], pal["bgGray"][0]], [pal["surface"][1], pal["bgGray"][1]])
for k, purpose, need in [("brandBlue","ссылки и кнопки",TEXT),("textFaint","строка курса",TEXT),("textDim","версия",TEXT),
                         ("muted","«Rates By…»",TEXT),("staleRed","статус «устарели»",TEXT),("staleBrown","статус «офлайн»",TEXT),
                         ("chipText","текст чипа",TEXT),("faint","крестик и ручка",ICON)]:
    check("iOS", k, purpose, need, *pal.get(k, (None, None)), *I_BG)

# ── веб ───────────────────────────────────────────────────────────────────
css = (ROOT/"web/styles.css").read_text()
def block(sel):
    i = css.index(sel); return dict(re.findall(r"--([a-z0-9-]+):(#[0-9A-Fa-f]{3,6});", css[i:css.index("}", i)]))
wl, wd = block(":root{"), {**block(":root{"), **block(':root[data-theme="dark"]{')}
W_BG = ([wl["card"], wl["bg"]], [wd["card"], wd["bg"]])
for k, purpose, need in [("ink","основной текст",TEXT),("gray","символ валюты",TEXT),("gray2","строка курса, название",TEXT),
                         ("gray3","статус",TEXT),("gray4","текст в списках",TEXT),("muted","«Rates By…»",TEXT),
                         ("dim","версия",TEXT),("faint2","плейсхолдер",TEXT),("blue","ссылки и кнопки",TEXT),
                         ("faint","крестик и ручка",ICON)]:
    check("веб", k, purpose, need, wl.get(k), wd.get(k), *W_BG)

if problems:
    print("✗ контраст не проходит норму:"); print("\n".join("  " + p for p in problems)); sys.exit(1)
print(f"✓ контраст: {checked} проверок на трёх платформах, все в норме")
