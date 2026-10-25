#!/usr/bin/env python3
"""Генерирует справочник валют для PWA и iOS из Android-исходников —
единого источника данных.

Источники:
  CurrencyViewModel.kt — SYMBOLS, NAMES, FLAGS и список валют по умолчанию;
  MainActivity.kt      — LANGUAGES (тег → родное название).
RTL-языки в Android определяет система, для web/iOS список задан здесь.

Раньше web/currency-data.js и ios/FIXXE/Resources/currency-data.json
правились руками и могли разъехаться с Android. Запуск:

    python3 tools/gen-data.py
"""
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VM = os.path.join(ROOT, 'app/src/main/java/com/example/currencyconverter/ui/CurrencyViewModel.kt')
MAIN = os.path.join(ROOT, 'app/src/main/java/com/example/currencyconverter/MainActivity.kt')
JS = os.path.join(ROOT, 'web/currency-data.js')
JSON_OUT = os.path.join(ROOT, 'ios/FIXXE/Resources/currency-data.json')

RTL_LANGS = ['ar', 'he', 'fa']

vm = open(VM, encoding='utf-8').read()
main = open(MAIN, encoding='utf-8').read()


def block(src, decl):
    """тело объявления `decl(` до парной закрывающей скобки"""
    m = re.search(decl, src)
    if not m:
        raise SystemExit(f'не найдено: {decl}')
    i, depth = m.end() - 1, 0
    while i < len(src):
        if src[i] == '(':
            depth += 1
        elif src[i] == ')':
            depth -= 1
            if depth == 0:
                return src[m.end():i]
        i += 1
    raise SystemExit(f'не закрыт блок: {decl}')


def strip_comments(s):
    return re.sub(r'//[^\n]*', '', s)


def pairs(src, name):
    body = strip_comments(block(src, rf'val {name} = mapOf\('))
    return dict(re.findall(r'"((?:[^"\\]|\\.)*)"\s+to\s+"((?:[^"\\]|\\.)*)"', body))


symbols = pairs(vm, 'SYMBOLS')
names = pairs(vm, 'NAMES')
flags = pairs(vm, 'FLAGS')

# список валют по умолчанию — из инициализации в CurrencyViewModel
defaults_body = block(vm, r'else mutableListOf\(')
defaults = re.findall(r'"([A-Z0-9]{3,})"', defaults_body)

# языки — пары «тег to родное название»
lang_body = strip_comments(block(main, r'val LANGUAGES = listOf\('))
languages = [[a, b] for a, b in re.findall(
    r'"([a-zA-Z+\-]{2,7})"\s+to\s+"((?:[^"\\]|\\.)*)"', lang_body)]

if not (symbols and names and flags and defaults and languages):
    raise SystemExit('что-то не распарсилось — данные не записаны')

data = {'symbols': symbols, 'names': names, 'flags': flags,
        'defaults': defaults, 'languages': languages, 'rtl': RTL_LANGS}

with open(JSON_OUT, 'w', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, separators=(',', ':'))


def js(v):
    return json.dumps(v, ensure_ascii=False)


with open(JS, 'w', encoding='utf-8') as f:
    f.write('// Автогенерировано из CurrencyViewModel.kt (tools/gen-data.py)\n')
    f.write(f'const SYMBOLS = {js(symbols)};\n')
    f.write(f'const NAMES = {js(names)};\n')
    f.write(f'const FLAGS = {js(flags)};\n')
    f.write(f'const DEFAULT_CURRENCIES = {js(defaults)};\n')
    f.write(f'const LANGUAGES = {js(languages)};\n')
    f.write(f'const RTL_LANGS = {js(RTL_LANGS)};\n')

print(f'symbols {len(symbols)}, names {len(names)}, flags {len(flags)}, '
      f'defaults {len(defaults)}, languages {len(languages)}')
print(f'-> {JS}\n-> {JSON_OUT}')
