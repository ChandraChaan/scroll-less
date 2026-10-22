#!/bin/bash
# Usage: make_screens.sh <raw.png> <out.png> "<title>" "<subtitle>"
# Composes a raw 1080x2400 emulator screenshot into a framed Play Store screenshot.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
RAW="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
OUT="$2"; TITLE="$3"; SUB="$4"
TMP="$(mktemp -d)/frame.html"
sed -e "s|__IMG__|file://$RAW|" -e "s|__TITLE__|$TITLE|" -e "s|__SUB__|$SUB|" "$HERE/frame.html" > "$TMP"
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --disable-gpu --hide-scrollbars --no-sandbox \
  --window-size=1080,2400 --screenshot="$OUT" "file://$TMP" >/dev/null 2>&1
echo "wrote $OUT"
