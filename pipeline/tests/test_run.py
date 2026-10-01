"""End-to-end run with fakes: API rows, the Rubber Board parser, a web page via AI,
a partner photo submission, review queue and admin decisions."""
import base64
import json
from pathlib import Path

from adike_pipeline.ai.base import AIProvider, AIUnavailable
from adike_pipeline.models import AIExtractedRow, AIExtraction, AISummary
from adike_pipeline.run import Runner
from adike_pipeline.store import MemoryStore
from adike_pipeline.util import Fetcher


class FakeAI(AIProvider):
    name = "fake"

    def __init__(self, rows=None, fail=False):
        super().__init__(30)
        self.rows, self.fail, self.seen = rows or [], fail, []

    def _extract(self, text, image, mime, hint):
        if self.fail:
            raise AIUnavailable("down")
        self.seen.append((text, bool(image)))
        return AIExtraction(rows=self.rows, transcript="ರಾಶಿ 51000-53000" if image else None)

    def _summarize(self, facts):
        if self.fail:
            raise AIUnavailable("down")
        return AISummary(kn="ಇಂದು " + facts[:10], en="Today " + facts[:10])


class Resp:
    def __init__(self, data=None, text="", status=200, ctype="application/json"):
        self._d, self.text, self.status_code = data, text, status
        self.headers = {"content-type": ctype}
        self.content = text.encode()

    def json(self):
        return self._d

    def raise_for_status(self):
        pass


class Session:
    def __init__(self, fixtures):
        self.fx = fixtures
        self.headers = {}

    def get(self, url, params=None, timeout=None):
        if "robots.txt" in url:
            return Resp(text="", status=404)
        if params:
            key = params.get("filters[commodity.keyword]") or params.get("filters[commodity]")
            state = params.get("filters[state.keyword]") or params.get("filters[state]")
            return Resp(self.fx.get((state, key), {"total": 0, "records": []}))
        if "rubberboard.gov.in" in url:
            return Resp(text=RB_HTML, ctype="text/html")
        return Resp(text="<table><tr><td>RSS-4</td><td>19000</td></tr></table>", ctype="text/html")


RB_HTML = (Path(__file__).parent / "fixtures" / "rubberboard_public.html").read_text()
# stand-in official page that goes through the HTML -> AI path
WEB_SRC = {"id": "gov_rates_page", "type": "official", "kind": "html", "enabled": True,
           "crops": ["rubber"], "name_en": "Test rates page", "name_kn": "ಪರೀಕ್ಷೆ",
           "url": "https://rates.example.gov.in/today", "defaultMarketId": "kottayam"}


def setup(tmp_path, config_dir, fixture_json, sources_extra=None):
    cfg = tmp_path / "cfg"
    cfg.mkdir()
    for n in ("markets.json", "varieties.json"):
        (cfg / n).write_text((config_dir / n).read_text())
    sources = json.loads((config_dir / "sources.json").read_text())
    (cfg / "sources.json").write_text(json.dumps(sources + [WEB_SRC] + (sources_extra or [])))
    site = tmp_path / "site"
    fx = {("Karnataka", "Arecanut(Betelnut/Supari)"): fixture_json("datagov_arecanut.json")}
    return cfg, site, Session(fx)


def make_runner(site, cfg, store, ai, now, sess, evening=False):
    return Runner(site, cfg, store, True, ai, now, evening,
                  fetcher=Fetcher(session=sess, sleep=lambda a: None),
                  api_fetcher=Fetcher(max_per_source=40, session=sess, sleep=lambda a: None),
                  datagov_key="KEY", admin_alert=lambda *a: None)


RUBBER = AIExtractedRow(market="Kottayam", crop="rubber", variety_raw="RSS-4", min=None, max=None,
                        modal=19000, unit="Rs/100kg", date="29/09/2026", confidence=0.95)


def test_full_run(tmp_path, config_dir, fixture_json, now):
    cfg, site, sess = setup(tmp_path, config_dir, fixture_json)
    img = base64.b64encode(b"\xff\xd8fakejpeg").decode()
    store = MemoryStore({
        "partners/u9": {"approved": True, "sourceId": "puttur_society", "name": "Puttur Society",
                        "marketId": "puttur", "phone": "+91 1", "address": "Puttur"},
        "submissions/s1": {"status": "new", "sourceId": "puttur_society", "partnerUid": "u9",
                           "imageB64": img},
    })
    ai = FakeAI([RUBBER])
    res = make_runner(site, cfg, store, ai, now, sess, evening=True).run()

    latest = json.loads((site / "data" / "latest.json").read_text())
    keys = {(r["sourceId"], r["marketId"], r["variety"]) for r in latest["rows"]}
    assert ("datagov_mandi", "shivamogga", "rashi") in keys
    assert ("gov_rates_page", "kottayam", "rss4") in keys
    rss = [r for r in latest["rows"] if r["variety"] == "rss4" and r["sourceId"] == "gov_rates_page"][0]
    assert rss["modal"] == 190 and rss["min"] is None
    # Rubber Board figures parsed straight from the page, ₹/kg, no AI
    rb = {r["variety"]: r["modal"] for r in latest["rows"] if r["sourceId"] == "rubberboard_daily"}
    assert rb == {"rss4": 291.7, "rss5": 285.45, "isnr20": 274.0, "latex60": 212.5}
    assert not any("291.70" in (t or "") for t, _ in ai.seen)
    # Sagar (swapped), Puttur (no modal), Mudigere (unknown market) -> review
    flagged = {k.split("_", 1)[1] for k in store.docs if k.startswith("review/")}
    assert any("sagar" in k for k in flagged)
    assert any("puttur_arecanut" in k and "datagov" in k for k in flagged)
    assert any("mudigere" in k for k in flagged)
    # partner submission processed, photo dropped, text kept
    sub = store.docs["submissions/s1"]
    assert sub["status"] == "processed" and sub["imageB64"] is None
    assert "ರಾಶಿ" in sub["extractedText"]
    assert store.claims["u9"] == {"partner": True, "sourceId": "puttur_society"}
    # summary + run log + raw snapshot
    assert latest["summary"]["evening"] and latest["summary"]["source"] == "ai"
    assert any(k.startswith("runs/") for k in store.docs)
    assert list((site / "raw").glob("*/datagov_mandi.json"))
    srcs = json.loads((site / "data" / "sources.json").read_text())
    assert any(s["id"] == "puttur_society" and s["profile"]["address"] == "Puttur" for s in srcs)
    assert res.changed


def test_admin_decisions_applied_next_run(tmp_path, config_dir, fixture_json, now):
    cfg, site, sess = setup(tmp_path, config_dir, fixture_json)
    store = MemoryStore()
    make_runner(site, cfg, store, FakeAI(), now, sess).run()
    sagar_key = next(k for k in store.docs if k.startswith("review/") and "sagar" in k)
    puttur_key = next(k for k in store.docs if k.startswith("review/") and "puttur_arecanut" in k)
    store.docs[sagar_key]["decision"] = "approve"
    edited = dict(store.docs[puttur_key]["row"], modal=44000)
    store.docs[puttur_key].update(decision="edit", editedRow=edited)

    make_runner(site, cfg, store, FakeAI(), now, sess).run()
    latest = json.loads((site / "data" / "latest.json").read_text())
    by_market = {(r["marketId"], r["variety"]): r for r in latest["rows"]}
    assert by_market[("sagar", "bette")]["min"] == 54000  # swapped + approved
    assert by_market[("puttur", "chali_new")]["modal"] == 44000
    assert store.docs[sagar_key]["status"] == "applied"
    # third run: same values re-extracted are not re-queued, approval still honoured
    make_runner(site, cfg, store, FakeAI(), now, sess).run()
    assert store.docs[sagar_key]["status"] == "applied"


def test_ai_down_defers_and_api_still_publishes(tmp_path, config_dir, fixture_json, now):
    cfg, site, sess = setup(tmp_path, config_dir, fixture_json)
    store = MemoryStore({"partners/u9": {"approved": True, "sourceId": "ps"},
                         "submissions/s1": {"status": "new", "sourceId": "ps", "text": "ರಾಶಿ 52000"}})
    res = make_runner(site, cfg, store, FakeAI(fail=True), now, sess, evening=True).run()
    latest = json.loads((site / "data" / "latest.json").read_text())
    assert any(r["sourceId"] == "datagov_mandi" for r in latest["rows"])
    assert store.docs["submissions/s1"]["status"] == "new"
    assert "deferred" in res.sources["gov_rates_page"].note
    assert res.sources["rubberboard_daily"].rows == 4  # parser needs no AI
    assert any(r["sourceId"] == "rubberboard_daily" for r in latest["rows"])
    assert latest["summary"]["source"] == "template"


def test_unchanged_page_skips_ai(tmp_path, config_dir, fixture_json, now):
    cfg, site, sess = setup(tmp_path, config_dir, fixture_json)
    store = MemoryStore()
    ai = FakeAI([RUBBER])
    make_runner(site, cfg, store, ai, now, sess).run()
    ai2 = FakeAI([RUBBER])
    r2 = make_runner(site, cfg, store, ai2, now, sess).run()
    assert ai2.calls == 0 and "unchanged" in r2.sources["gov_rates_page"].note
    # latest.json is not rewritten when nothing changed (ETag stays the same)
    assert "data/latest.json" not in r2.changed_files
