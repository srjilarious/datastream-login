# datastream

A login theme for SDDM (Qt 6) and a matching Plasma 6 lock screen. The
camera flies down an avenue of neon towers covered in streaming hex, green
hex rain falls over the top, and a retro terminal types out a boot log
before asking for your password. A wrong password tears the screen apart
with a glitch burst and a flickering ACCESS DENIED; the right one flashes
ACCESS GRANTED and the camera warps forward. Every so often the camera
rises above the rooftops for a skyline pass.

The lock screen uses the same scene and terminal with a shorter boot log
and the user fixed to the one who is locked out.

![preview](sddm/preview.png)

## Install

### Login screen (SDDM)

    ./install-sddm.sh
    sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/datastream

Then select it in System Settings > Login Screen (SDDM).

### Lock screen

    ./install-lock.sh          # install or update
    ./install-lock.sh --test   # install, then open a test lock screen
    ./install-lock.sh --uninstall

No sudo needed. Plasma's locker (`kscreenlocker_greet`) loads
`lockscreen/LockScreen.qml` from the Plasma shell package named by
`$PLASMA_DEFAULT_SHELL`. The script installs a shell package,
`~/.local/share/plasma/shells/datastream.lockscreen`, that holds only the
lock screen, and sets `PLASMA_DEFAULT_SHELL` for KWin alone through a
systemd drop-in
(`~/.config/systemd/user/plasma-kwin_wayland.service.d/datastream-lockscreen.conf`).
KWin starts the locker, so the locker sees it; plasmashell is a separate
service and keeps the normal desktop shell. The drop-in takes effect at the
next login. If the QML ever fails to load, kscreenlocker falls back to its
built-in lock screen, so a broken theme cannot leave you unable to unlock.

The lock screen package needs `"X-Plasma-APIVersion": "2"` in its metadata,
or kscreenlocker logs "Lockscreen QML outdated" and uses Breeze.

### Settings window

    ./install-settings.sh              # install or update
    ./install-settings.sh --uninstall

Adds "datastream settings" to the application launcher: a live preview with
the palette, the node name in the terminal header, and switches for the
flying city and the hex rain. Apply saves the choices to
`~/.config/datastream/settings.conf` and pushes them to both screens:
the login screen's `theme.conf.user` (through pkexec, so it asks for your
password) and the lock screen's `settings.js`. `install-lock.sh` merges
`settings.conf` too, so reinstalling keeps them. Plasma's own Login Screen
settings page can only change a theme's background, which is why this is a
separate window.

## Keys

| Key | Login screen | Lock screen |
| --- | --- | --- |
| Enter | next line / log in | unlock |
| Tab, Shift+Tab | switch between login and password | |
| Up / Down (login line) | cycle users | |
| F10 | cycle sessions | |
| F11 | reboot | |
| F12 | power off | sleep |
| Escape | clear password | clear password (and the locker blanks the screen) |
| any key during boot log | skip to the prompt | skip to the prompt; typed characters go into the password |

## Palettes

`Palette=` in `theme.conf` picks the colors:

- `neon` (default): cyan, magenta and amber towers under green hex rain.
- `phosphor`: an old green monochrome monitor. The CRT pass maps the whole
  image onto one green by brightness, so everything is a shade of green;
  ACCESS DENIED shows in the hottest near-white green instead of red.

Palettes are defined in `shared/palettes.js`; add one there and select it
by name. Any color key set in `theme.conf` (they are listed there,
commented out) overrides the palette's value for that key.

## Tuning

The settings window covers the common options. Everything else lives in
`theme.conf`: palette, node name, city and rain switches, colors, flight speed, the rooftop climb,
rain density and opacity, scanline strength and idle glitches.
`RenderScale` sets the resolution the city is raycast at (0.75 of the
screen by default); drop it to 0.5 on a weak GPU or a 4K panel.

SDDM reads `theme.conf` directly, with `theme.conf.user` on top. The lock
screen has no config object, so `install-lock.sh` converts `theme.conf` plus
`~/.config/datastream/settings.conf` to `settings.js` with
`tools/conf2js.sh` (adding the host name); rerun the installer after
editing `theme.conf`.
The lock screen also takes `UnlockDelay`, the milliseconds ACCESS GRANTED
plays before the desktop comes back (default 1200).

## Layout

- `shared/Scene.qml`: city, rain, CRT pass, glitch/flash drivers, banner, warp.
- `shared/Terminal.qml`: boot log, prompts, status line and key handling.
  Talks to its owner through signals, so it has no SDDM or PAM code.
- `shared/Banner.qml`: the big ACCESS GRANTED / DENIED word.
- `shared/palettes.js`: the color palettes `Palette=` chooses from.
- `settings/`: the settings window (PySide6 backend, Kirigami QML front end
  that reuses `shared/Scene.qml` for the preview).
- `shared/shaders/city.frag`: the city, a 2D grid raycast with one box per cell.
- `shared/shaders/rain.frag`: screen-space hex rain.
- `shared/shaders/post.frag`: chromatic split, glitch bands, scanlines, vignette,
  and the monochrome phosphor mapping.
- `sddm/Main.qml`: wires the terminal to SDDM's `sddm`, `userModel` and
  `sessionModel`.
- `lockscreen/LockScreen.qml`: wires the terminal to kscreenlocker's
  `authenticator`.
- `sddm/shared` and `lockscreen/shared` are symlinks to `shared/` so each
  entry point can `import "shared"` from the repo the same way it does
  once installed.

The glyphs are a hand-made 3x5 hex font packed into floats
(`tools/font.py`), shared by the city and rain shaders. After editing a
`.frag`, run `./build-shaders.sh`.

## Testing without installing

`harness/` has mock context objects so both screens can be screenshotted
with the plain `qml` runtime (password "hack" succeeds):

    tools/conf2js.sh theme.conf > lockscreen/settings.js
    QT_FORCE_STDERR_LOGGING=1 qml6 harness/lock.qml -- "$PWD/lockscreen" /tmp/shots
    QT_FORCE_STDERR_LOGGING=1 qml6 harness/sddm.qml -- "$PWD/sddm" /tmp/shots

Under a systemd session Qt logs to the journal, so without
`QT_FORCE_STDERR_LOGGING=1` QML errors are silent.
