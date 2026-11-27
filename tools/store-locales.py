#!/usr/bin/env python3
"""Единый источник переводов карточек магазинов.

store-locales/<lang>.yaml — один файл на язык приложения. Отсюда тексты
раскладываются в play/manifest.yaml и appstore/manifest.yaml, у которых
разные коды локалей и разный набор полей.

    python3 tools/store-locales.py check   # лимиты длины и полнота
    python3 tools/store-locales.py sync    # вписать в оба манифеста
"""
import sys, pathlib, re
import yaml

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "store-locales"

# Язык приложения → локаль магазина. None = магазин такого языка не знает.
# Один язык может ехать в несколько локалей (pt → pt-PT и pt-BR).
APPSTORE = {
    "ar": ["ar-SA"], "cs": ["cs"], "da": ["da"], "de": ["de-DE"], "el": ["el"],
    "en": ["en-US", "en-GB", "en-AU", "en-CA"], "es": ["es-ES", "es-MX"],
    "fi": ["fi"], "fr": ["fr-FR", "fr-CA"], "he": ["he"], "hi": ["hi"],
    "hr": ["hr"], "hu": ["hu"], "id": ["id"], "it": ["it"], "ja": ["ja"],
    "ko": ["ko"], "nb": ["no"], "nl": ["nl-NL"], "pl": ["pl"],
    "pt": ["pt-PT", "pt-BR"], "ro": ["ro"], "ru": ["ru"], "sk": ["sk"],
    "sv": ["sv"], "th": ["th"], "tr": ["tr"], "vi": ["vi"], "zh": ["zh-Hans"],
    # App Store не знает этих языков приложения: bg bs et fa ka lt lv mk sl sq sr
}
PLAY = {
    "ar": ["ar"], "bg": ["bg"], "cs": ["cs-CZ"], "da": ["da-DK"],
    "de": ["de-DE"], "el": ["el-GR"], "en": ["en-US", "en-GB"], "es": ["es-ES", "es-419"],
    "et": ["et"], "fa": ["fa"], "fi": ["fi-FI"], "fr": ["fr-FR", "fr-CA"],
    "he": ["iw-IL"], "hi": ["hi-IN"], "hr": ["hr"], "hu": ["hu-HU"], "id": ["id"],
    "it": ["it-IT"], "ja": ["ja-JP"], "ka": ["ka-GE"], "ko": ["ko-KR"], "lt": ["lt"],
    "lv": ["lv"], "mk": ["mk-MK"], "nb": ["no-NO"], "nl": ["nl-NL"], "pl": ["pl-PL"],
    "pt": ["pt-PT", "pt-BR"], "ro": ["ro"], "ru": ["ru-RU"], "sk": ["sk"],
    "sl": ["sl"], "sr": ["sr"], "sv": ["sv-SE"], "th": ["th"],
    "tr": ["tr-TR"], "vi": ["vi"], "zh": ["zh-CN"],
    # Google Play не знает этих языков приложения: bs sq
}

# Карточки Google Play, которые уходят латиницей: в Сербии ищут «kurs dinara»,
# а не «курс динара». В sr.yaml (и на странице About) текст остаётся кириллицей.
PLAY_LATIN = {"sr"}
_SR_LAT = dict(zip("абвгдђежзијклљмнњопрстћуфхцчџш",
                   ["a","b","v","g","d","đ","e","ž","z","i","j","k","l","lj","m","n","nj","o","p","r",
                    "s","t","ć","u","f","h","c","č","dž","š"]))


def sr_latin(text):
    """Сербская кириллица → латиница; Љ/Њ/Џ в слове заглавными — LJ/NJ/DŽ."""
    out = []
    for i, ch in enumerate(text):
        lat = _SR_LAT.get(ch.lower())
        if lat is None:
            out.append(ch)
        elif ch.islower():
            out.append(lat)
        else:
            nxt = text[i + 1] if i + 1 < len(text) else ""
            out.append(lat.upper() if len(lat) > 1 and nxt.isupper() else lat[0].upper() + lat[1:])
    return "".join(out)


LIMITS = {           # жёсткие лимиты магазинов
    "title": 30,               # оба магазина: «FIXXE – Конвертер валют»
    "subtitle": 30,            # App Store
    "short_description": 80,   # Play
    "keywords": 100,           # App Store
    "promotional_text": 170,   # App Store
    "description": 4000,
    "whats_new": 4000,
}
REQUIRED = ["title", "subtitle", "short_description", "keywords", "promotional_text",
            "description", "whats_new"]


def load():
    out = {}
    for f in sorted(SRC.glob("*.yaml")):
        out[f.stem] = yaml.safe_load(f.read_text(encoding="utf-8"))
    return out


def check(data):
    bad = []
    for lang, d in sorted(data.items()):
        for k in REQUIRED:
            if not d.get(k):
                bad.append(f"{lang}: нет поля {k}")
                continue
            n = len(d[k].strip())
            if n > LIMITS[k]:
                bad.append(f"{lang}.{k}: {n} символов, лимит {LIMITS[k]}")
        # overrides: {локаль магазина: {поле: текст}} — своё значение для одной локали
        for code, fields in (d.get("overrides") or {}).items():
            if code not in APPSTORE.get(lang, []) + PLAY.get(lang, []):
                bad.append(f"{lang}.overrides: {code} — не локаль этого языка")
            for k, v in fields.items():
                if k not in LIMITS:
                    bad.append(f"{lang}.overrides.{code}: неизвестное поле {k}")
                elif len(v.strip()) > LIMITS[k]:
                    bad.append(f"{lang}.overrides.{code}.{k}: {len(v.strip())} символов, лимит {LIMITS[k]}")
    # en-US обязан быть английским — его видят все страны без своей карточки
    cyr = re.compile("[Ѐ-ӿ]")
    en = data.get("en", {})
    for k, v in en.items():
        if isinstance(v, str) and cyr.search(v):
            bad.append(f"en.{k}: кириллица в английской карточке")
    return bad


def sync(data):
    for path, mapping, fields in (
        (ROOT / "play/manifest.yaml", PLAY,
         {"title": "title", "short_description": "short_description",
          "full_description": "description"}),
        (ROOT / "appstore/manifest.yaml", APPSTORE,
         {"name": "title", "subtitle": "subtitle", "description": "description",
          "promotional_text": "promotional_text", "keywords": "keywords",
          "whats_new": "whats_new"}),
    ):
        is_play = mapping is PLAY
        doc = yaml.safe_load(path.read_text(encoding="utf-8"))
        base = doc["locales"][next(iter(doc["locales"]))]
        locales = {}
        for lang, d in sorted(data.items()):
            for code in mapping.get(lang, []):
                entry = {}
                own = (d.get("overrides") or {}).get(code, {})
                for field, src in fields.items():
                    # Название — с ключевым словом на языке витрины: по одному
                    # «FIXXE» никто не ищет, а «конвертер валют» ищут все.
                    entry[field] = own.get(src, d[src])
                    if is_play and lang in PLAY_LATIN:
                        entry[field] = sr_latin(entry[field])
                # ссылки и контакты одинаковы во всех локалях
                for k in ("support_url", "privacy_policy_url", "marketing_url", "video_url"):
                    if k in base:
                        entry[k] = base[k]
                locales[code] = entry
        doc["locales"] = locales
        path.write_text(yaml.dump(doc, allow_unicode=True, sort_keys=False,
                                  default_flow_style=False, width=100000),
                        encoding="utf-8")
        print(f"  {path.name}: {len(locales)} локалей")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "check"
    data = load()
    problems = check(data)
    if problems:
        print("✗ проблемы:")
        print("\n".join("  " + p for p in problems))
        if cmd == "sync":
            sys.exit(1)
    else:
        print(f"✓ {len(data)} языков, лимиты соблюдены")
    if cmd == "sync":
        sync(data)
