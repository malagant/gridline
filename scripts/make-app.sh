#!/usr/bin/env bash
# Baut Gridline im Release-Modus und verpackt es als Gridline.app (ad-hoc signiert).
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release --product Gridline
BIN_DIR="$(swift build -c release --show-bin-path)"

APP="build/Gridline.app"
rm -rf "$APP" build/Gridline.zip
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Gridline" "$APP/Contents/MacOS/Gridline"
cp Packaging/Info.plist "$APP/Contents/Info.plist"

codesign --force --sign - "$APP"
(cd build && ditto -c -k --keepParent Gridline.app Gridline.zip)
echo "Fertig: $APP und build/Gridline.zip"
