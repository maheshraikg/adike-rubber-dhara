"""Live check of the Rubber Board parser: prints the rows it reads and the text
around the rate box (to spot a printed date). Read-only, one or two GET requests.

    python -m tools.check_rubberboard
"""
from __future__ import annotations

import json

from adike_pipeline.sources import rubberboard
from adike_pipeline.util import Fetcher, now_ist

SOURCE = {"id": rubberboard.SOURCE_ID, "url": "https://rubberboard.gov.in/public"}


def main() -> None:
    rows, text = rubberboard.collect(Fetcher(), SOURCE, now_ist().strftime("%Y-%m-%dT%H:%M"))
    for r in rows:
        print(json.dumps(r.model_dump(exclude={"rawExcerpt"}), ensure_ascii=False))
    print("--- text around the rate box ---")
    print(rows[0].rawExcerpt if rows else text[:1500])
    if not rows:
        raise SystemExit("rate box not found")


if __name__ == "__main__":
    main()
