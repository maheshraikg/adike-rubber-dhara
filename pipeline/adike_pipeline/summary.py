"""Evening summary: facts are computed in code from published rows only.
AI (optional) only rephrases those facts; the template is the no-AI fallback."""
from __future__ import annotations

from typing import Optional

from . import config
from .ai.base import AIProvider, AIUnavailable
from .util import log_event

KEY_VARIETIES = {"arecanut": ["rashi", "chali_new", "bette", "saraku"], "rubber": ["rss4", "rss5"]}
CROP_KN = {"arecanut": "ಅಡಿಕೆ", "rubber": "ರಬ್ಬರ್"}
UNIT_KN = {"arecanut": "ಕ್ವಿಂಟಾಲ್‌ಗೆ", "rubber": "ಕೆಜಿಗೆ"}
UNIT_EN = {"arecanut": "per quintal", "rubber": "per kg"}


def inr(v: float) -> str:
    """Indian digit grouping: 123456 -> ₹1,23,456."""
    neg = v < 0
    n = round(abs(v), 2)
    whole = int(n)
    frac = n - whole
    s = str(whole)
    if len(s) > 3:
        head, tail = s[:-3], s[-3:]
        groups = []
        while len(head) > 2:
            groups.insert(0, head[-2:])
            head = head[:-2]
        if head:
            groups.insert(0, head)
        s = ",".join(groups + [tail])
    if frac >= 0.005:
        s += f"{frac:.2f}"[1:]
    return ("-" if neg else "") + "₹" + s


def pick_facts(rows: list[dict], today: str, markets: dict[str, dict]) -> list[dict]:
    facts = []
    todays = [r for r in rows if r["date"] == today and r.get("modal") is not None]
    for crop, vids in KEY_VARIETIES.items():
        crop_rows = [r for r in todays if r["crop"] == crop]
        if not crop_rows:
            continue
        for vid in vids:
            vr = [r for r in crop_rows if r["variety"] == vid]
            if not vr:
                continue
            vr.sort(key=lambda r: (config.TRUST_ORDER[r["trust"]], -r["modal"]))
            hi = max(vr, key=lambda r: r["modal"])
            lo = min(vr, key=lambda r: r["modal"])
            facts.append({"crop": crop, "variety": vid, "kn": vr[0]["varietyLabel_kn"],
                          "en": vr[0]["varietyLabel_en"], "markets": len(vr),
                          "hi": hi, "lo": lo, "hiMarket": markets.get(hi["marketId"], {}),
                          "loMarket": markets.get(lo["marketId"], {})})
            break
    return facts


def facts_text(facts: list[dict]) -> str:
    lines = []
    for f in facts:
        h, lo = f["hi"], f["lo"]
        chg = f" (change vs previous day {h['changePct']:+.1f}%)" if h.get("changePct") is not None else ""
        lines.append(
            f"{f['crop']} {f['en']}: highest modal {inr(h['modal'])} {UNIT_EN[f['crop']]} at "
            f"{f['hiMarket'].get('en', h['marketId'])}{chg}; lowest modal {inr(lo['modal'])} at "
            f"{f['loMarket'].get('en', lo['marketId'])}; {f['markets']} market(s) reported today.")
    return "\n".join(lines)


def template_summary(facts: list[dict]) -> dict:
    kn, en = [], []
    for f in facts:
        h = f["hi"]
        hm_kn = f["hiMarket"].get("kn", h["marketId"])
        hm_en = f["hiMarket"].get("en", h["marketId"])
        arrow = ""
        if h.get("changePct") is not None:
            arrow = f" ({h['changePct']:+.1f}%)"
        kn.append(f"{CROP_KN[f['crop']]} {f['kn']}: {hm_kn} ಮಾರುಕಟ್ಟೆಯಲ್ಲಿ ಗರಿಷ್ಠ ಸರಾಸರಿ {inr(h['modal'])} "
                  f"{UNIT_KN[f['crop']]}{arrow}; {f['markets']} ಮಾರುಕಟ್ಟೆಗಳ ಧಾರಣೆ ಲಭ್ಯ.")
        en.append(f"{f['crop'].capitalize()} {f['en']}: highest modal {inr(h['modal'])} "
                  f"{UNIT_EN[f['crop']]} at {hm_en}{arrow}; {f['markets']} market(s) reported.")
    if not kn:
        kn.append("ಇಂದು ಹೊಸ ಧಾರಣೆ ಪ್ರಕಟವಾಗಿಲ್ಲ.")
        en.append("No new rates were published today.")
    return {"kn": "\n".join(kn), "en": "\n".join(en)}


def build_summary(rows: list[dict], today: str, markets: dict[str, dict],
                  ai: Optional[AIProvider], generated_at: str) -> dict:
    facts = pick_facts(rows, today, markets)
    out = template_summary(facts)
    out["source"] = "template"
    if ai is not None and facts:
        try:
            s = ai.summarize(facts_text(facts))
            out = {"kn": s.kn.strip(), "en": s.en.strip(), "source": "ai"}
        except AIUnavailable as e:
            log_event("summary.ai_unavailable", error=str(e))
    out.update({"date": today, "generatedAt": generated_at, "evening": True})
    return out
