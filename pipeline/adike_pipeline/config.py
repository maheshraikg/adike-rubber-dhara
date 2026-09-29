"""Single place for constants. Change the AI model here only."""
from __future__ import annotations

import os
from datetime import timedelta, timezone

APP_NAME = "AdikeRubberDhara"
# MET Norway and polite scraping both require a contact address in the UA.
CONTACT_EMAIL = os.environ.get("ADIKE_CONTACT_EMAIL", "maheshraikg@gmail.com")
USER_AGENT = f"{APP_NAME}/1.0 (+https://github.com/maheshraikg/adike-rubber-dhara; {CONTACT_EMAIL})"

# --- AI (Gemini free tier). Swap provider in ai/__init__.py -----------------
GEMINI_MODEL = os.environ.get("GEMINI_MODEL", "gemini-2.5-flash")
GEMINI_FALLBACK_MODEL = os.environ.get("GEMINI_FALLBACK_MODEL", "gemini-2.5-flash-lite")
AI_MAX_RETRIES = 3
AI_BACKOFF_SECONDS = 8.0

# --- data.gov.in ---------------------------------------------------------
DATAGOV_BASE = "https://api.data.gov.in/resource/"
DATAGOV_DAILY_RESOURCE = os.environ.get(
    "DATAGOV_DAILY_RESOURCE", "9ef84268-d588-465a-a308-a864a43d0070")
# Historical variety-wise resource used by tools/backfill.py (verify with tools/probe_sources.py).
DATAGOV_HISTORY_RESOURCE = os.environ.get(
    "DATAGOV_HISTORY_RESOURCE", "35985678-0d79-46b4-9ed6-6f13308a1d24")
DATAGOV_QUERIES = [
    {"state": "Karnataka", "commodity": "Arecanut(Betelnut/Supari)", "crop": "arecanut"},
    {"state": "Kerala", "commodity": "Rubber", "crop": "rubber"},
    {"state": "Karnataka", "commodity": "Rubber", "crop": "rubber"},
]
DATAGOV_PAGE_LIMIT = 1000
DATAGOV_MAX_PAGES = 5

# --- fetching ------------------------------------------------------------
MAX_REQUESTS_PER_SOURCE = 3
HTTP_TIMEOUT = 30

# --- publishing ----------------------------------------------------------
HISTORY_DAYS = 400
LATEST_MAX_AGE_DAYS = 7
RAW_KEEP_DAYS = 90
MAX_DATE_AGE_DAYS = 3

IST = timezone(timedelta(hours=5, minutes=30))

DEFAULT_VALIDATION = {
    "arecanut": {"minQtl": 5000, "maxQtl": 150000},
    "rubber": {"minKg": 50, "maxKg": 500},
    "maxDailyChangePct": 8,
    "maxCrossSourceDiffPct": 10,
    "aiEnabled": True,
    "maxAiCallsPerRun": 30,
    "minAiConfidence": 0.8,
}

CANONICAL_UNIT = {"arecanut": "INR/quintal", "rubber": "INR/kg"}
TRUST_ORDER = {"official": 0, "partner": 1, "trader": 2}
