"""Live check of the official Agmarknet 2.0 report API (api.agmarknet.gov.in),
the endpoint behind agmarknet.gov.in's "Daily Price and Arrival Report" page.
Public, no key. Prints the ids it needs and a few rows per crop. Read-only.

    python -m tools.probe_agmarknet
"""
from __future__ import annotations

import json
from datetime import date, timedelta

import requests

BASE = "https://api.agmarknet.gov.in/v1"
HEADERS = {
    "User-Agent": "Mozilla/5.0 (Linux; Android 14) AdikeRubberRates/1.0 (+maheshraikg@gmail.com)",
    "Accept": "application/json, text/plain, */*",
    "Content-Type": "application/json",
    "Origin": "https://agmarknet.gov.in",
    "Referer": "https://agmarknet.gov.in/",
}
STATES = ["karnataka", "kerala", "keralam"]
CROPS = ["arecanut", "rubber", "black pepper", "pepper", "coffee", "cocoa", "cardamom"]


def main() -> None:
    s = requests.Session()
    s.headers.update(HEADERS)
    for url in ("https://api.data.gov.in/resource/9ef84268-d588-465a-a308-a864a43d0070?format=json&limit=1"
                "&api-key=579b464db66ec23bdd000001cdd3946e44ce4aad7209ff7b23ac571b",):
        try:
            r = s.get(url, timeout=20)
            print(f"[data.gov.in] HTTP {r.status_code} {r.text[:150]!r}")
        except Exception as e:  # noqa: BLE001
            print(f"[data.gov.in] ERROR {str(e)[:150]}")
    r = s.get(f"{BASE}/daily-price-arrival/filters", timeout=60)
    print(f"[filters] HTTP {r.status_code} {r.headers.get('content-type')}")
    data = r.json()["data"]
    print("[filters] keys:", list(data))
    states = {x["state_name"].strip().lower(): x for x in data["state_data"]}
    for n in STATES:
        if n in states:
            print("[state]", json.dumps(states[n]))
    cmdts = [c for c in data["cmdt_data"] if any(k in c["cmdt_name"].lower() for k in CROPS)]
    for c in cmdts:
        print("[cmdt]", json.dumps(c, ensure_ascii=False))
    today = date.today()
    for c in cmdts:
        for sname in ("karnataka", "kerala", "keralam"):
            st = states.get(sname)
            if not st:
                continue
            payload = {
                "from_date": (today - timedelta(days=6)).isoformat(), "to_date": today.isoformat(),
                "data_type": "100004", "group": str(c["cmdt_group_id"]), "commodity": str(c["cmdt_id"]),
                "state": f"[{st['state_id']}]", "district": "[100001]", "market": "[100002]",
                "grade": "[100003]", "variety": "[100007]", "page": "1", "limit": "1000",
            }
            try:
                rr = s.post(f"{BASE}/daily-price-arrival/report", json=payload, timeout=90)
                doc = rr.json()
            except Exception as e:  # noqa: BLE001
                print(f"[report] {c['cmdt_name']} / {sname}: ERROR {str(e)[:200]}")
                continue
            recs = (doc.get("data") or {}).get("records") or [] if isinstance(doc.get("data"), dict) else []
            flat = [x for g in recs for x in g.get("data", [])]
            print(f"[report] {c['cmdt_name']} / {sname}: HTTP {rr.status_code} rows={len(flat)} "
                  f"msg={str(doc.get('message') or doc.get('status') or '')[:80]}")
            if not flat:
                print("   raw:", json.dumps(doc, ensure_ascii=False)[:300])
            markets = sorted({x.get("market_name") for x in flat})
            if markets:
                print("   markets:", ", ".join(m for m in markets if m)[:400])
            for x in flat[:3]:
                print("   row:", json.dumps(x, ensure_ascii=False)[:400])


if __name__ == "__main__":
    main()
