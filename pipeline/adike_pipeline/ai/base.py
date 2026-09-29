"""Provider-agnostic AI interface. Add a new provider by implementing AIProvider."""
from __future__ import annotations

from abc import ABC, abstractmethod
from typing import Optional

from ..models import AIExtraction, AISummary


class AIUnavailable(Exception):
    """AI disabled, rate-limited beyond retries, or no key. Callers defer work to the next run."""


class AIBudgetExceeded(AIUnavailable):
    pass


EXTRACTION_RULES = """You extract agricultural commodity prices (arecanut / ಅಡಿಕೆ and natural rubber / ರಬ್ಬರ್)
from the text or image given. Rules:
- Extract ONLY numbers that are explicitly present. Never estimate, calculate, average or guess.
- If a value (min, max or modal/average) is not written, return null for it.
- Keep the ORIGINAL unit as written (e.g. "Rs/quintal", "Rs/kg", "Rs/100kg"); do not convert.
- Convert Kannada numerals (೦-೯) to ASCII digits. Remove thousands separators.
- market: the market/APMC/society/place name as written. variety_raw: variety or grade as written
  (e.g. Rashi, Bette, Saraku, Gorabalu, Api, Chali, Coca, RSS-4, RSS-5, ISNR-20, Latex).
- date: the price date as dd/mm/yyyy if it is written; else null.
- confidence: your confidence (0..1) that you read the numbers correctly. Skip rows you are unsure of.
- If there is no price data, return an empty list.
- For an image, also fill `transcript` with the plain text of the price lines only
  (no phone numbers, no personal names other than the business name).
"""

SUMMARY_RULES = """Write a short factual market summary for arecanut and rubber growers in Karnataka.
Use ONLY the facts given below. 3–4 short lines. No selling/buying advice, no predictions,
no reasons unless stated. Give one version in Kannada (kn) and one in English (en).
Prices: arecanut in ₹ per quintal, rubber in ₹ per kg. Use Indian digit grouping (e.g. ₹52,500).
"""


class AIProvider(ABC):
    name = "base"

    def __init__(self, max_calls: int):
        self.max_calls = max_calls
        self.calls = 0

    def _spend(self) -> None:
        if self.calls >= self.max_calls:
            raise AIBudgetExceeded(f"maxAiCallsPerRun={self.max_calls} reached")
        self.calls += 1

    def extract(self, text: Optional[str] = None, image: Optional[bytes] = None,
                mime: str = "image/jpeg", hint: str = "") -> AIExtraction:
        self._spend()
        return self._extract(text, image, mime, hint)

    def summarize(self, facts: str) -> AISummary:
        self._spend()
        return self._summarize(facts)

    @abstractmethod
    def _extract(self, text, image, mime, hint) -> AIExtraction: ...

    @abstractmethod
    def _summarize(self, facts: str) -> AISummary: ...


class DisabledAI(AIProvider):
    name = "disabled"

    def __init__(self, reason: str = "AI disabled"):
        super().__init__(0)
        self.reason = reason

    def extract(self, *a, **k) -> AIExtraction:
        raise AIUnavailable(self.reason)

    def summarize(self, facts: str) -> AISummary:
        raise AIUnavailable(self.reason)

    def _extract(self, *a):  # pragma: no cover
        raise AIUnavailable(self.reason)

    def _summarize(self, facts):  # pragma: no cover
        raise AIUnavailable(self.reason)
