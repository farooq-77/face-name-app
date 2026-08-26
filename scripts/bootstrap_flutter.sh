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
# the native Android scaffold. Strip embedded ICC/text metadata first because AAPT2
# can reject otherwise-valid PNGs with unsupported ancillary color-profile chunks.
ICON_SOURCE="assets/face_name_launcher.png"
if [ -f "$ICON_SOURCE" ]; then
  SANITIZED_ICON="$TMP_DIR/face_name_launcher_android.png"
  python3 - "$ICON_SOURCE" "$SANITIZED_ICON" <<'PY'
from pathlib import Path
import struct
import sys

src = Path(sys.argv[1]).read_bytes()
if src[:8] != b"\x89PNG\r\n\x1a\n":
    raise SystemExit("Launcher asset is not a PNG")

# Keep only chunks needed to decode/render the PNG plus transparency and physical
# pixel information. This preserves the exact artwork while removing ICC/text
# metadata that Android resource compilation does not need.
keep = {b"IHDR", b"PLTE", b"IDAT", b"IEND", b"tRNS", b"pHYs"}
out = bytearray(src[:8])
pos = 8
while pos + 12 <= len(src):
    length = struct.unpack(">I", src[pos:pos + 4])[0]
    end = pos + 12 + length
    if end > len(src):
        raise SystemExit("Malformed launcher PNG")
    chunk_type = src[pos + 4:pos + 8]
    if chunk_type in keep:
        out.extend(src[pos:end])
    pos = end
    if chunk_type == b"IEND":
        break
Path(sys.argv[2]).write_bytes(out)
PY

  for density in mdpi hdpi xhdpi xxhdpi xxxhdpi; do
    cp "$SANITIZED_ICON" "android/app/src/main/res/mipmap-$density/ic_launcher.png"
  done
fi

flutter pub get

echo "Flutter native Android/iOS scaffold generated with Face Name branding."
