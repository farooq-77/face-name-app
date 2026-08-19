import json

import firebase_admin
from firebase_admin import credentials, firestore, storage

from .settings import settings


def init_firebase() -> None:
    if firebase_admin._apps:
        return

    options = {}
    if settings.firebase_storage_bucket:
        options["storageBucket"] = settings.firebase_storage_bucket

    if settings.service_account_json:
        try:
            payload = json.loads(settings.service_account_json)
        except json.JSONDecodeError as exc:
            raise RuntimeError(
                "FIREBASE_SERVICE_ACCOUNT_JSON is not valid JSON"
            ) from exc
        cred = credentials.Certificate(payload)
        firebase_admin.initialize_app(cred, options=options)
    else:
        firebase_admin.initialize_app(options=options)


def db():
    return firestore.client()


def bucket():
    if not settings.firebase_storage_bucket:
        return None
    return storage.bucket()
