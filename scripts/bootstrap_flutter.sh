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

# Generate Android launcher resources from the approved Face Name source asset.
# Legacy icons get a black square canvas with safe padding. Adaptive icons use
# the same exact source as a centered foreground over a black background, so
# Android launchers can crop to circle/squircle shapes without reverting to the
# default Flutter mark or clipping the Face Name symbol.
ICON_SOURCE="assets/face_name_launcher.png"
if [ -f "$ICON_SOURCE" ]; then
  if command -v magick >/dev/null 2>&1; then
    IMAGE_MAGICK=(magick)
  elif command -v convert >/dev/null 2>&1; then
    IMAGE_MAGICK=(convert)
  else
    echo "ImageMagick is required to generate Android launcher icons." >&2
    exit 1
  fi

  while read -r density legacy_size foreground_size; do
    legacy_inner=$(( legacy_size * 78 / 100 ))
    foreground_inner=$(( foreground_size * 66 / 100 ))

    "${IMAGE_MAGICK[@]}" -size "${legacy_size}x${legacy_size}" xc:black \
      \( "$ICON_SOURCE" -auto-orient -resize "${legacy_inner}x${legacy_inner}" \) \
      -gravity center -composite -strip -define png:color-type=6 \
      "android/app/src/main/res/mipmap-$density/ic_launcher.png"

    cp "android/app/src/main/res/mipmap-$density/ic_launcher.png" \
      "android/app/src/main/res/mipmap-$density/ic_launcher_round.png"

    "${IMAGE_MAGICK[@]}" -size "${foreground_size}x${foreground_size}" xc:none \
      \( "$ICON_SOURCE" -auto-orient -resize "${foreground_inner}x${foreground_inner}" \) \
      -gravity center -composite -strip -define png:color-type=6 \
      "android/app/src/main/res/mipmap-$density/ic_launcher_foreground.png"
  done <<'SIZES'
mdpi 48 108
hdpi 72 162
xhdpi 96 216
xxhdpi 144 324
xxxhdpi 192 432
SIZES

  mkdir -p android/app/src/main/res/mipmap-anydpi-v26
  mkdir -p android/app/src/main/res/values

  cat > android/app/src/main/res/values/face_name_launcher.xml <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="face_name_launcher_background">#000000</color>
</resources>
XML

  cat > android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/face_name_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
XML

  cat > android/app/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/face_name_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
XML

  python3 - <<'PY'
from pathlib import Path
p = Path("android/app/src/main/AndroidManifest.xml")
s = p.read_text()
if 'android:roundIcon=' not in s:
    s = s.replace(
        'android:icon="@mipmap/ic_launcher"',
        'android:icon="@mipmap/ic_launcher"\n        android:roundIcon="@mipmap/ic_launcher_round"',
    )
p.write_text(s)
PY
fi

flutter pub get

echo "Flutter native Android/iOS scaffold generated with Face Name branding."
