"""Small shared helpers: logging, numbers, dates, HTTP with retry, JSON IO."""
from __future__ import annotations

import hashlib
import json
import logging
import random
import re
import sys
import time
from datetime import date, datetime
from pathlib import Path
from typing import Any

import requests

from . import config

_KN_DIGITS = str.maketrans("೦೧೨೩೪೫೬೭೮೯", "0123456789")


class JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        payload = {"ts": datetime.now(config.IST).isoformat(timespec="seconds"),
                   "level": record.levelname, "msg": record.getMessage()}
        extra = getattr(record, "ctx", None)
        if extra:
            payload.update(extra)
        return json.dumps(payload, ensure_ascii=False, default=str)


def get_logger(name: str = "adike") -> logging.Logger:
    log = logging.getLogger(name)
    if not log.handlers:
        h = logging.StreamHandler(sys.stdout)
        h.setFormatter(JsonFormatter())
        log.addHandler(h)
        log.setLevel(logging.INFO)
        log.propagate = False
    return log


def log_event(msg: str, **ctx: Any) -> None:
    get_logger().info(msg, extra={"ctx": ctx})


def kn_digits_to_ascii(s: str) -> str:
    return s.translate(_KN_DIGITS)


def parse_number(v: Any) -> float | None:
    """Parse '52,500', '₹ 52500.00', Kannada digits. Returns None when absent."""
    if v is None:
        return None
    if isinstance(v, (int, float)):
        return float(v)
    s = kn_digits_to_ascii(str(v)).strip()
    if s in ("", "-", "NA", "N/A", "null", "None", "--"):
        return None
    s = re.sub(r"[₹,\s]|Rs\.?|INR", "", s, flags=re.I)
    try:
        return float(s)
    except ValueError:
        return None


_DATE_FORMATS = ("%d/%m/%Y", "%Y-%m-%d", "%d-%m-%Y", "%d.%m.%Y", "%d/%m/%y", "%d-%b-%Y", "%d %b %Y")


def parse_date(v: Any) -> date | None:
    if v is None:
        return None
    if isinstance(v, date):
        return v
    s = kn_digits_to_ascii(str(v)).strip()
    for fmt in _DATE_FORMATS:
        try:
            return datetime.strptime(s, fmt).date()
        except ValueError:
            continue
    return None


def now_ist() -> datetime:
    return datetime.now(config.IST)


def sha256(data: bytes | str) -> str:
    if isinstance(data, str):
        data = data.encode("utf-8")
    return hashlib.sha256(data).hexdigest()


def dump_min(obj: Any) -> str:
    return json.dumps(obj, ensure_ascii=False, separators=(",", ":"), sort_keys=False)


def write_json_if_changed(path: Path, obj: Any) -> bool:
    text = dump_min(obj)
    if path.exists() and path.read_text(encoding="utf-8") == text:
        return False
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")
    return True


def read_json(path: Path, default: Any = None) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (FileNotFoundError, json.JSONDecodeError):
        return default


def backoff_sleep(attempt: int, base: float = 2.0, cap: float = 60.0) -> None:
    time.sleep(min(cap, base * (2 ** attempt)) + random.uniform(0, 1))


class Fetcher:
    """Polite HTTP client: contact UA, per-source request budget, retries, robots.txt."""

    def __init__(self, max_per_source: int = config.MAX_REQUESTS_PER_SOURCE,
                 session: requests.Session | None = None, sleep=backoff_sleep):
        self.session = session or requests.Session()
        self.session.headers["User-Agent"] = config.USER_AGENT
        self.max_per_source = max_per_source
        self.counts: dict[str, int] = {}
        self._robots: dict[str, Any] = {}
        self._sleep = sleep

    def allowed(self, url: str) -> bool:
        from urllib import robotparser
        from urllib.parse import urlsplit
        parts = urlsplit(url)
        root = f"{parts.scheme}://{parts.netloc}"
        if root not in self._robots:
            rp = robotparser.RobotFileParser()
            try:
                r = self.session.get(root + "/robots.txt", timeout=config.HTTP_TIMEOUT)
                rp.parse(r.text.splitlines() if r.status_code == 200 else [])
            except requests.RequestException:
                rp.parse([])
            self._robots[root] = rp
        return self._robots[root].can_fetch(config.USER_AGENT, url)

    def get(self, source_id: str, url: str, params: dict | None = None,
            check_robots: bool = True, retries: int = 3) -> requests.Response:
        if check_robots and not self.allowed(url):
            raise PermissionError(f"robots.txt disallows {url}")
        last: Exception | None = None
        for attempt in range(retries):
            n = self.counts.get(source_id, 0)
            if n >= self.max_per_source:
                raise RuntimeError(f"request budget exhausted for {source_id}")
            self.counts[source_id] = n + 1
            try:
                r = self.session.get(url, params=params, timeout=config.HTTP_TIMEOUT)
                if r.status_code in (429, 500, 502, 503, 504):
                    raise requests.HTTPError(f"HTTP {r.status_code}", response=r)
                r.raise_for_status()
                return r
            except requests.RequestException as e:
                last = e
                if attempt + 1 < retries:
                    self._sleep(attempt)
        raise RuntimeError(f"fetch failed for {source_id}: {last}")
