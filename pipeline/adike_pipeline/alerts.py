"""Price alerts + daily summary via FCM HTTP v1 (firebase-admin messaging; free).

Run by alerts.yml after collect.yml finishes. One Firestore query for active alerts.
"""
from __future__ import annotations

import argparse
import os
from pathlib import Path
from typing import Callable, Optional

from . import config
from .store import Store, make_store
from .util import log_event, now_ist, read_json

Sender = Callable[[dict], Optional[str]]  # returns error code or None


def best_row(rows: list[dict], crop: str, variety: str, market: str) -> Optional[dict]:
    cands = [r for r in rows if r["crop"] == crop and r["variety"] == variety
             and r["marketId"] == market and r.get("modal") is not None]
    if not cands:
        return None
    cands.sort(key=lambda r: (r["date"], -config.TRUST_ORDER[r["trust"]]), reverse=True)
    return cands[0]


def should_fire(alert: dict, row: dict, today: str) -> bool:
    if alert.get("lastFiredDate") == today or row["date"] != today:
        return False
    v = float(alert["value"])
    return row["modal"] >= v if alert["condition"] == "above" else row["modal"] <= v


def evaluate(store: Store, latest: dict, send: Sender, today: str,
             markets: dict[str, dict], varieties: dict[str, dict]) -> dict:
    rows = latest.get("rows", [])
    fired = skipped = deactivated = 0
    for alert_id, a in store.active_alerts():
        row = best_row(rows, a.get("crop"), a.get("variety"), a.get("marketId"))
        if not row or not should_fire(a, row, today):
            skipped += 1
            continue
        m = markets.get(row["marketId"], {})
        v = varieties.get(row["variety"], {})
        unit = "/ಕ್ವಿಂ" if row["crop"] == "arecanut" else "/ಕೆಜಿ"
        word = "ಮೇಲೆ" if a["condition"] == "above" else "ಕೆಳಗೆ"
        from .summary import inr
        msg = {"token": a["fcmToken"],
               "title": f"{v.get('kn', row['variety'])} · {m.get('kn', row['marketId'])}",
               "body": f"ಸರಾಸರಿ {inr(row['modal'])}{unit} — ನಿಮ್ಮ ಮಿತಿ {inr(float(a['value']))} ಕ್ಕಿಂತ {word}",
               "data": {"type": "alert", "crop": row["crop"], "variety": row["variety"],
                        "marketId": row["marketId"]}}
        err = send(msg)
        if err in ("UNREGISTERED", "INVALID_ARGUMENT", "NOT_FOUND"):
            store.set_doc(f"alerts/{alert_id}", {"active": False}, merge=True)
            deactivated += 1
        elif err is None:
            store.set_doc(f"alerts/{alert_id}", {"lastFiredDate": today}, merge=True)
            fired += 1
    return {"fired": fired, "skipped": skipped, "deactivated": deactivated}


def maybe_send_summary(store: Store, latest: dict, send: Sender, today: str) -> bool:
    s = latest.get("summary") or {}
    if s.get("date") != today or not s.get("evening"):
        return False
    meta = store.get_doc("runs/_meta") or {}
    if meta.get("summarySentDate") == today:
        return False
    first_kn = (s.get("kn") or "").split("\n")[0]
    err = send({"topic": "daily_summary", "title": "ಇಂದಿನ ಅಡಿಕೆ–ರಬ್ಬರ್ ಧಾರಣೆ",
                "body": first_kn[:180], "data": {"type": "summary"}})
    if err is None:
        store.set_doc("runs/_meta", {"summarySentDate": today}, merge=True)
        return True
    return False


def fcm_sender(dry_run: bool = False) -> Sender:
    def send(msg: dict) -> Optional[str]:
        if dry_run:
            log_event("fcm.dry_run", **{k: v for k, v in msg.items() if k != "token"})
            return None
        from firebase_admin import messaging
        m = messaging.Message(
            token=msg.get("token"), topic=msg.get("topic"),
            notification=messaging.Notification(title=msg["title"], body=msg["body"]),
            data={k: str(v) for k, v in msg.get("data", {}).items()},
            android=messaging.AndroidConfig(priority="high"))
        try:
            messaging.send(m)
            return None
        except messaging.UnregisteredError:
            return "UNREGISTERED"
        except Exception as e:  # noqa: BLE001
            code = getattr(e, "code", "ERROR")
            log_event("fcm.error", error=str(e)[:200], code=str(code))
            return str(code).upper()
    return send


def send_admin_alert(title: str, body: str, dry_run: bool = False) -> None:
    fcm_sender(dry_run)({"topic": "admins", "title": title, "body": body, "data": {"type": "admin"}})


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--site", default="../site")
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()
    site = Path(a.site)
    latest = read_json(site / "data" / "latest.json", {})
    markets = {m["id"]: m for m in read_json(site / "data" / "markets.json", [])}
    varieties = {v["id"]: v for v in read_json(site / "data" / "varieties.json", [])}
    store, real = make_store()
    if not real:
        log_event("alerts.skipped", reason="FIREBASE_SERVICE_ACCOUNT not set")
        return
    today = now_ist().date().isoformat()
    send = fcm_sender(a.dry_run or bool(os.environ.get("ADIKE_DRY_RUN")))
    res = evaluate(store, latest, send, today, markets, varieties)
    res["summarySent"] = maybe_send_summary(store, latest, send, today)
    log_event("alerts.done", **res)


if __name__ == "__main__":
    main()
