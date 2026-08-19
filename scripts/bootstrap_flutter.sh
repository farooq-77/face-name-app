#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/../flutter_app" && pwd)"

cd "$APP_DIR"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

cp -R lib "$TMP_DIR/lib"
cp pubspec.yaml "$TMP_DIR/pubspec.yaml"
cp analysis_options.yaml "$TMP_DIR/analysis_options.yaml"
if [ -d test ]; then cp -R test "$TMP_DIR/test"; fi

rm -rf android ios linux macos windows web

flutter create . \
  --platforms=android,ios \
  --org com.farooq77 \
  --project-name face_name_app

rm -rf lib test
cp -R "$TMP_DIR/lib" ./lib
cp "$TMP_DIR/pubspec.yaml" ./pubspec.yaml
cp "$TMP_DIR/analysis_options.yaml" ./analysis_options.yaml
if [ -d "$TMP_DIR/test" ]; then cp -R "$TMP_DIR/test" ./test; fi

if [ -f android/app/build.gradle.kts ]; then
  python3 - <<'PY'
from pathlib import Path
p = Path("android/app/build.gradle.kts")
s = p.read_text()
s = s.replace("minSdk = flutter.minSdkVersion", "minSdk = 24")
p.write_text(s)
PY
fi

if [ -f ios/Podfile ]; then
  python3 - <<'PY'
from pathlib import Path
p = Path("ios/Podfile")
s = p.read_text()
if "# platform :ios, '13.0'" in s:
    s = s.replace("# platform :ios, '13.0'", "platform :ios, '13.0'")
elif "platform :ios" not in s:
    s = "platform :ios, '13.0'\n" + s
p.write_text(s)
PY
fi

PLIST="ios/Runner/Info.plist"
if [ -f "$PLIST" ]; then
  python3 - <<'PY'
from pathlib import Path
p = Path("ios/Runner/Info.plist")
s = p.read_text()
items = """
\t<key>NSCameraUsageDescription</key>
\t<string>Face Name uses the camera so you can capture a photo for face recognition.</string>
\t<key>NSPhotoLibraryUsageDescription</key>
\t<string>Face Name uses your photo library so you can select images for face recognition.</string>
"""
if "NSCameraUsageDescription" not in s:
    s = s.replace("</dict>", items + "</dict>")
p.write_text(s)
PY
fi

flutter pub get

echo "Flutter native Android/iOS scaffold generated."
