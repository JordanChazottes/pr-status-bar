#!/usr/bin/env bash
#
# Installs the Linux tray app for the current user and starts it.
#
#   ./install.sh            install, enable autostart and launch
#   ./install.sh uninstall  remove everything install put down

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

APP=pr-status-bar
SHARE=~/.local/share/$APP
BIN=~/.local/bin/$APP
DESKTOP=~/.local/share/applications/$APP.desktop
AUTOSTART=~/.config/autostart/$APP.desktop

pkill -f "$SHARE/$APP" || true

if [[ "${1:-}" == "uninstall" ]]; then
    rm -rf "$SHARE" "$BIN" "$DESKTOP" "$AUTOSTART"
    echo "✅ Uninstalled"
    exit 0
fi

if ! python3 -c 'import gi; gi.require_version("Gtk", "3.0")' 2>/dev/null \
    || ! { python3 -c 'import gi; gi.require_version("AyatanaAppIndicator3", "0.1")' 2>/dev/null \
        || python3 -c 'import gi; gi.require_version("AppIndicator3", "0.1")' 2>/dev/null; }; then
    cat >&2 <<'EOF'
Missing GTK / AppIndicator bindings. Install them with:
  Debian/Ubuntu: sudo apt install python3-gi gir1.2-ayatanaappindicator3-0.1
  Fedora:        sudo dnf install python3-gobject libayatana-appindicator-gtk3
  Arch:          sudo pacman -S python-gobject libayatana-appindicator
EOF
    exit 1
fi
command -v gh >/dev/null || echo "⚠️  gh CLI not on PATH: install it and run gh auth login" >&2

mkdir -p "$SHARE" "$(dirname "$BIN")" "$(dirname "$DESKTOP")" "$(dirname "$AUTOSTART")"
cp "$APP" pr_status_core.py "$SHARE/"
chmod +x "$SHARE/$APP"
ln -sf "$SHARE/$APP" "$BIN"
sed "s|@EXEC@|$SHARE/$APP|" "$APP.desktop" > "$DESKTOP"
cp "$DESKTOP" "$AUTOSTART"

nohup "$SHARE/$APP" >/dev/null 2>&1 &
echo "✅ Installed to $SHARE, starts on login, running now"
