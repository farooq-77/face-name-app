# Face Name Backend

FastAPI service using `face_recognition` and Firebase Admin.

## Secrets

Use one of:
1. Google Application Default Credentials, or
2. `FIREBASE_SERVICE_ACCOUNT_JSON` containing the complete service-account JSON string.

Never commit the service account.

## Local Linux

```bash
sudo apt-get update
sudo apt-get install -y build-essential cmake libopenblas-dev liblapack-dev
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload
```

## Render / Docker

The package includes `Dockerfile` and `render.yaml`.

Set:
- `FIREBASE_SERVICE_ACCOUNT_JSON`
- `FIREBASE_STORAGE_BUCKET`
- optionally `FACE_MATCH_TOLERANCE` (default 0.50)

Endpoints:
- `GET /health`
- `POST /v1/recognize`
- `POST /v1/faces`
- `GET /v1/faces`
- `DELETE /v1/faces/{face_id}`

All `/v1` endpoints require a valid Firebase ID token.
