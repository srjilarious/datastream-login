#!/bin/sh
# Copies the theme into SDDM's theme directory. Does not change which theme
# is active; pick it in System Settings > Login Screen (SDDM), or set
# [Theme] Current=datastream in /etc/sddm.conf.d/kde_settings.conf.
set -eu
src=$(cd "$(dirname "$0")" && pwd)
dest=/usr/share/sddm/themes/datastream
sudo mkdir -p "$dest/shaders"
sudo install -m 644 "$src"/Main.qml "$src"/Terminal.qml "$src"/Banner.qml \
    "$src"/metadata.desktop "$src"/theme.conf "$src"/preview.png "$dest/"
sudo install -m 644 "$src"/shaders/*.qsb "$dest/shaders/"
echo "installed to $dest"
echo "preview without logging out: sddm-greeter-qt6 --test-mode --theme $dest"
