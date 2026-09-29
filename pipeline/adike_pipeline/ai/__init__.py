"""AI provider factory. To switch providers (e.g. a paid model later), add a class
implementing ai.base.AIProvider and return it here."""
from __future__ import annotations

import os

from .base import AIBudgetExceeded, AIProvider, AIUnavailable, DisabledAI

__all__ = ["make_provider", "AIProvider", "AIUnavailable", "AIBudgetExceeded", "DisabledAI"]


def make_provider(cfg: dict) -> AIProvider:
    if not cfg.get("aiEnabled", True):
        return DisabledAI("aiEnabled=false in config/validation")
    key = os.environ.get("GEMINI_API_KEY", "").strip()
    if not key:
        return DisabledAI("GEMINI_API_KEY not set")
    from .gemini import GeminiProvider
    return GeminiProvider(api_key=key, max_calls=int(cfg.get("maxAiCallsPerRun", 30)))
