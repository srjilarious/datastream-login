#!/bin/sh
# Installs the datastream settings window for the current user. No sudo
# needed; the window asks for your password (pkexec) when it applies
# changes to the login screen.
#
# Copies the app to ~/.local/share/datastream-settings and adds
# "datastream settings" to the application launcher.
#
#   ./install-settings.sh             install or update
#   ./install-settings.sh --uninstall remove the app and its launcher entry
#                                     (keeps ~/.config/datastream)
set -eu
src=$(cd "$(dirname "$0")" && pwd)
data=${XDG_DATA_HOME:-$HOME/.local/share}
dest=$data/datastream-settings
desktop=$data/applications/datastream-settings.desktop

refresh_menu() {
    if command -v kbuildsycoca6 >/dev/null 2>&1; then
        kbuildsycoca6 >/dev/null 2>&1 || true
    fi
}

if [ "${1:-}" = "--uninstall" ]; then
    rm -rf "$dest"
    rm -f "$desktop"
    refresh_menu
    echo "removed $dest and $desktop"
    exit 0
fi

rm -rf "$dest"
mkdir -p "$dest/shared/shaders" "$data/applications"
install -m 755 "$src/settings/datastream-settings.py" "$dest/"
install -m 644 "$src/settings/Settings.qml" "$src/theme.conf" "$dest/"
install -m 755 "$src/tools/conf2js.sh" "$dest/"
install -m 644 "$src"/shared/*.qml "$src"/shared/*.js "$dest/shared/"
install -m 644 "$src"/shared/shaders/*.qsb "$dest/shared/shaders/"
echo "installed $dest"

cat > "$desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=datastream settings
Comment=Palette, node name and effects for the datastream login and lock screens
Exec=python3 "$dest/datastream-settings.py"
Icon=preferences-desktop-theme
Categories=Settings;DesktopSettings;
DESKTOP
refresh_menu
echo "installed $desktop"
