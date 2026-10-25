#!/usr/bin/env python3
"""Собирает страницу-описание FIXXE из тех же текстов, что уходят в магазины.

Источник — store-locales/<язык>.yaml: описание и подзаголовок там уже есть
и уже выверены, второй раз писать их для сайта незачем. Строки самой
страницы лежат в том же файле под ключом landing.

На выходе — web/about/i18n/<язык>.json, по файлу на язык: страница грузит
только тот, который выбран, иначе сорок описаний весили бы под двести
килобайт на каждого посетителя.

    ~/.local/share/uv/tools/appstore-ops/bin/python tools/build-about.py
"""
import json, pathlib, sys, unicodedata
import yaml

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "store-locales"
OUT = ROOT / "web/about/i18n"

# Названия языков — на них самих: человек ищет в списке своё слово.
NATIVE = {
    "ar": "العربية", "bg": "Български", "bs": "Bosanski", "cs": "Čeština",
    "da": "Dansk", "de": "Deutsch", "el": "Ελληνικά", "en": "English",
    "es": "Español", "et": "Eesti", "fa": "فارسی", "fi": "Suomi",
    "fr": "Français", "he": "עברית", "hi": "हिन्दी", "hr": "Hrvatski",
    "hu": "Magyar", "id": "Indonesia", "it": "Italiano", "ja": "日本語",
    "ka": "ქართული", "ko": "한국어", "lt": "Lietuvių", "lv": "Latviešu",
    "mk": "Македонски", "nb": "Norsk", "nl": "Nederlands", "pl": "Polski",
    "pt": "Português", "ro": "Română", "ru": "Русский", "sk": "Slovenčina",
    "sl": "Slovenščina", "sq": "Shqip", "sr": "Српски", "sv": "Svenska",
    "th": "ไทย", "tr": "Türkçe", "vi": "Tiếng Việt", "zh": "中文",
}
RTL = {"ar", "he", "fa"}


def structure(en_description):
    """Разметка описания по английскому: где заголовок, где пункт списка.

    Угадывать заголовки по заглавным буквам нельзя: в японском, китайском,
    арабском, грузинском, хинди заглавных нет вовсе, и разделы выходили
    обычным текстом, а первое китайское предложение — наоборот, заголовком.
    Все переводы повторяют английский построчно, поэтому разметку берём по
    номеру строки.
    """
    kinds = []
    for line in en_description.strip().split("\n"):
        t = line.strip()
        if not t:                 kinds.append("")
        elif t.startswith("•"):   kinds.append("li")
        elif t == t.upper() and len(t) < 60 and any(c.isalpha() for c in t): kinds.append("h")
        else:                     kinds.append("p")
    return kinds


def blocks(description, kinds, lang):
    lines = description.strip().split("\n")
    if len(lines) != len(kinds):
        raise SystemExit(f"{lang}: в описании {len(lines)} строк, а в английском {len(kinds)} — "
                         "разметка по номерам строк не сойдётся")
    out = []
    for kind, line in zip(kinds, lines):
        t = line.strip()
        if not kind: continue
        out.append([kind, t[1:].strip() if kind == "li" else t])
    return out


def sort_key(native):
    # «Čeština» — рядом с «Dansk», а не после «Türkçe»
    base = "".join(c for c in unicodedata.normalize("NFD", native) if not unicodedata.combining(c))
    return base.casefold()


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    en = yaml.safe_load((SRC / "en.yaml").read_text(encoding="utf-8"))
    kinds = structure(en["description"])
    index, missing = [], []

    for f in sorted(SRC.glob("*.yaml")):
        lang = f.stem
        d = yaml.safe_load(f.read_text(encoding="utf-8"))
        landing = d.get("landing")
        if not landing:
            missing.append(lang)
            landing = en["landing"]          # без перевода — английский, не пустота
        payload = {
            "lang": lang,
            "rtl": lang in RTL,
            "native": NATIVE.get(lang, lang),
            "subtitle": d["subtitle"],
            "blocks": blocks(d["description"], kinds, lang),
            **landing,
        }
        (OUT / f"{lang}.json").write_text(
            json.dumps(payload, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
        index.append({"code": lang, "native": NATIVE.get(lang, lang)})

    (OUT / "languages.json").write_text(
        json.dumps(sorted(index, key=lambda x: sort_key(x["native"])), ensure_ascii=False), encoding="utf-8")

    print(f"собрано языков: {len(index)}")
    if missing:
        print(f"строки страницы ещё не переведены ({len(missing)}): {', '.join(missing)}")
        print("  — у них английский интерфейс, описание на своём языке")
    return 0


if __name__ == "__main__":
    sys.exit(main())
