#!/usr/bin/env python3
"""Шаги выпуска iOS-версии, которых нет (или которые сломаны) в appstore-ops.

Запускается из tools/ship-ios.sh интерпретатором appstore-ops (в нём есть
cryptography). Ключ App Store Connect берётся из профиля testflight-ops,
путь к которому — в переменной TESTFLIGHT_OPS_PROFILE (ship-ios.sh берёт её
из .release.local); сам ключ в репозитории не хранится.

  asc_release.py state 1.65     — состояние версии в App Store (или NONE)
  asc_release.py finish 1.65    — проверить и отправить версию на ревью

finish:
  1. версия есть и к ней прикреплена сборка этой же версии;
  2. «Что нового» заполнено во ВСЕХ локалях — `metadata push` может
     оборваться на полпути (1.64), и тогда Apple отвечает на отправку только
     невнятным ENTITY_STATE_INVALID;
  3. выпуск сразу после одобрения (AFTER_APPROVAL), без рекламного ID;
  4. отправка на ревью через reviewSubmissions — `appstore-ops submit`
     сломан (Apple убрала appAvailabilities); сразу после загрузки сборки
     Apple ещё обрабатывает материалы, поэтому — с повторами.
Код возврата 3 — пустые «Что нового» (ship-ios.sh перезальёт тексты и
повторит), остальное ненулевое — ошибка.
"""
import base64, json, os, pathlib, re, sys, time, urllib.error, urllib.request

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec, utils as asu

APP = "6815242016"   # FIXXE в App Store Connect (публичный id, он же в ссылке магазина)
CFG = pathlib.Path(os.environ.get("TESTFLIGHT_OPS_PROFILE") or sys.exit(
    "✗ задайте TESTFLIGHT_OPS_PROFILE — путь к профилю testflight-ops с ключом App Store Connect"))

_cfg = CFG.read_text()
_field = lambda k: re.search(rf"^{k}:\s*\"?([^\"\n]+)\"?", _cfg, re.M).group(1).strip()
_ISS, _KID = _field("asc_issuer_id"), _field("asc_key_id")
_KEY = serialization.load_pem_private_key(
    pathlib.Path(_field("asc_key_path")).expanduser().read_bytes(), password=None)


def _token():
    b64 = lambda b: base64.urlsafe_b64encode(b).rstrip(b"=")
    h = b64(json.dumps({"alg": "ES256", "kid": _KID, "typ": "JWT"}, separators=(",", ":")).encode())
    p = b64(json.dumps({"iss": _ISS, "exp": int(time.time()) + 900, "aud": "appstoreconnect-v1"},
                       separators=(",", ":")).encode())
    r, s = asu.decode_dss_signature(_KEY.sign(h + b"." + p, ec.ECDSA(hashes.SHA256())))
    return (h + b"." + p + b"." + b64(r.to_bytes(32, "big") + s.to_bytes(32, "big"))).decode()


def req(method, path, body=None):
    rq = urllib.request.Request("https://api.appstoreconnect.apple.com" + path, method=method,
                                headers={"Authorization": f"Bearer {_token()}", "Content-Type": "application/json"},
                                data=json.dumps(body).encode() if body else None)
    try:
        raw = urllib.request.urlopen(rq, timeout=60).read()
        return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        return {"err": e.code, "body": e.read().decode()}


def version(ver):
    vs = req("GET", f"/v1/apps/{APP}/appStoreVersions?filter[platform]=IOS&limit=10")["data"]
    return next((v for v in vs if v["attributes"]["versionString"] == ver), None)


def cmd_state(ver):
    v = version(ver)
    print(v["attributes"]["appStoreState"] if v else "NONE")


def cmd_finish(ver):
    v = version(ver)
    if not v:
        sys.exit(f"✗ версии {ver} в App Store Connect нет")
    vid = v["id"]
    state = v["attributes"]["appStoreState"]
    if state in ("WAITING_FOR_REVIEW", "IN_REVIEW", "READY_FOR_SALE", "PENDING_DEVELOPER_RELEASE"):
        print(f"✓ {ver} уже {state} — отправлять нечего"); return

    # 1. сборка прикреплена и она этой же версии
    b = req("GET", f"/v1/appStoreVersions/{vid}/build")
    build = b.get("data")
    if not build:
        sys.exit(f"✗ к версии {ver} не прикреплена сборка")
    pre = req("GET", f"/v1/builds/{build['id']}/preReleaseVersion").get("data", {})
    bver = pre.get("attributes", {}).get("version")
    if bver != ver:
        sys.exit(f"✗ к версии {ver} прикреплена сборка версии {bver}")
    print(f"  сборка {build['attributes']['version']} ({bver}), {build['attributes']['processingState']}")

    # 2. «Что нового» во всех локалях
    locs = req("GET", f"/v1/appStoreVersions/{vid}/appStoreVersionLocalizations?limit=50")["data"]
    empty = [l["attributes"]["locale"] for l in locs if not (l["attributes"].get("whatsNew") or "").strip()]
    if empty:
        print(f"✗ пустое «Что нового» в {len(empty)} из {len(locs)} локалей: {', '.join(empty)}")
        sys.exit(3)
    print(f"  «Что нового» заполнено во всех {len(locs)} локалях")

    # 3. выпуск сразу после одобрения
    r = req("PATCH", f"/v1/appStoreVersions/{vid}", {"data": {"type": "appStoreVersions", "id": vid,
            "attributes": {"releaseType": "AFTER_APPROVAL", "usesIdfa": False}}})
    if "err" in r:
        sys.exit(f"✗ не удалось выставить выпуск после одобрения: {r['body'][:300]}")

    # 4. отправка на ревью
    subs = req("GET", f"/v1/reviewSubmissions?filter[app]={APP}&filter[platform]=IOS&limit=20")["data"]
    ready = [s for s in subs if s["attributes"]["state"] == "READY_FOR_REVIEW"]
    if ready:
        sid = ready[0]["id"]
    else:
        r = req("POST", "/v1/reviewSubmissions", {"data": {"type": "reviewSubmissions",
                "attributes": {"platform": "IOS"}, "relationships": {"app": {"data": {"type": "apps", "id": APP}}}}})
        if "err" in r:
            sys.exit(f"✗ не создать заявку на ревью: {r['body'][:300]}")
        sid = r["data"]["id"]
    items = req("GET", f"/v1/reviewSubmissions/{sid}/items")["data"]
    if not items:
        for i in range(30):          # до 15 минут: Apple обрабатывает материалы
            r = req("POST", "/v1/reviewSubmissionItems", {"data": {"type": "reviewSubmissionItems",
                    "relationships": {"reviewSubmission": {"data": {"type": "reviewSubmissions", "id": sid}},
                                      "appStoreVersion": {"data": {"type": "appStoreVersions", "id": vid}}}}})
            if "err" not in r:
                break
            body = r["body"]
            if "ASSET_IN_POST_PROCESSING" not in body and i >= 3:
                # не «ещё обрабатывается» — показать, что именно не так
                details = re.findall(r'"detail" : "([^"]+)"', body)
                sys.exit("✗ Apple не принимает версию на ревью:\n  " + "\n  ".join(dict.fromkeys(details)))
            print("  Apple ещё обрабатывает материалы, жду…"); time.sleep(30)
        else:
            sys.exit("✗ за 15 минут Apple так и не приняла версию на ревью")
    r = req("PATCH", f"/v1/reviewSubmissions/{sid}", {"data": {"type": "reviewSubmissions", "id": sid,
            "attributes": {"submitted": True}}})
    if "err" in r:
        sys.exit(f"✗ не отправить заявку: {r['body'][:300]}")
    state = req("GET", f"/v1/appStoreVersions/{vid}")["data"]["attributes"]["appStoreState"]
    print(f"✓ {ver} отправлена на ревью: {state}; выйдет сама после одобрения")


if __name__ == "__main__":
    if len(sys.argv) != 3 or sys.argv[1] not in ("state", "finish"):
        sys.exit(__doc__)
    {"state": cmd_state, "finish": cmd_finish}[sys.argv[1]](sys.argv[2])
