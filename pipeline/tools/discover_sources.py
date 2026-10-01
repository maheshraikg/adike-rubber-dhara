"""Find the actual daily-price pages on official / co-op sites.

Fetches each start page, follows up to 6 links whose text or URL mentions prices,
and prints what it finds (status, title, short text around rupee figures and
variety names). Read-only, a few GET requests per site. Run from GitHub Actions
(adike-probe.yml) because some government sites block other networks.

    python -m tools.discover_sources
"""
from __future__ import annotations

import re
import sys
from urllib.parse import urljoin, urlsplit

import requests
from bs4 import BeautifulSoup

from adike_pipeline import config
from adike_pipeline.util import aia_bundle

START = {
    "rubberboard": ["https://rubberboard.gov.in/rss_indianprice?type=latest",
                    "https://rubberboard.gov.in/public", "https://rubberboard.gov.in/",
                    "https://rubberboard.gov.in/public/rubber-price",
                    "https://rubberboard.gov.in/public/price"],
    "krishimaratavahini": ["https://krishimaratavahini.kar.nic.in/",
                           "https://krishimaratavahini.kar.nic.in/MainPage/DailyMrktPriceRep2.aspx",
                           "https://maratavahini.kar.nic.in/"],
    "agmarknet": ["https://agmarknet.gov.in/", "https://agmarknet.gov.in/SearchCmmMkt.aspx"],
    # co-ops: discovery only; enabling needs written permission
    "campco": ["https://www.campco.org/", "https://campco.org/"],
    "tss_sirsi": ["https://www.tssindia.in/", "https://tssindia.in/"],
    "mamcos": ["https://www.mamcos.in/", "https://mamcos.in/"],
}
LINK_RX = re.compile(r"price|rate|dhara|ಧಾರಣೆ|ದರ|market|mandi|rss|arecanut|supari|daily", re.I)
DATA_RX = re.compile(r"(rss[\s\-]?[45]|isnr|latex|rashi|bette|saraku|chali|gorabalu|"
                     r"₹|rs\.?\s?\d|\d{2,3},\d{3}|\d{3,6}\.\d{2})", re.I)


def snippet(text: str, n: int = 12) -> list[str]:
    lines = [ln.strip() for ln in text.splitlines() if ln.strip()]
    hits = [ln[:160] for ln in lines if DATA_RX.search(ln)]
    return hits[:n]


def visit(s: requests.Session, url: str) -> tuple[int, str, BeautifulSoup | None, str]:
    try:
        try:
            r = s.get(url, timeout=25, allow_redirects=True)
        except requests.exceptions.SSLError as e:
            # follow redirects by hand so each host gets its own AIA bundle
            host = re.sub(r"^https?://([^/]+).*$", r"\1", str(e.request.url if e.request else url))
            bundle = aia_bundle(host)
            if not bundle:
                raise
            r = s.get(url, timeout=25, allow_redirects=True, verify=bundle)
    except requests.RequestException as e:
        return 0, str(e)[:120], None, url
    ctype = r.headers.get("content-type", "")
    if "rss_" in r.url:
        print(f"      raw ({ctype}, {len(r.text)} chars) from {r.url}:")
        for ln in r.text[:6000].splitlines():
            if ln.strip():
                print(f"      | {ln.rstrip()[:200]}")
    elif "xml" in ctype and "html" not in ctype:
        print(f"      xml ({len(r.text)} chars) from {r.url}:")
        for ln in r.text[:4000].splitlines():
            print(f"      | {ln}")
    if "html" not in ctype:
        return r.status_code, ctype, None, r.url
    soup = BeautifulSoup(r.text, "html.parser")
    title = (soup.title.get_text(strip=True) if soup.title else "")[:100]
    return r.status_code, title, soup, r.url


def main() -> None:
    s = requests.Session()
    s.headers["User-Agent"] = config.USER_AGENT
    only = set(sys.argv[1:])
    for name, starts in START.items():
        if only and name not in only:
            continue
        print(f"\n===== {name} =====")
        seen: set[str] = set()
        for start in starts:
            code, title, soup, final = visit(s, start)
            print(f"[start] {start} -> HTTP {code} {final} | {title}")
            if soup is None:
                continue
            for ln in snippet(soup.get_text("\n")):
                print(f"    data: {ln}")
            links = []
            for a in soup.find_all("a", href=True):
                href = urljoin(final, a["href"])
                label = a.get_text(" ", strip=True)[:60]
                if urlsplit(href).netloc != urlsplit(final).netloc:
                    continue
                if (LINK_RX.search(label) or LINK_RX.search(href)) and href not in seen:
                    seen.add(href)
                    links.append((label, href))
            for label, href in links[:6]:
                c2, t2, soup2, f2 = visit(s, href)
                print(f"  [link] '{label}' {href} -> HTTP {c2} | {t2}")
                if soup2 is not None:
                    for ln in snippet(soup2.get_text("\n"), 8):
                        print(f"      data: {ln}")
                    pdfs = [urljoin(f2, a['href']) for a in soup2.find_all('a', href=True)
                            if a['href'].lower().endswith('.pdf')][:3]
                    for p in pdfs:
                        print(f"      pdf: {p}")
            if links and "rss_" not in start:
                break  # first working start page is enough


if __name__ == "__main__":
    main()
