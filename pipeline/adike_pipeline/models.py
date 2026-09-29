"""Data models shared by collectors, validation, AI and publishing."""
from __future__ import annotations

from typing import Literal, Optional

from pydantic import BaseModel, Field

Crop = Literal["arecanut", "rubber"]
Trust = Literal["official", "partner", "trader"]


class RawRow(BaseModel):
    """A row as found at the source, before normalisation. Values are never invented."""
    sourceId: str
    crop: Optional[str] = None
    market_raw: Optional[str] = None
    variety_raw: Optional[str] = None
    min: Optional[float] = None
    max: Optional[float] = None
    modal: Optional[float] = None
    unit_raw: Optional[str] = None
    date_raw: Optional[str] = None
    confidence: Optional[float] = None  # None = parsed deterministically (API)
    note: Optional[str] = None
    sourceUrl: Optional[str] = None
    rawExcerpt: Optional[str] = None
    time: Optional[str] = None
    via: Literal["api", "ai", "admin"] = "api"


class PriceRow(BaseModel):
    crop: Crop
    variety: str
    marketId: str
    sourceId: str
    trust: Trust
    min: Optional[float] = None
    max: Optional[float] = None
    modal: Optional[float] = None
    unit: str
    date: str  # ISO yyyy-mm-dd
    time: str = ""  # HH:MM IST when collected
    confidence: Optional[float] = None

    @property
    def key(self) -> str:
        return f"{self.date}_{self.sourceId}_{self.marketId}_{self.crop}_{self.variety}"

    @property
    def series_key(self) -> tuple[str, str, str, str]:
        return (self.sourceId, self.marketId, self.crop, self.variety)


class Flagged(BaseModel):
    row: PriceRow
    flags: list[str]
    rawExcerpt: Optional[str] = None
    sourceUrl: Optional[str] = None


# ---- AI structured output (response_schema) -------------------------------
class AIExtractedRow(BaseModel):
    market: Optional[str] = Field(None, description="Market / APMC / society name exactly as written")
    crop: Optional[Literal["arecanut", "rubber"]] = None
    variety_raw: Optional[str] = Field(None, description="Variety/grade exactly as written")
    min: Optional[float] = None
    max: Optional[float] = None
    modal: Optional[float] = None
    unit: Optional[str] = Field(None, description="Unit exactly as written, e.g. Rs/quintal, Rs/kg, Rs/100kg")
    date: Optional[str] = Field(None, description="Date as dd/mm/yyyy if present")
    confidence: float = Field(0.0, description="0..1 confidence that the numbers are read correctly")
    note: Optional[str] = None


class AIExtraction(BaseModel):
    rows: list[AIExtractedRow] = []
    transcript: Optional[str] = Field(None, description="Plain-text transcript of the price lines (for images)")


class AISummary(BaseModel):
    kn: str
    en: str
