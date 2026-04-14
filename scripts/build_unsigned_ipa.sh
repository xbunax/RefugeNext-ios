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
