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

# Keep the existing project/package identity, but use the product name users see.
ANDROID_MANIFEST="android/app/src/main/AndroidManifest.xml"
if [ -f "$ANDROID_MANIFEST" ]; then
  python3 - <<'PY'
from pathlib import Path
p = Path("android/app/src/main/AndroidManifest.xml")
s = p.read_text()
s = s.replace('android:label="face_name_app"', 'android:label="Face Name"')
p.write_text(s)
PY
fi

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
s = s.replace("<string>face_name_app</string>", "<string>Face Name</string>")
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

# Apply the approved Face Name symbol-only launcher icon after Flutter regenerates
# the native Android scaffold. Android scales the square source per density.
ICON_SOURCE="assets/face_name_launcher.png"
if [ -f "$ICON_SOURCE" ]; then
  for density in mdpi hdpi xhdpi xxhdpi xxxhdpi; do
    cp "$ICON_SOURCE" "android/app/src/main/res/mipmap-$density/ic_launcher.png"
  done
fi

flutter pub get

echo "Flutter native Android/iOS scaffold generated with Face Name branding."
