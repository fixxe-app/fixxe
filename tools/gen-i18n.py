#!/usr/bin/env python3
"""Генерирует локализацию для iOS и PWA из Android-ресурсов
app/src/main/res/values*/strings.xml — единственного источника истины для строк.

    ios/FIXXE/Resources/i18n.json
    web/i18n.js

Запуск: python3 tools/gen-i18n.py"""
import os, re, json, xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, 'app/src/main/res')
OUT = os.path.join(ROOT, 'ios/FIXXE/Resources/i18n.json')
OUT_JS = os.path.join(ROOT, 'web/i18n.js')

def tag_for(dirname):
    if dirname == 'values': return 'en'
    t = dirname[len('values-'):]
    return t[2:] if t.startswith('b+') else t   # values-b+he -> he

def unescape(s):
    if s is None: return ''
    s = s.replace('\\n', '\n').replace("\\'", "'").replace('\\"', '"').replace('\\@', '@')
    return s

def read(path):
    root = ET.parse(path).getroot()
    out = {}
    for el in root.findall('string'):
        name = el.get('name')
        # собираем текст вместе с вложенной разметкой (у нас её нет, но на будущее)
        text = ''.join(el.itertext())
        out[name] = unescape(text)
    return out

data = {}
for d in sorted(os.listdir(RES)):
    if not (d == 'values' or d.startswith('values-')): continue
    p = os.path.join(RES, d, 'strings.xml')
    if not os.path.exists(p): continue
    data[tag_for(d)] = read(p)

# en первым, остальные — в порядке как раньше
ordered = {'en': data.pop('en')}
ordered.update(data)
with open(OUT, 'w', encoding='utf-8') as f:
    json.dump(ordered, f, ensure_ascii=False, separators=(',', ':'))

# PWA: тот же словарь, по ключу на строку (как было в рукописном файле)
with open(OUT_JS, 'w', encoding='utf-8') as f:
    f.write('// Автогенерировано из Android strings.xml (tools/gen-i18n.py)\n')
    f.write('const I18N = {\n')
    langs = list(ordered.items())
    for li, (lang, kv) in enumerate(langs):
        f.write(json.dumps(lang, ensure_ascii=False) + ': {\n')
        items = list(kv.items())
        for i, (k, v) in enumerate(items):
            comma = ',' if i < len(items) - 1 else ''
            f.write(f'{json.dumps(k, ensure_ascii=False)}: {json.dumps(v, ensure_ascii=False)}{comma}\n')
        f.write('}' + (',' if li < len(langs) - 1 else '') + '\n')
    f.write('};\n')

print(f'{len(ordered)} языков, {len(ordered["en"])} ключей')
print(f'-> {OUT}\n-> {OUT_JS}')
