"""Generate SAMPLE data for local development (clearly marked sample: true).

    python -m tools.seed_sample --site ../../site-sample --config ../data

Values are synthetic and must never be published to the real gh-pages branch.
"""
from __future__ import annotations

import argparse
import math
import random
from datetime import timedelta
from pathlib import Path

from adike_pipeline.models import PriceRow
from adike_pipeline.publish import Publisher, trust_score
from adike_pipeline.summary import build_summary
from adike_pipeline.util import now_ist, read_json, write_json_if_changed

BASE = {("arecanut", "rashi"): 52000, ("arecanut", "bette"): 56000, ("arecanut", "saraku"): 80000,
        ("arecanut", "gorabalu"): 32000, ("arecanut", "chali_new"): 45000, ("arecanut", "chali_old"): 50000,
        ("rubber", "rss4"): 190, ("rubber", "rss5"): 185, ("rubber", "latex60"): 130}
MARKETS = {"arecanut": ["shivamogga", "sagar", "tirthahalli", "channagiri", "sirsi", "puttur", "mangaluru",
                        "bantwal", "belthangady", "kundapura"],
           "rubber": ["kottayam", "puttur", "sullia", "belthangady"]}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--site", default="../../site-sample")
    ap.add_argument("--config", default="../data")
    ap.add_argument("--days", type=int, default=400)
    a = ap.parse_args()
    rnd = random.Random(42)
    now = now_ist()
    today = now.date()
    site, cfg = Path(a.site), Path(a.config)
    pub = Publisher(site, cfg, today)
    rows: list[PriceRow] = []
    for (crop, var), base in BASE.items():
        for mi, mid in enumerate(MARKETS[crop]):
            if crop == "arecanut" and var in ("chali_new", "chali_old") and mid not in (
                    "puttur", "mangaluru", "bantwal", "belthangady", "kundapura", "sirsi"):
                continue
            if crop == "arecanut" and var in ("rashi", "bette", "saraku", "gorabalu") and mid in (
                    "puttur", "mangaluru", "bantwal", "belthangady", "kundapura"):
                continue
            src = "datagov_mandi" if mi % 3 else "sample_partner"
            trust = "official" if src == "datagov_mandi" else "partner"
            for d in range(a.days, -1, -1):
                day = today - timedelta(days=d)
                if day.weekday() == 6:
                    continue
                season = 1 + 0.08 * math.sin((day.timetuple().tm_yday + mi * 9) / 365 * 2 * math.pi)
                digits = 0 if crop == "arecanut" else 1
                modal = round(base * season * (1 + rnd.uniform(-0.01, 0.01)) * (1 + mi * 0.004), digits)
                spread = modal * 0.05
                rows.append(PriceRow(crop=crop, variety=var, marketId=mid, sourceId=src, trust=trust,
                                     min=round(modal - spread, 0 if crop == "arecanut" else 1),
                                     max=round(modal + spread, 0 if crop == "arecanut" else 1),
                                     modal=modal, unit="INR/quintal" if crop == "arecanut" else "INR/kg",
                                     date=day.isoformat(), time="11:30"))
    pub.append_history(rows)
    todays = [r for r in rows if r.date >= (today - timedelta(days=2)).isoformat()]
    markets = {m["id"]: m for m in read_json(cfg / "markets.json", [])}
    latest = pub.build_latest(todays, None, now.strftime("%Y-%m-%dT%H:%M"))
    latest["summary"] = build_summary(latest["rows"], today.isoformat(), markets, None, now.strftime("%Y-%m-%dT%H:%M"))
    latest["summary"]["kn"] = "ಮಾದರಿ ದತ್ತಾಂಶ (SAMPLE) — ನಿಜವಾದ ಧಾರಣೆ ಅಲ್ಲ.\n" + latest["summary"]["kn"]
    latest["summary"]["en"] = "SAMPLE data — not real prices.\n" + latest["summary"]["en"]
    latest["sample"] = True
    write_json_if_changed(site / "data" / "latest.json", latest)
    for name in ("markets.json", "varieties.json"):
        write_json_if_changed(site / "data" / name, read_json(cfg / name, []))
    sources = read_json(cfg / "sources.json", [])
    sources.append({"id": "sample_partner", "type": "partner", "kind": "submission", "enabled": True,
                    "name_en": "Sample Co-op Society (SAMPLE)", "name_kn": "ಮಾದರಿ ಸಹಕಾರ ಸಂಘ (SAMPLE)",
                    "crops": ["arecanut", "rubber"], "defaultMarketId": "puttur",
                    "profile": {"address": "Main Road, Puttur (sample)", "timings": "9:30–5:30, Mon–Sat",
                                "phone": "+91 00000 00000", "lat": 12.76, "lon": 75.20}})
    for s in sources:
        s["score"] = trust_score(None, s["type"])
    write_json_if_changed(site / "data" / "sources.json", sources)
    print(f"SAMPLE data written to {site}/data ({len(rows)} history points)")


if __name__ == "__main__":
    main()
