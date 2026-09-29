from adike_pipeline.normalize import normalize
from adike_pipeline.sources import datagov
from adike_pipeline.util import Fetcher

T = "2026-09-29T11:30"


def test_parse_fixture(fixture_json, normalizer):
    rows = datagov.parse_records(fixture_json("datagov_arecanut.json")["records"], "arecanut", T)
    assert len(rows) == 4
    assert rows[0].market_raw == "Shimoga" and rows[0].modal == 52500 and rows[0].min == 50000
    assert rows[2].modal is None  # empty modal stays missing
    norm = [normalize(r, normalizer, "official", T) for r in rows]
    assert norm[0][0].marketId == "shivamogga" and norm[0][1] == []
    assert norm[2][0].variety == "chali_new"
    assert "unknown_market" in norm[3][1]


def test_parse_historical_field_names(fixture_json, normalizer):
    rows = datagov.parse_records(fixture_json("datagov_rubber.json")["records"], "rubber", T)
    r, flags = normalize(rows[0], normalizer, "official", T)
    assert (r.marketId, r.variety, r.modal) == ("kottayam", "rss4", 190)
    assert flags == []


def test_build_params_keyword_style():
    p = datagov.build_params("K", "Karnataka", "Arecanut(Betelnut/Supari)", 0, True)
    assert p["filters[state.keyword]"] == "Karnataka"
    assert p["filters[commodity.keyword]"] == "Arecanut(Betelnut/Supari)"
    p = datagov.build_params("K", "Kerala", "Rubber", 1000, False)
    assert p["filters[state]"] == "Kerala" and p["offset"] == 1000


class FakeResp:
    def __init__(self, data, status=200):
        self._d, self.status_code, self.headers = data, status, {}

    def json(self):
        return self._d

    def raise_for_status(self):
        pass


class FakeSession:
    def __init__(self, fixture):
        self.fixture = fixture
        self.headers = {}
        self.calls = []

    def get(self, url, params=None, timeout=None):
        self.calls.append(params)
        if any(k.endswith(".keyword]") for k in params):
            return FakeResp({"total": 0, "records": []})  # keyword form not supported
        return FakeResp(self.fixture)


def test_fetch_falls_back_to_plain_filters(fixture_json):
    sess = FakeSession(fixture_json("datagov_arecanut.json"))
    f = Fetcher(max_per_source=10, session=sess, sleep=lambda a: None)
    recs = datagov.fetch_query(f, "K", "Karnataka", "Arecanut(Betelnut/Supari)")
    assert len(recs) == 4
    assert len(sess.calls) == 2
