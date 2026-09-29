"""Firestore access (Spark plan: Admin SDK only, no Cloud Functions).

All reads are batched into a handful of queries per run to stay far below the
free quota. MemoryStore is used by tests and when no service account is set.
"""
from __future__ import annotations

import json
import os
from datetime import datetime, timedelta, timezone
from typing import Any, Optional


class Store:
    # config
    def get_doc(self, path: str) -> Optional[dict]: raise NotImplementedError
    def set_doc(self, path: str, data: dict, merge: bool = False) -> None: raise NotImplementedError
    def delete_doc(self, path: str) -> None: raise NotImplementedError
    def query(self, collection: str, field: Optional[str] = None, value: Any = None,
              limit: int = 500) -> list[tuple[str, dict]]: raise NotImplementedError

    # convenience wrappers
    def validation_config(self) -> dict:
        return self.get_doc("config/validation") or {}

    def aliases(self) -> dict:
        return self.get_doc("config/aliases") or {}

    def new_submissions(self, limit: int = 50) -> list[tuple[str, dict]]:
        return self.query("submissions", "status", "new", limit)

    def review_docs(self) -> list[tuple[str, dict]]:
        return self.query("review", limit=1000)

    def approved_partners(self) -> list[tuple[str, dict]]:
        return self.query("partners", "approved", True)

    def active_alerts(self) -> list[tuple[str, dict]]:
        return self.query("alerts", "active", True, limit=5000)

    # custom claims (Auth Admin API; free on Spark)
    def get_claims(self, uid: str) -> dict: raise NotImplementedError
    def set_claims(self, uid: str, claims: dict) -> None: raise NotImplementedError


class MemoryStore(Store):
    def __init__(self, docs: Optional[dict[str, dict]] = None):
        self.docs: dict[str, dict] = {k: dict(v) for k, v in (docs or {}).items()}
        self.claims: dict[str, dict] = {}

    def get_doc(self, path):
        d = self.docs.get(path)
        return dict(d) if d is not None else None

    def set_doc(self, path, data, merge=False):
        if merge and path in self.docs:
            self.docs[path].update(data)
        else:
            self.docs[path] = dict(data)

    def delete_doc(self, path):
        self.docs.pop(path, None)

    def query(self, collection, field=None, value=None, limit=500):
        out = []
        for p, d in self.docs.items():
            col, _, doc_id = p.partition("/")
            if col != collection or "/" in doc_id:
                continue
            if field is None or d.get(field) == value:
                out.append((doc_id, dict(d)))
        return out[:limit]

    def get_claims(self, uid):
        return dict(self.claims.get(uid, {}))

    def set_claims(self, uid, claims):
        self.claims[uid] = dict(claims)


class FirestoreStore(Store):
    def __init__(self, service_account_json: str):
        import firebase_admin
        from firebase_admin import credentials, firestore
        info = json.loads(service_account_json)
        if not firebase_admin._apps:
            firebase_admin.initialize_app(credentials.Certificate(info))
        self.project_id = info.get("project_id")
        self.db = firestore.client()

    def get_doc(self, path):
        snap = self.db.document(path).get()
        return snap.to_dict() if snap.exists else None

    def set_doc(self, path, data, merge=False):
        self.db.document(path).set(data, merge=merge)

    def delete_doc(self, path):
        self.db.document(path).delete()

    def query(self, collection, field=None, value=None, limit=500):
        from google.cloud.firestore_v1.base_query import FieldFilter
        q = self.db.collection(collection)
        if field is not None:
            q = q.where(filter=FieldFilter(field, "==", value))
        return [(s.id, s.to_dict()) for s in q.limit(limit).stream()]

    def get_claims(self, uid):
        from firebase_admin import auth
        return dict(auth.get_user(uid).custom_claims or {})

    def set_claims(self, uid, claims):
        from firebase_admin import auth
        auth.set_custom_user_claims(uid, claims)


def make_store() -> tuple[Store, bool]:
    """Returns (store, is_real). Without FIREBASE_SERVICE_ACCOUNT the pipeline runs
    in offline mode: API data is still published, review/submissions are skipped."""
    sa = os.environ.get("FIREBASE_SERVICE_ACCOUNT", "").strip()
    if not sa:
        return MemoryStore(), False
    return FirestoreStore(sa), True


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def older_than(ts: Any, days: int) -> bool:
    if ts is None:
        return False
    if isinstance(ts, str):
        try:
            ts = datetime.fromisoformat(ts)
        except ValueError:
            return False
    if ts.tzinfo is None:
        ts = ts.replace(tzinfo=timezone.utc)
    return utcnow() - ts > timedelta(days=days)
