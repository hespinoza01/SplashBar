#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP="SplashBar.app"
CONTENTS="$APP/Contents"

rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS"
cp .build/release/SplashBar "$CONTENTS/MacOS/SplashBar"
cp Info.plist "$CONTENTS/Info.plist"

codesign --force --deep --sign - "$APP"

echo "Listo: $(pwd)/$APP"

if [ "${1:-}" = "--install" ]; then
    pkill -f "/Applications/SplashBar.app/Contents/MacOS/SplashBar" 2>/dev/null || true
    rm -rf "/Applications/$APP"
    cp -R "$APP" "/Applications/$APP"
    echo "Instalado en /Applications/$APP"
fi
