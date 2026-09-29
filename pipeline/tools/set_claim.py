"""Set or remove custom claims (admin / partner) with the service account.

    export FIREBASE_SERVICE_ACCOUNT="$(cat service-account.json)"
    python -m tools.set_claim --email you@gmail.com --admin
    python -m tools.set_claim --email society@gmail.com --partner --source-id puttur_society
    python -m tools.set_claim --email x@gmail.com --clear
    python -m tools.set_claim --email you@gmail.com --show

The user must have signed in to the app (Google) at least once first. Custom
claims work on the free Spark plan (Admin SDK). The user must sign out and in
again (or wait ~1 hour) for new claims to reach the app.
"""
from __future__ import annotations

import argparse
import json
import os
import sys


def main() -> None:
    ap = argparse.ArgumentParser()
    who = ap.add_mutually_exclusive_group(required=True)
    who.add_argument("--email")
    who.add_argument("--uid")
    ap.add_argument("--admin", action="store_true")
    ap.add_argument("--partner", action="store_true")
    ap.add_argument("--source-id")
    ap.add_argument("--clear", action="store_true")
    ap.add_argument("--show", action="store_true")
    a = ap.parse_args()

    sa = os.environ.get("FIREBASE_SERVICE_ACCOUNT")
    if not sa:
        sys.exit("Set FIREBASE_SERVICE_ACCOUNT to the service-account JSON (contents, not path).")
    import firebase_admin
    from firebase_admin import auth, credentials
    firebase_admin.initialize_app(credentials.Certificate(json.loads(sa)))
    user = auth.get_user_by_email(a.email) if a.email else auth.get_user(a.uid)
    claims = dict(user.custom_claims or {})
    if a.show:
        print(user.uid, user.email, claims)
        return
    if a.clear:
        claims = {}
    if a.admin:
        claims["admin"] = True
    if a.partner:
        if not a.source_id:
            sys.exit("--partner needs --source-id")
        claims["partner"] = True
        claims["sourceId"] = a.source_id
    auth.set_custom_user_claims(user.uid, claims or None)
    print("OK", user.uid, user.email, claims)


if __name__ == "__main__":
    main()
