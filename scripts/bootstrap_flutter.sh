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

# Keep the Dart project name unchanged, but align the Android application identity
# with the existing Google Play / Firebase app registration.
ANDROID_PACKAGE="com.farooq77.facename"
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
s = s.replace('namespace = "com.farooq77.face_name_app"', 'namespace = "com.farooq77.facename"')
s = s.replace('applicationId = "com.farooq77.face_name_app"', 'applicationId = "com.farooq77.facename"')
s = s.replace("minSdk = flutter.minSdkVersion", "minSdk = 24")
p.write_text(s)
PY
fi

OLD_MAIN="android/app/src/main/kotlin/com/farooq77/face_name_app/MainActivity.kt"
NEW_MAIN_DIR="android/app/src/main/kotlin/com/farooq77/facename"
NEW_MAIN="$NEW_MAIN_DIR/MainActivity.kt"
if [ -f "$OLD_MAIN" ]; then
  mkdir -p "$NEW_MAIN_DIR"
  sed 's/^package com\.farooq77\.face_name_app$/package com.farooq77.facename/' "$OLD_MAIN" > "$NEW_MAIN"
  rm -f "$OLD_MAIN"
  rmdir --ignore-fail-on-non-empty android/app/src/main/kotlin/com/farooq77/face_name_app 2>/dev/null || true
fi

grep -q 'namespace = "com.farooq77.facename"' android/app/build.gradle.kts
grep -q 'applicationId = "com.farooq77.facename"' android/app/build.gradle.kts
grep -q '^package com.farooq77.facename$' "$NEW_MAIN"

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

# Generate Android launcher resources from the approved full Face Name source asset.
# Preserve the artwork itself. Remove only the source's redundant outer dark margin
# before proportional scaling so FACE NAME / Farooq77 are larger and more readable,
# while the complete logo still stays inside Android legacy/adaptive safe zones.
ICON_SOURCE="assets/face_name_launcher.png"
LAUNCHER_BG="#F2F2F2"
if [ -f "$ICON_SOURCE" ]; then
  if command -v magick >/dev/null 2>&1; then
    IMAGE_MAGICK=(magick)
  elif command -v convert >/dev/null 2>&1; then
    IMAGE_MAGICK=(convert)
  else
    echo "ImageMagick is required to generate Android launcher icons." >&2
    exit 1
  fi

  TRIMMED_ICON="$(mktemp --suffix=.png)"
  "${IMAGE_MAGICK[@]}" "$ICON_SOURCE" -auto-orient -fuzz 6% -trim +repage \
    -strip -define png:color-type=6 "$TRIMMED_ICON"

  while read -r density legacy_size foreground_size; do
    legacy_inner=$(( legacy_size * 78 / 100 ))
    foreground_inner=$(( foreground_size * 66 / 100 ))

    "${IMAGE_MAGICK[@]}" -size "${legacy_size}x${legacy_size}" "xc:${LAUNCHER_BG}" \
      \( "$TRIMMED_ICON" -resize "${legacy_inner}x${legacy_inner}>" \) \
      -gravity center -composite -strip -define png:color-type=6 \
      "android/app/src/main/res/mipmap-$density/ic_launcher.png"

    cp "android/app/src/main/res/mipmap-$density/ic_launcher.png" \
      "android/app/src/main/res/mipmap-$density/ic_launcher_round.png"

    "${IMAGE_MAGICK[@]}" -size "${foreground_size}x${foreground_size}" xc:none \
      \( "$TRIMMED_ICON" -resize "${foreground_inner}x${foreground_inner}>" \) \
      -gravity center -composite -strip -define png:color-type=6 \
      "android/app/src/main/res/mipmap-$density/ic_launcher_foreground.png"
  done <<'SIZES'
mdpi 48 108
hdpi 72 162
xhdpi 96 216
xxhdpi 144 324
xxxhdpi 192 432
SIZES

  rm -f "$TRIMMED_ICON"

  mkdir -p android/app/src/main/res/mipmap-anydpi-v26
  mkdir -p android/app/src/main/res/values

  cat > android/app/src/main/res/values/face_name_launcher.xml <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="face_name_launcher_background">#F2F2F2</color>
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

  # Validate with the dedicated identify binary. `convert identify ...` is parsed
  # as an input image named "identify" on ImageMagick 6 runners.
  if command -v magick >/dev/null 2>&1; then
    identify_dims() { magick identify -format '%wx%h' "$1"; }
  elif command -v identify >/dev/null 2>&1; then
    identify_dims() { identify -format '%wx%h' "$1"; }
  else
    echo "ImageMagick identify is required to validate launcher icons." >&2
    exit 1
  fi

  while read -r density legacy_size foreground_size; do
    for name in ic_launcher.png ic_launcher_round.png; do
      path="android/app/src/main/res/mipmap-$density/$name"
      test -s "$path"
      dims="$(identify_dims "$path")"
      test "$dims" = "${legacy_size}x${legacy_size}"
    done
    path="android/app/src/main/res/mipmap-$density/ic_launcher_foreground.png"
    test -s "$path"
    dims="$(identify_dims "$path")"
    test "$dims" = "${foreground_size}x${foreground_size}"
  done <<'SIZES'
mdpi 48 108
hdpi 72 162
xhdpi 96 216
xxhdpi 144 324
xxxhdpi 192 432
SIZES
  grep -q '#F2F2F2' android/app/src/main/res/values/face_name_launcher.xml
  grep -q '@mipmap/ic_launcher_foreground' android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml
  grep -q '@mipmap/ic_launcher_foreground' android/app/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml
fi

flutter pub get

echo "Flutter native Android/iOS scaffold generated with Face Name branding."
