import pytest

from adike_pipeline.ai import make_provider
from adike_pipeline.ai.base import AIBudgetExceeded, AIUnavailable, DisabledAI
from adike_pipeline.ai.gemini import GeminiProvider, parse_structured
from adike_pipeline.models import AIExtraction, AISummary

GOOD = '{"rows":[{"market":"Puttur","crop":"arecanut","variety_raw":"ಹೊಸ ಚಾಲಿ","min":42000,' \
       '"max":46000,"modal":45000,"unit":"Rs/quintal","date":"29/09/2026","confidence":0.93}],' \
       '"transcript":"ಹೊಸ ಚಾಲಿ 42000-46000"}'


class Resp:
    def __init__(self, text=None, parsed=None):
        self.text, self.parsed = text, parsed


class RateLimit(Exception):
    code = 429


class FakeModels:
    def __init__(self, script):
        self.script = list(script)
        self.calls = []

    def generate_content(self, model, contents, config):
        self.calls.append(model)
        item = self.script.pop(0)
        if isinstance(item, Exception):
            raise item
        return item


class FakeClient:
    def __init__(self, script):
        self.models = FakeModels(script)


def provider(script, max_calls=5):
    return GeminiProvider("k", max_calls, client=FakeClient(script), model="m1", fallback="m2",
                          sleep=lambda s: None)


def test_parse_text_json_and_fences():
    e = parse_structured(Resp(text=GOOD), AIExtraction)
    assert e.rows[0].modal == 45000 and e.rows[0].variety_raw == "ಹೊಸ ಚಾಲಿ"
    e = parse_structured(Resp(text="```json\n" + GOOD + "\n```"), AIExtraction)
    assert len(e.rows) == 1
    parsed = AIExtraction(rows=[])
    assert parse_structured(Resp(parsed=parsed), AIExtraction) is parsed
    with pytest.raises(ValueError):
        parse_structured(Resp(text="not json"), AIExtraction)


def test_extract_ok_counts_calls():
    p = provider([Resp(text=GOOD)])
    out = p.extract(text="ಪುತ್ತೂರು ಹೊಸ ಚಾಲಿ ...")
    assert out.rows[0].min == 42000 and p.calls == 1


def test_429_backoff_then_fallback_model():
    p = provider([RateLimit("429"), RateLimit("429"), RateLimit("429"), Resp(text=GOOD)])
    out = p.extract(text="x")
    assert len(out.rows) == 1
    assert p.client.models.calls == ["m1", "m1", "m1", "m2"]


def test_all_rate_limited_raises_unavailable():
    p = provider([RateLimit("429")] * 6)
    with pytest.raises(AIUnavailable):
        p.extract(text="x")


def test_non_retryable_error_is_unavailable():
    class Bad(Exception):
        code = 400
    p = provider([Bad("bad request")])
    with pytest.raises(AIUnavailable):
        p.extract(text="x")


def test_budget():
    p = provider([Resp(text=GOOD)], max_calls=1)
    p.extract(text="x")
    with pytest.raises(AIBudgetExceeded):
        p.extract(text="y")


def test_summary_schema():
    p = provider([Resp(text='{"kn":"ಇಂದು","en":"Today"}')])
    s = p.summarize("facts")
    assert isinstance(s, AISummary) and s.en == "Today"


def test_factory_disabled(monkeypatch):
    monkeypatch.delenv("GEMINI_API_KEY", raising=False)
    assert isinstance(make_provider({"aiEnabled": True}), DisabledAI)
    monkeypatch.setenv("GEMINI_API_KEY", "x")
    assert isinstance(make_provider({"aiEnabled": False}), DisabledAI)
    with pytest.raises(AIUnavailable):
        DisabledAI().extract(text="x")
