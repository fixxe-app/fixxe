#!/usr/bin/env python3
"""Рекламная картинка для сторис (1080x1920) из актуального скриншота приложения.

    python3 tools/make-story.py store-assets/promo/story-en.png        # английская
    python3 tools/make-story.py store-assets/promo/story-ru.png ru     # русская

Берёт store-assets/screenshots-ios/5-dark.png — то есть картинка всегда
показывает текущий вид приложения и свежие курсы. Верх и низ держим внутри
безопасных зон: в сторис их перекрывает интерфейс соцсети.
"""
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import pathlib, sys
RU = len(sys.argv) > 2 and sys.argv[2] == 'ru'
T = {
    'subtitle': 'Конвертер валют' if RU else 'Currency converter',
    'title': ['335 валют.', 'Даже редкие.'] if RU else ['335 currencies.', 'Even the rare ones.'],
    'bullets': (['Среднерыночные курсы, 3 источника', 'Работает без интернета',
                 'Без рекламы и слежки', '40 языков интерфейса']
                if RU else ['Mid-market rates, 3 sources', 'Works offline',
                            'No ads. No tracking.', '40 languages']),
    'shot': '6-dark-ru.png' if RU else '5-dark.png',
}


W, H = 1080, 1920
SF = '/System/Library/Fonts/SFNS.ttf'
# В сторис верх перекрывает аватар с именем, низ — поле ответа.
# Держим важное внутри этих полей.
SAFE_TOP, SAFE_BOT = 170, 300

def font(size, weight='Regular'):
    f = ImageFont.truetype(SF, size)
    try: f.set_variation_by_name(weight)
    except Exception: pass
    return f

def rounded(img, r):
    mask = Image.new('L', img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, img.size[0]-1, img.size[1]-1], r, fill=255)
    out = img.convert('RGBA'); out.putalpha(mask); return out

bg = Image.new('RGB', (W, H), '#070C14')
d = ImageDraw.Draw(bg)
TOP, BOT = (18, 38, 64), (5, 8, 14)
for y in range(H):
    t = (y / H) ** 0.75
    d.line([(0, y), (W, y)], fill=tuple(int(TOP[i] + (BOT[i]-TOP[i]) * t) for i in range(3)))
g = Image.new('L', (W, H), 0)
ImageDraw.Draw(g).ellipse([-200, -560, W+200, 460], fill=125)
g = g.filter(ImageFilter.GaussianBlur(170))
bg = Image.composite(Image.new('RGB', (W, H), '#2C72C8'), bg, g)
d = ImageDraw.Draw(bg)

# шапка
icon = rounded(Image.open('store-assets/icon-512.png').convert('RGBA').resize((130, 130), Image.LANCZOS), 29)
bg.paste(icon, (76, SAFE_TOP), icon)
d.text((228, SAFE_TOP + 8), 'FIXXE', font=font(60, 'Bold'), fill='#FFFFFF')
d.text((231, SAFE_TOP + 74), T['subtitle'], font=font(40, 'Semibold'), fill='#A9C8EA')

# заголовок — две строки, короче и крупнее
y = SAFE_TOP + 190
for line in T['title']:
    d.text((76, y), line, font=font(74, 'Heavy'), fill='#FFFFFF')
    y += 86

# Показываем верх экрана крупным планом: мелкий шрифт целого скриншота
# в ленте не читается, а рубль и вона — главный аргумент.
shot = Image.open('store-assets/screenshots-ios/' + T['shot']).convert('RGB')
crop = shot.crop((0, 0, shot.width, 1480))   # ровно по строку KPW включительно
ph_w = 716
ph_h = int(crop.height * ph_w / crop.width)
crop = rounded(crop.resize((ph_w, ph_h), Image.LANCZOS), 38)

py = y + 46
px = (W - ph_w) // 2
shadow = Image.new('RGBA', (ph_w + 140, ph_h + 140), (0, 0, 0, 0))
ImageDraw.Draw(shadow).rounded_rectangle([70, 80, ph_w + 70, ph_h + 70], 38, fill=(0, 0, 0, 200))
shadow = shadow.filter(ImageFilter.GaussianBlur(38))
bg.paste(shadow, (px - 70, py - 70), shadow)
bg.paste(crop, (px, py), crop)
ImageDraw.Draw(bg).rounded_rectangle([px-1, py-1, px+ph_w, py+ph_h], 39, outline='#44679A', width=3)

# преимущества
d = ImageDraw.Draw(bg)
y = py + ph_h + 62
for text in T['bullets']:
    d.ellipse([80, y + 14, 98, y + 32], fill='#5BA9F5')
    d.text((126, y), text, font=font(38, 'Medium'), fill='#DCE7F5')
    y += 60

# призыв: ниже буллетов, но не ближе к краю, чем позволяет безопасная зона
y = max(y + 36, H - SAFE_BOT + 30)
d.text((76, y), 'App Store  ·  Google Play', font=font(44, 'Bold'), fill='#FFFFFF')
d.text((78, y + 62), 'telebimmer.com/fixxe', font=font(32, 'Medium'), fill='#93B7DF')
assert y + 110 < H - 60, f'низ вылезает за край: {y+110} из {H}'

out = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else '/tmp/fixxe-story.png')
bg.save(out, quality=95)
print('сохранено:', out, bg.size, '| нижний край текста:', y + 100, 'из', H)
