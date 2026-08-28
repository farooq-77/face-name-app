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
  PLAY_UPLOAD_KEY_ALIAS
  PLAY_UPLOAD_KEY_PASSWORD
  PLAY_UPLOAD_STORE_PASSWORD
)

for key in "${required[@]}"; do
  if [ -z "${!key:-}" ]; then
    echo "Missing environment variable: $key" >&2
    exit 1
  fi
done

if [ ! -f android/upload-keystore.jks ]; then
  echo "Missing android/upload-keystore.jks" >&2
  exit 1
fi

cat > android/key.properties <<EOF
storePassword=$PLAY_UPLOAD_STORE_PASSWORD
keyPassword=$PLAY_UPLOAD_KEY_PASSWORD
keyAlias=$PLAY_UPLOAD_KEY_ALIAS
storeFile=../upload-keystore.jks
EOF

python3 - <<'PY'
from pathlib import Path

p = Path("android/app/build.gradle.kts")
s = p.read_text()

if "import java.util.Properties" not in s:
    s = "import java.util.Properties\nimport java.io.FileInputStream\n\n" + s

marker = "android {"
if marker not in s:
    raise SystemExit("Could not find android block in build.gradle.kts")

props = '''val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (!keystorePropertiesFile.exists()) {
    error("android/key.properties is required for Play release signing")
}
keystoreProperties.load(FileInputStream(keystorePropertiesFile))

'''
if "val keystoreProperties = Properties()" not in s:
    s = s.replace(marker, props + marker, 1)

if "compileSdk = flutter.compileSdkVersion" in s:
    s = s.replace("compileSdk = flutter.compileSdkVersion", "compileSdk = 36")

if "targetSdk = flutter.targetSdkVersion" in s:
    s = s.replace("targetSdk = flutter.targetSdkVersion", "targetSdk = 36")

build_types = "    buildTypes {"
signing = '''    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
            storePassword = keystoreProperties.getProperty("storePassword")
        }
    }

'''
if 'create("release")' not in s:
    if build_types not in s:
        raise SystemExit("Could not find buildTypes block in build.gradle.kts")
    s = s.replace(build_types, signing + build_types, 1)

old = 'signingConfig = signingConfigs.getByName("debug")'
new = 'signingConfig = signingConfigs.getByName("release")'
if old in s:
    s = s.replace(old, new, 1)
elif new not in s:
    raise SystemExit("Could not configure release signing in build.gradle.kts")

p.write_text(s)
PY

flutter build appbundle --release \
  --dart-define="FACE_NAME_API_BASE_URL=$FACE_NAME_API_BASE_URL" \
  --dart-define="FIREBASE_API_KEY=$FIREBASE_API_KEY" \
  --dart-define="FIREBASE_PROJECT_ID=$FIREBASE_PROJECT_ID" \
  --dart-define="FIREBASE_MESSAGING_SENDER_ID=$FIREBASE_MESSAGING_SENDER_ID" \
  --dart-define="FIREBASE_ANDROID_APP_ID=$FIREBASE_ANDROID_APP_ID" \
  --dart-define="GOOGLE_SERVER_CLIENT_ID=$GOOGLE_SERVER_CLIENT_ID"

AAB="build/app/outputs/bundle/release/app-release.aab"
test -f "$AAB"

echo "Built signed Play release bundle: $AAB"
