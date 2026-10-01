"""Probe data sources and print what works. Run from GitHub Actions (adike-probe.yml)
or locally; paste the output into docs/DATA_SOURCES.md.

    DATA_GOV_IN_KEY=... python -m tools.probe_sources --config ../data
"""
from __future__ import annotations

import argparse
import os
from pathlib import Path

import requests

from adike_pipeline import config
from adike_pipeline.util import read_json


def probe_datagov(key: str) -> None:
    s = requests.Session()
    s.headers["User-Agent"] = config.USER_AGENT
    for resource in (config.DATAGOV_DAILY_RESOURCE, config.DATAGOV_HISTORY_RESOURCE):
        url = config.DATAGOV_BASE + resource
        for q in config.DATAGOV_QUERIES:
            for style in ("{f}.keyword", "{f}", "{F}"):
                params = {"api-key": key, "format": "json", "limit": 3}
                for f in ("state", "commodity"):
                    name = style.format(f=f, F=f.capitalize())
                    params[f"filters[{name}]"] = q[f]
                try:
                    r = s.get(url, params=params, timeout=30)
                    data = r.json() if r.headers.get("content-type", "").startswith("application/json") else {}
                    recs = data.get("records") or []
                    print(f"[datagov] {resource} {style:12} {q['state']:9} {q['commodity']:26} "
                          f"HTTP {r.status_code} total={data.get('total')} got={len(recs)} "
                          f"fields={list(recs[0].keys()) if recs else '-'}")
                except Exception as e:  # noqa: BLE001
                    print(f"[datagov] {resource} {style} ERROR {e}")


def probe_pages(cfg: Path) -> None:
    s = requests.Session()
    s.headers["User-Agent"] = config.USER_AGENT
    for src in read_json(cfg / "sources.json", []):
        if src["kind"] not in ("html", "pdf"):
            continue
        try:
            r = s.get(src["url"], timeout=30)
            print(f"[page] {src['id']:20} HTTP {r.status_code} {r.headers.get('content-type')} "
                  f"len={len(r.content)} final={r.url}")
            low = r.text.lower()
            for word in ("rss", "rashi", "arecanut", "rubber", "price", ".pdf"):
                if word in low:
                    print(f"        contains '{word}'")
        except Exception as e:  # noqa: BLE001
            print(f"[page] {src['id']:20} ERROR {e}")
    try:
        r = s.get("https://api.met.no/weatherapi/locationforecast/2.0/compact?lat=12.76&lon=75.2", timeout=30)
        print(f"[met.no] HTTP {r.status_code} expires={r.headers.get('expires')}")
    except Exception as e:  # noqa: BLE001
        print(f"[met.no] ERROR {e}")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--config", default="../data")
    a = ap.parse_args()
    key = os.environ.get("DATA_GOV_IN_KEY", "")
    if not key:
        print("DATA_GOV_IN_KEY not set: probing with data.gov.in's public sample key")
    probe_datagov(key or config.DATAGOV_SAMPLE_KEY)
    probe_pages(Path(a.config))


if __name__ == "__main__":
    main()
