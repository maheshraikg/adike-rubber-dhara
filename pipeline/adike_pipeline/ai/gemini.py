"""Google Gemini (free tier) implementation using the google-genai SDK with structured output."""
from __future__ import annotations

import json
import time
from typing import Callable, Optional, Type

from pydantic import BaseModel, ValidationError

from .. import config
from ..models import AIExtraction, AISummary
from ..util import log_event
from .base import EXTRACTION_RULES, SUMMARY_RULES, AIProvider, AIUnavailable


def _is_rate_limit(e: Exception) -> bool:
    code = getattr(e, "code", None) or getattr(e, "status_code", None)
    return code == 429 or "429" in str(e) or "RESOURCE_EXHAUSTED" in str(e)


def _is_retryable(e: Exception) -> bool:
    code = getattr(e, "code", None) or getattr(e, "status_code", None)
    return _is_rate_limit(e) or code in (500, 502, 503, 504)


def parse_structured(resp, model: Type[BaseModel]) -> BaseModel:
    """Use resp.parsed when the SDK provides it, else parse resp.text as JSON."""
    parsed = getattr(resp, "parsed", None)
    if isinstance(parsed, model):
        return parsed
    if isinstance(parsed, dict):
        return model.model_validate(parsed)
    text = (getattr(resp, "text", None) or "").strip()
    if text.startswith("```"):
        text = text.strip("`").split("\n", 1)[-1]
    try:
        return model.model_validate(json.loads(text))
    except (json.JSONDecodeError, ValidationError) as e:
        raise ValueError(f"unparseable AI output: {e}") from e


class GeminiProvider(AIProvider):
    name = "gemini"

    def __init__(self, api_key: str, max_calls: int, client=None,
                 model: str = config.GEMINI_MODEL, fallback: str = config.GEMINI_FALLBACK_MODEL,
                 sleep: Callable[[float], None] = time.sleep):
        super().__init__(max_calls)
        if client is None:
            from google import genai
            client = genai.Client(api_key=api_key)
        self.client = client
        self.models = [model] + ([fallback] if fallback and fallback != model else [])
        self._sleep = sleep

    def _generate(self, contents, schema: Type[BaseModel], system: str) -> BaseModel:
        from google.genai import types
        cfg = types.GenerateContentConfig(
            system_instruction=system, temperature=0,
            response_mime_type="application/json", response_schema=schema)
        last: Exception | None = None
        for model in self.models:
            for attempt in range(config.AI_MAX_RETRIES):
                try:
                    resp = self.client.models.generate_content(model=model, contents=contents, config=cfg)
                    return parse_structured(resp, schema)
                except ValueError as e:  # bad JSON: one more try, then give up on this item
                    last = e
                    if attempt >= 1:
                        raise AIUnavailable(str(e)) from e
                except Exception as e:  # noqa: BLE001 - SDK raises several error types
                    last = e
                    if not _is_retryable(e):
                        raise AIUnavailable(f"{model}: {e}") from e
                    wait = config.AI_BACKOFF_SECONDS * (2 ** attempt)
                    log_event("ai.backoff", model=model, attempt=attempt, wait=wait, error=str(e)[:200])
                    self._sleep(wait)
            log_event("ai.fallback_model", from_model=model)
        raise AIUnavailable(f"AI unavailable after retries: {last}")

    def _extract(self, text: Optional[str], image: Optional[bytes], mime: str, hint: str) -> AIExtraction:
        from google.genai import types
        parts: list = []
        if hint:
            parts.append(f"Context: {hint}")
        if text:
            parts.append("SOURCE TEXT:\n" + text[:30000])
        if image:
            parts.append(types.Part.from_bytes(data=image, mime_type=mime))
        return self._generate(parts, AIExtraction, EXTRACTION_RULES)  # type: ignore[return-value]

    def _summarize(self, facts: str) -> AISummary:
        return self._generate(["FACTS:\n" + facts], AISummary, SUMMARY_RULES)  # type: ignore[return-value]
