#!/usr/bin/env python3
"""Установки FIXXE в App Store — из аналитических отчётов App Store Connect.

Раздел «Аналитика» в веб-консоли роли App Manager закрыт, поэтому цифры берём
через API ключом, которым выпускаем версии (настройки testflight-ops).
08.10.2026 созданы два запроса отчётов — повторно создавать НЕ надо:
  разовый снимок прошлого:  1f16cb89-caf2-43ed-a923-271a79d2de67
  постоянный ежедневный:    e35306aa-c9d4-4521-9ce5-1e70e2e11436
Отчёты внутри: «App Downloads Standard» и «App Store Installation and Deletion
Standard». Apple кладёт одну и ту же дату в несколько экземпляров (и в снимок,
и в ежедневный) — на каждую дату берём один экземпляр, иначе всё удваивается.

    ~/.local/share/uv/tools/appstore-ops/bin/python -I tools/asc_installs.py
"""
import base64, collections, csv, gzip, io, json, pathlib, re, sys, time, urllib.request
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec, utils as asu

REQUESTS = ("1f16cb89-caf2-43ed-a923-271a79d2de67", "e35306aa-c9d4-4521-9ce5-1e70e2e11436")
HOME = pathlib.Path.home()
# настройки testflight-ops: ~/.config/<издатель>/testflight-ops/testflight-ops.local.md
cfg = next(HOME.glob(".config/*/testflight-ops/testflight-ops.local.md")).read_text()
iss = re.search(r"asc_issuer_id:\s*(\S+)", cfg).group(1)
kid = re.search(r"asc_key_id:\s*(\S+)", cfg).group(1)
key = serialization.load_pem_private_key((HOME / f".appstoreconnect/private_keys/AuthKey_{kid}.p8").read_bytes(), password=None)

b64 = lambda b: base64.urlsafe_b64encode(b).rstrip(b"=")
hdr = b64(json.dumps({"alg": "ES256", "kid": kid, "typ": "JWT"}, separators=(",", ":")).encode())
pl = b64(json.dumps({"iss": iss, "exp": int(time.time()) + 1200, "aud": "appstoreconnect-v1"}, separators=(",", ":")).encode())
r, s = asu.decode_dss_signature(key.sign(hdr + b"." + pl, ec.ECDSA(hashes.SHA256())))
TOKEN = (hdr + b"." + pl + b"." + b64(r.to_bytes(32, "big") + s.to_bytes(32, "big"))).decode()


def get(p, raw=False):
    u = p if p.startswith("http") else "https://api.appstoreconnect.apple.com" + p
    h = {"Authorization": f"Bearer {TOKEN}"} if "api.appstoreconnect" in u else {}
    resp = urllib.request.urlopen(urllib.request.Request(u, headers=h), timeout=60)
    return resp.read() if raw else json.load(resp)


def pages(url):
    while url:
        d = get(url)
        yield from d["data"]
        url = d.get("links", {}).get("next")


def load(name):
    """{дата: [строки одного экземпляра]} — по одному экземпляру на дату."""
    by_date = collections.defaultdict(dict)           # дата -> {экземпляр: строки}
    for rid in REQUESTS:
        for rep in pages(f"/v1/analyticsReportRequests/{rid}/reports?limit=200"):
            if rep["attributes"].get("name") != name:
                continue
            for inst in pages(f"/v1/analyticsReports/{rep['id']}/instances?limit=200&filter[granularity]=DAILY"):
                for sg in pages(f"/v1/analyticsReportInstances/{inst['id']}/segments"):
                    blob = get(sg["attributes"]["url"], raw=True)
                    try:
                        text = gzip.decompress(blob).decode()
                    except OSError:
                        text = blob.decode()
                    for x in csv.DictReader(io.StringIO(text), delimiter="\t"):
                        by_date[x.get("Date")].setdefault(inst["id"], []).append(x)
    return {d: max(insts.values(), key=len) for d, insts in by_date.items() if d}


def counts(x):
    return int(float(x.get("Counts") or 0))


def main():
    dl = load("App Downloads Standard")
    if not dl:
        sys.exit("отчёт «App Downloads Standard» пуст — Apple ещё не выложила данные?")
    dates = sorted(dl)
    by_type, by_country, by_device = collections.Counter(), collections.Counter(), collections.Counter()
    for d in dates:
        for x in dl[d]:
            t = x.get("Download Type", "?")
            by_type[t] += counts(x)
            if t == "First-time download":
                by_country[x.get("Territory", "?")] += counts(x)
                by_device[x.get("Device", "?")] += counts(x)
    print(f"App Store, загрузки: {dates[0]} … {dates[-1]} ({len(dates)} дней с данными)")
    for t, c in by_type.most_common():
        print(f"  {t:22} {c}")
    print("  первые загрузки по устройствам:", dict(by_device.most_common()))
    print("  первые загрузки по странам:", ", ".join(f"{k} {v}" for k, v in by_country.most_common(12)))

    inst = load("App Store Installation and Deletion Standard")
    if inst:
        idates = sorted(inst)
        cols = list(next(iter(inst.values()))[0].keys())
        ev = next((c for c in ("Event", "Event Type", "Type") if c in cols), None)
        by_event = collections.Counter()
        for d in idates:
            for x in inst[d]:
                by_event[x.get(ev, "?") if ev else "?"] += counts(x)
        print(f"App Store, установки и удаления: {idates[0]} … {idates[-1]}")
        for e, c in by_event.most_common():
            print(f"  {e:22} {c}")
        if not ev:
            print("  колонки:", cols)


if __name__ == "__main__":
    main()
