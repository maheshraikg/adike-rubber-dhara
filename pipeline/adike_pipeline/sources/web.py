"""Official pages / PDFs and permitted partner websites -> plain text for AI extraction."""
from __future__ import annotations

import io
import re
from dataclasses import dataclass
from urllib.parse import urljoin

from bs4 import BeautifulSoup

from ..util import Fetcher, sha256


@dataclass
class PageText:
    url: str
    text: str
    kind: str  # html | pdf
    hash: str


def html_to_text(html: str) -> str:
    soup = BeautifulSoup(html, "html.parser")
    for t in soup(["script", "style", "noscript", "nav", "footer", "header"]):
        t.decompose()
    lines: list[str] = []
    for table in soup.find_all("table"):
        for tr in table.find_all("tr"):
            cells = [c.get_text(" ", strip=True) for c in tr.find_all(["th", "td"])]
            if any(cells):
                lines.append("\t".join(cells))
        lines.append("")
        table.decompose()
    body = soup.get_text("\n", strip=True)
    text = "\n".join(lines) + "\n" + body
    return re.sub(r"\n{3,}", "\n\n", text).strip()


def pdf_to_text(data: bytes) -> str:
    import pdfplumber
    out: list[str] = []
    with pdfplumber.open(io.BytesIO(data)) as pdf:
        for page in pdf.pages[:10]:
            for table in page.extract_tables() or []:
                for row in table:
                    out.append("\t".join((c or "").strip() for c in row))
            out.append(page.extract_text() or "")
    return "\n".join(out).strip()


def find_pdf_link(html: str, base: str, pattern: str | None) -> str | None:
    soup = BeautifulSoup(html, "html.parser")
    rx = re.compile(pattern, re.I) if pattern else re.compile(r"\.pdf($|\?)", re.I)
    for a in soup.find_all("a", href=True):
        if rx.search(a["href"]) or rx.search(a.get_text(" ", strip=True)):
            return urljoin(base, a["href"])
    return None


def fetch_source_text(fetcher: Fetcher, source: dict) -> PageText:
    """≤3 requests: the page, optionally one linked PDF (source.pdfLinkPattern)."""
    url = source["url"]
    r = fetcher.get(source["id"], url)
    ctype = r.headers.get("content-type", "")
    if "pdf" in ctype or url.lower().endswith(".pdf"):
        text = pdf_to_text(r.content)
        return PageText(url, text, "pdf", sha256(r.content))
    html = r.text
    if source.get("pdfLinkPattern"):
        link = find_pdf_link(html, url, source["pdfLinkPattern"])
        if link:
            p = fetcher.get(source["id"], link)
            return PageText(link, pdf_to_text(p.content), "pdf", sha256(p.content))
    text = html_to_text(html)
    return PageText(url, text, "html", sha256(text))
