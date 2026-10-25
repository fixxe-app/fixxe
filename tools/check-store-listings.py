#!/usr/bin/env python3
"""Сверка карточек Google Play: что залито и что реально видит человек.

Google Play сам переводит карточку на языки, для которых нет нашего текста,
и этот машинный перевод выглядит как настоящий — но в нём «order» становится
«заказом», а источник Frankfurter — «Франкфуртским центральным банком».
Поэтому мало проверить, что мы залили: нужно убедиться, что витрина отдаёт
именно наш текст, а не свой.

Запускать питоном play-ops — в нём есть клиент Google API:

    ~/.local/share/uv/tools/play-ops/bin/python tools/check-store-listings.py
    ~/.local/share/uv/tools/play-ops/bin/python tools/check-store-listings.py --public

Витрина обновляется не сразу — после заливки на распространение уходит
от получаса до суток, так что расхождение сразу после push это норма.
"""
import os, sys, re, html, pathlib, urllib.request
import yaml
from google.oauth2 import service_account
from googleapiclient.discovery import build

ROOT = pathlib.Path(__file__).resolve().parent.parent
# ключ сервисного аккаунта Google Play — вне репозитория (см. .release.local.example)
KEY = os.environ.get("PLAY_SERVICE_ACCOUNT_JSON") or sys.exit(
    "✗ задайте PLAY_SERVICE_ACCOUNT_JSON — путь к JSON-ключу сервисного аккаунта Google Play")
PKG = "com.karpinity.fixxe"


def console_listings():
    creds = service_account.Credentials.from_service_account_file(
        KEY, scopes=["https://www.googleapis.com/auth/androidpublisher"])
    svc = build("androidpublisher", "v3", credentials=creds, cache_discovery=False)
    eid = svc.edits().insert(packageName=PKG, body={}).execute()["id"]
    try:
        got = svc.edits().listings().list(packageName=PKG, editId=eid).execute()
        return {l["language"]: l for l in got.get("listings", [])}
    finally:
        svc.edits().delete(packageName=PKG, editId=eid).execute()


def page_text(lang):
    """Страница витрины, приведённая к обычному тексту.

    Play отдаёт описание внутри JSON в разметке, где не-латиница
    экранирована как \\uXXXX — без обратного преобразования поиск по
    русской или японской фразе не найдёт ничего и соврёт.
    """
    url = f"https://play.google.com/store/apps/details?id={PKG}&hl={lang}"
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    try:
        page = urllib.request.urlopen(req, timeout=30).read().decode("utf-8", "replace")
    except Exception:
        return None
    page = re.sub(r"\\\\u([0-9a-fA-F]{4})", lambda m: chr(int(m.group(1), 16)), page)
    return re.sub(r"\s+", " ", html.unescape(page))


def norm(t):
    return re.sub(r"\s+", " ", t).strip()


def main():
    check_public = "--public" in sys.argv
    want = yaml.safe_load((ROOT / "play/manifest.yaml").read_text())["locales"]
    have = console_listings()

    missing = sorted(set(want) - set(have))
    stale, ok = [], []
    for lang, w in sorted(want.items()):
        h = have.get(lang)
        if not h:
            continue
        if h.get("fullDescription", "").strip() == w["full_description"].strip() \
           and h.get("shortDescription", "").strip() == w["short_description"].strip():
            ok.append(lang)
        else:
            stale.append(lang)

    print(f"В консоли Google Play: {len(have)} локалей")
    print(f"  совпадают с нашим текстом: {len(ok)}")
    if stale:
        print(f"  РАСХОДЯТСЯ: {', '.join(stale)}")
    if missing:
        print(f"  НЕ ЗАЛИТЫ: {', '.join(missing)}")

    if check_public:
        print("\nЧто отдаёт витрина (первые слова описания):")
        live = 0
        for lang in sorted(want):
            got = page_text(lang)
            if got is None:
                print(f"  {lang:<7} — страница не открылась")
                continue
            # маркер: кусок нашего описания подлиннее, чтобы не совпасть случайно
            head = norm(want[lang]["full_description"])[:60]
            if head in got:
                live += 1
                print(f"  {lang:<7} ✓ наш текст")
            else:
                print(f"  {lang:<7} ✗ пока автоперевод Google")
        print(f"\n  на витрине наш текст: {live} из {len(want)}")

    bad = bool(stale or missing)
    print("\n" + ("✗ есть расхождения" if bad else "✓ в консоли всё наше"))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
