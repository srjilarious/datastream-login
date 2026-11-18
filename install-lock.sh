#!/bin/sh
# Installs the datastream lock screen for the current user. No sudo needed.
#
# Plasma's lock screen (kscreenlocker_greet) loads lockscreen/LockScreen.qml
# from the Plasma "shell" package named by $PLASMA_DEFAULT_SHELL. This
# installs a shell package that only holds the lock screen (anything else
# falls back to the default shell), and sets PLASMA_DEFAULT_SHELL for KWin
# alone through a systemd drop-in. KWin starts the lock screen, so it picks
# up the variable; plasmashell runs as its own service and keeps the normal
# desktop shell.
#
# The drop-in takes effect at the next login. To try it now without
# locking:   ./install-lock.sh --test
#
#   ./install-lock.sh             install or update
#   ./install-lock.sh --test      install, then open a test lock screen
#   ./install-lock.sh --uninstall remove the package and the drop-in
set -eu
src=$(cd "$(dirname "$0")" && pwd)
id=datastream.lockscreen
pkg=${XDG_DATA_HOME:-$HOME/.local/share}/plasma/shells/$id
dropin_dir=${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/plasma-kwin_wayland.service.d
dropin=$dropin_dir/datastream-lockscreen.conf

if [ "${1:-}" = "--uninstall" ]; then
    rm -rf "$pkg"
    rm -f "$dropin"
    systemctl --user daemon-reload
    echo "removed $pkg and $dropin; the Breeze lock screen returns at the next login"
    exit 0
fi

rm -rf "$pkg"
mkdir -p "$pkg/contents/lockscreen/shared/shaders"
install -m 644 "$src/lockscreen/metadata.json" "$pkg/"
install -m 644 "$src/lockscreen/LockScreen.qml" "$pkg/contents/lockscreen/"
install -m 644 "$src"/shared/*.qml "$pkg/contents/lockscreen/shared/"
install -m 644 "$src"/shared/shaders/*.qsb "$pkg/contents/lockscreen/shared/shaders/"
"$src/tools/conf2js.sh" "$src/theme.conf" > "$pkg/contents/lockscreen/settings.js"
echo "installed $pkg"

mkdir -p "$dropin_dir"
cat > "$dropin" <<EOF
# Installed by datastream/install-lock.sh. Points the screen locker at the
# datastream lock screen. Remove with install-lock.sh --uninstall.
[Service]
Environment=PLASMA_DEFAULT_SHELL=$id
EOF
systemctl --user daemon-reload
echo "installed $dropin (active from the next login)"

if [ "${1:-}" = "--test" ]; then
    echo "test lock screen: type your password to close it"
    PLASMA_DEFAULT_SHELL=$id /usr/lib/kscreenlocker_greet --testing
fi
