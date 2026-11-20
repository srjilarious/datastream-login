#!/bin/sh
# Copies a theme into SDDM's theme directory. Does not change which theme
# is active; pick it in System Settings > Login Screen (SDDM), or set
# [Theme] Current=<theme> in /etc/sddm.conf.d/kde_settings.conf.
#
#   ./install-sddm.sh              install datastream
#   ./install-sddm.sh acidburn     install acidburn
set -eu
src=$(cd "$(dirname "$0")" && pwd)
theme=${1:-datastream}
case "$theme" in
    datastream) root=$src ;;
    acidburn) root=$src/acidburn ;;
    *) echo "usage: install-sddm.sh [datastream|acidburn]" >&2; exit 2 ;;
esac
dest=/usr/share/sddm/themes/$theme
# Clear out the old files but keep theme.conf.user, where System Settings
# saves overrides.
if [ -d "$dest" ]; then
    sudo find "$dest" -mindepth 1 -maxdepth 1 ! -name theme.conf.user -exec rm -rf {} +
fi
sudo mkdir -p "$dest/shared/shaders"
sudo install -m 644 "$root"/sddm/Main.qml "$root"/sddm/metadata.desktop \
    "$root"/sddm/preview.png "$root"/theme.conf "$dest/"
# install follows symlinks, so files a set borrows from the top-level
# shared/ are copied in as plain files.
sudo install -m 644 "$root"/shared/*.qml "$root"/shared/*.js "$dest/shared/"
sudo install -m 644 "$root"/shared/shaders/*.qsb "$dest/shared/shaders/"
echo "installed to $dest"
echo "preview without logging out: sddm-greeter-qt6 --test-mode --theme $dest"
