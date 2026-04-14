#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-release}"

case "$MODE" in
  release|profile|debug)
    ;;
  *)
    echo "Usage: $0 [release|profile|debug]"
    exit 1
    ;;
esac

if ! command -v flutter >/dev/null 2>&1; then
  echo "Error: flutter command not found in PATH"
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCHIVE_DIR="$ROOT_DIR/build/ios/archive/Runner.xcarchive"
APP_DIR="$ARCHIVE_DIR/Products/Applications"
OUT_DIR="$ROOT_DIR/build/ios/ipa"
OUT_IPA="$OUT_DIR/Runner-${MODE}-unsigned.ipa"
TMP_DIR="$ROOT_DIR/build/ios/ipa_tmp_${MODE}"

cd "$ROOT_DIR"

echo "==> Patching device_info_plus iOS selector compatibility..."
FOUND_PLUGIN=0
while IFS= read -r PLUGIN_FILE; do
  FOUND_PLUGIN=1
  perl -0777 -i -pe 's/isiOSAppOnVision/isMacCatalystApp/g' "$PLUGIN_FILE"
  echo "Patched: $PLUGIN_FILE"
done < <(find "$HOME/.pub-cache/hosted/pub.dev" "$ROOT_DIR/ios/.symlinks/plugins" -type f -name "FPPDeviceInfoPlusPlugin.m" 2>/dev/null)

if [ "$FOUND_PLUGIN" -eq 0 ]; then
  echo "Warning: FPPDeviceInfoPlusPlugin.m not found in pub cache or iOS symlinks."
fi

if grep -RE "processInfo[^[:alnum:]_]*\][[:space:]]*isiOSAppOnVision" "$HOME/.pub-cache/hosted/pub.dev" "$ROOT_DIR/ios/.symlinks/plugins" 2>/dev/null; then
  echo "Error: device_info_plus selector patch verification failed."
  exit 1
fi

echo "==> Building iOS archive (${MODE}, no codesign)..."
flutter build ipa "--${MODE}" --no-codesign --no-pub

if [ ! -d "$APP_DIR" ]; then
  echo "Error: archive app directory not found: $APP_DIR"
  exit 1
fi

APP_PATH="$(find "$APP_DIR" -maxdepth 1 -type d -name '*.app' | head -n 1)"
if [ -z "$APP_PATH" ]; then
  echo "Error: no .app found under: $APP_DIR"
  exit 1
fi

APP_NAME="$(basename "$APP_PATH")"

mkdir -p "$OUT_DIR"
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR/Payload"
cp -R "$APP_PATH" "$TMP_DIR/Payload/$APP_NAME"

(
  cd "$TMP_DIR"
  zip -qry "$OUT_IPA" Payload
)

rm -rf "$TMP_DIR"

echo "==> Done"
echo "IPA: $OUT_IPA"
ls -lh "$OUT_IPA"
