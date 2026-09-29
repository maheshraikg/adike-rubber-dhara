import json
import sys
from datetime import datetime
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from adike_pipeline import config  # noqa: E402
from adike_pipeline.normalize import Normalizer  # noqa: E402

CONFIG_DIR = ROOT.parent / "data"
FIXTURES = Path(__file__).parent / "fixtures"


@pytest.fixture
def config_dir():
    return CONFIG_DIR


@pytest.fixture
def normalizer():
    return Normalizer(json.loads((CONFIG_DIR / "markets.json").read_text()),
                      json.loads((CONFIG_DIR / "varieties.json").read_text()))


@pytest.fixture
def fixture_json():
    return lambda name: json.loads((FIXTURES / name).read_text())


@pytest.fixture
def now():
    return datetime(2026, 9, 29, 17, 30, tzinfo=config.IST)
