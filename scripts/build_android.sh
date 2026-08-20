#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../flutter_app"

required=(
  FACE_NAME_API_BASE_URL
  FIREBASE_API_KEY
  FIREBASE_PROJECT_ID
  FIREBASE_MESSAGING_SENDER_ID
  FIREBASE_ANDROID_APP_ID
  GOOGLE_SERVER_CLIENT_ID
)

for key in "${required[@]}"; do
  if [ -z "${!key:-}" ]; then
    echo "Missing environment variable: $key" >&2
    exit 1
  fi
done

flutter build apk --release \
  --dart-define="FACE_NAME_API_BASE_URL=$FACE_NAME_API_BASE_URL" \
  --dart-define="FIREBASE_API_KEY=$FIREBASE_API_KEY" \
  --dart-define="FIREBASE_PROJECT_ID=$FIREBASE_PROJECT_ID" \
  --dart-define="FIREBASE_MESSAGING_SENDER_ID=$FIREBASE_MESSAGING_SENDER_ID" \
  --dart-define="FIREBASE_ANDROID_APP_ID=$FIREBASE_ANDROID_APP_ID" \
  --dart-define="GOOGLE_SERVER_CLIENT_ID=$GOOGLE_SERVER_CLIENT_ID"
