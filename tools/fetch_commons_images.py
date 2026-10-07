"""Download candidate photos from Wikimedia Commons (free licences only) with
their attribution, for picking app images. Run from GitHub Actions
(adike-images.yml); writes images/candidates/<slug>_<n>.jpg + credits.json.

    python tools/fetch_commons_images.py
"""
from __future__ import annotations

import json
import re
from pathlib import Path

import requests

API = "https://commons.wikimedia.org/w/api.php"
UA = "AdikeRubberRates/1.0 (https://github.com/maheshraikg/adike-rubber-dhara; maheshraikg@gmail.com)"
QUERIES = {
    "arecanut_bunch": "Areca catechu nuts bunch",
    "arecanut_tree": "Areca catechu plantation Karnataka",
    "arecanut_dried": "Areca nut dried supari",
    "arecanut_harvest": "Arecanut harvest",
    "rubber_tapping": "Rubber tapping latex Kerala",
    "rubber_sheets": "Rubber sheets drying",
    "rubber_plantation": "Hevea brasiliensis plantation",
    "market": "Agricultural market India sacks",
}
OK_LICENCE = re.compile(r"^(cc0|cc[- ]by(-sa)?[- ]?[0-9.]*|public domain|pd)", re.IGNORECASE)
OUT = Path("images/candidates")


def search(q: str, n: int = 6) -> list[dict]:
    r = requests.get(API, params={
        "action": "query", "format": "json", "generator": "search", "gsrsearch": f"{q} filetype:bitmap",
        "gsrnamespace": 6, "gsrlimit": 20, "prop": "imageinfo",
        "iiprop": "url|extmetadata|size", "iiurlwidth": 1280,
    }, headers={"User-Agent": UA}, timeout=60)
    pages = sorted((r.json().get("query") or {}).get("pages", {}).values(), key=lambda p: p.get("index", 99))
    out = []
    for p in pages:
        ii = (p.get("imageinfo") or [{}])[0]
        meta = ii.get("extmetadata") or {}
        lic = (meta.get("LicenseShortName") or {}).get("value", "")
        if not OK_LICENCE.match(lic) or ii.get("width", 0) < 1000:
            continue
        artist = re.sub(r"<[^>]+>", "", (meta.get("Artist") or {}).get("value", "")).strip()
        out.append({"title": p["title"], "thumb": ii.get("thumburl"), "page": ii.get("descriptionurl"),
                    "licence": lic, "licence_url": (meta.get("LicenseUrl") or {}).get("value", ""),
                    "author": artist[:120]})
        if len(out) >= n:
            break
    return out


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    credits = {}
    for slug, q in QUERIES.items():
        for i, c in enumerate(search(q)):
            name = f"{slug}_{i}.jpg"
            data = requests.get(c["thumb"], headers={"User-Agent": UA}, timeout=60).content
            (OUT / name).write_bytes(data)
            credits[name] = c
            print(name, c["licence"], c["title"])
    (OUT / "credits.json").write_text(json.dumps(credits, indent=1, ensure_ascii=False))


if __name__ == "__main__":
    main()
