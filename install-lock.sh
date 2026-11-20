#!/bin/sh
# Installs a lock screen (datastream or acidburn) for the current user. No
# sudo needed.
#
# Plasma's lock screen (kscreenlocker_greet) loads lockscreen/LockScreen.qml
# from the Plasma "shell" package named by $PLASMA_DEFAULT_SHELL. This
# installs a shell package that only holds the lock screen (anything else
# falls back to the default shell), and sets PLASMA_DEFAULT_SHELL for KWin
# alone through a systemd drop-in. KWin starts the lock screen, so it picks
# up the variable; plasmashell runs as its own service and keeps the normal
# desktop shell. There is one drop-in, so the last set installed is the
# one in use.
#
# The drop-in takes effect at the next login. To try it now without
# locking:   ./install-lock.sh [theme] --test
#
#   ./install-lock.sh [datastream|acidburn]              install or update
#   ./install-lock.sh [datastream|acidburn] --test       install, then open a test lock screen
#   ./install-lock.sh [datastream|acidburn] --uninstall  remove the package, and the
#                                                        drop-in if it points at it
# The theme defaults to datastream.
set -eu
src=$(cd "$(dirname "$0")" && pwd)

usage() {
    echo "usage: install-lock.sh [datastream|acidburn] [--test|--uninstall]" >&2
    exit 2
}

theme=datastream
action=install
for arg in "$@"; do
    case "$arg" in
        datastream|acidburn) theme=$arg ;;
        --test) action=test ;;
        --uninstall) action=uninstall ;;
        *) usage ;;
    esac
done
case "$theme" in
    datastream) root=$src ;;
    acidburn) root=$src/acidburn ;;
esac

id=$theme.lockscreen
pkg=${XDG_DATA_HOME:-$HOME/.local/share}/plasma/shells/$id
config_home=${XDG_CONFIG_HOME:-$HOME/.config}
dropin_dir=$config_home/systemd/user/plasma-kwin_wayland.service.d
dropin=$dropin_dir/datastream-lockscreen.conf

if [ "$action" = "uninstall" ]; then
    rm -rf "$pkg"
    echo "removed $pkg"
    if [ -f "$dropin" ] && grep -q "^Environment=PLASMA_DEFAULT_SHELL=$id\$" "$dropin"; then
        rm -f "$dropin"
        systemctl --user daemon-reload
        echo "removed $dropin; the Breeze lock screen returns at the next login"
    fi
    exit 0
fi

rm -rf "$pkg"
mkdir -p "$pkg/contents/lockscreen/shared/shaders"
install -m 644 "$root/lockscreen/metadata.json" "$pkg/"
install -m 644 "$root/lockscreen/LockScreen.qml" "$pkg/contents/lockscreen/"
# install follows symlinks, so files a set borrows from the top-level
# shared/ are copied in as plain files.
install -m 644 "$root"/shared/*.qml "$root"/shared/*.js "$pkg/contents/lockscreen/shared/"
install -m 644 "$root"/shared/shaders/*.qsb "$pkg/contents/lockscreen/shared/shaders/"
"$src/tools/conf2js.sh" "$root/theme.conf" "$config_home/$theme/settings.conf" > "$pkg/contents/lockscreen/settings.js"
echo "installed $pkg"

mkdir -p "$dropin_dir"
cat > "$dropin" <<EOF
# Installed by datastream/install-lock.sh. Points the screen locker at the
# $theme lock screen. Remove with install-lock.sh $theme --uninstall.
[Service]
Environment=PLASMA_DEFAULT_SHELL=$id
EOF
systemctl --user daemon-reload
echo "installed $dropin (active from the next login)"

if [ "$action" = "test" ]; then
    echo "test lock screen: type your password to close it"
    PLASMA_DEFAULT_SHELL=$id /usr/lib/kscreenlocker_greet --testing
fi
