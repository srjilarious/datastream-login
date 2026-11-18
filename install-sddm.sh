#!/bin/sh
# Copies the theme into SDDM's theme directory. Does not change which theme
# is active; pick it in System Settings > Login Screen (SDDM), or set
# [Theme] Current=datastream in /etc/sddm.conf.d/kde_settings.conf.
set -eu
src=$(cd "$(dirname "$0")" && pwd)
dest=/usr/share/sddm/themes/datastream
# Clear out the old files but keep theme.conf.user, where System Settings
# saves overrides.
if [ -d "$dest" ]; then
    sudo find "$dest" -mindepth 1 -maxdepth 1 ! -name theme.conf.user -exec rm -rf {} +
fi
sudo mkdir -p "$dest/shared/shaders"
sudo install -m 644 "$src"/sddm/Main.qml "$src"/sddm/metadata.desktop \
    "$src"/sddm/preview.png "$src"/theme.conf "$dest/"
sudo install -m 644 "$src"/shared/*.qml "$src"/shared/*.js "$dest/shared/"
sudo install -m 644 "$src"/shared/shaders/*.qsb "$dest/shared/shaders/"
echo "installed to $dest"
echo "preview without logging out: sddm-greeter-qt6 --test-mode --theme $dest"
