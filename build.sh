#!/usr/bin/env bash
#
# Builds PRStatusBar.app with plain swiftc (no SwiftPM: its manifest linking is
# broken on the macOS 27 Command Line Tools).
#
#   ./build.sh          build PRStatusBar.app
#   ./build.sh test     build and run the checks in Tests/
#   ./build.sh install  build, copy to ~/Applications and launch

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

APP=PRStatusBar
OUT=.build/out
FLAGS=(-O -parse-as-library -target "$(uname -m)-apple-macosx13.0")
mkdir -p "$OUT"

swiftc "${FLAGS[@]}" -module-name PRStatusCore \
    -emit-module -emit-module-path "$OUT/PRStatusCore.swiftmodule" \
    -emit-library -static -o "$OUT/libPRStatusCore.a" \
    Sources/PRStatusCore/*.swift

if [[ "${1:-}" == "test" ]]; then
    swiftc -target "$(uname -m)-apple-macosx13.0" -I "$OUT" -L "$OUT" -lPRStatusCore Tests/*.swift -o "$OUT/tests"
    exec "$OUT/tests"
fi

swiftc "${FLAGS[@]}" -I "$OUT" -L "$OUT" -lPRStatusCore Sources/PRStatusBar/*.swift -o "$OUT/$APP"

rm -rf "$APP.app"
mkdir -p "$APP.app/Contents/MacOS"
cp "$OUT/$APP" "$APP.app/Contents/MacOS/$APP"
cp Info.plist "$APP.app/Contents/Info.plist"
codesign --force --sign - "$APP.app"
echo "✅ Built $APP.app"

if [[ "${1:-}" == "install" ]]; then
    pkill -x "$APP" || true
    mkdir -p ~/Applications
    rm -rf ~/Applications/"$APP.app"
    cp -R "$APP.app" ~/Applications/
    open ~/Applications/"$APP.app"
    echo "✅ Installed to ~/Applications and launched"
fi
