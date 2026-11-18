#!/usr/bin/env python3
"""Settings window for the datastream login and lock screens.

Shows a live preview and a few options. Apply saves the choices to
~/.config/datastream/settings.conf (the source of truth), then pushes them
to both screens:

  login screen  /usr/share/sddm/themes/datastream/theme.conf.user, written
                through pkexec. SDDM reads it over theme.conf. Other keys
                already in it (System Settings' background) are kept.
  lock screen   settings.js in the datastream.lockscreen shell package,
                regenerated with conf2js.sh from theme.conf plus
                settings.conf. install-lock.sh merges settings.conf too, so
                reinstalling keeps the choices.

Runs from the repo (settings/) or from the copy install-settings.sh makes.
"""
import os
import socket
import subprocess
import sys
from pathlib import Path

from PySide6.QtCore import Property, QObject, QProcess, QUrl, Signal, Slot
from PySide6.QtGui import QGuiApplication, QIcon
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuickControls2 import QQuickStyle

APP_DIR = Path(__file__).resolve().parent

# The options this window manages, with the value used when neither
# theme.conf nor settings.conf sets one.
OPTION_DEFAULTS = {
    "Palette": "neon",
    "NodeName": "",
    "City": "true",
    "Rain": "true",
}
BOOL_OPTIONS = {"City", "Rain"}

CONFIG_HOME = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
DATA_HOME = Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local/share")
USER_CONF = CONFIG_HOME / "datastream" / "settings.conf"
SDDM_THEME_DIR = Path("/usr/share/sddm/themes/datastream")
SDDM_USER_CONF = SDDM_THEME_DIR / "theme.conf.user"
LOCK_DIR = DATA_HOME / "plasma/shells/datastream.lockscreen/contents/lockscreen"


def app_file(installed_name, repo_path):
    """A file next to this script when installed, or in the repo otherwise."""
    installed = APP_DIR / installed_name
    if installed.exists():
        return installed
    return APP_DIR.parent / repo_path


THEME_CONF = app_file("theme.conf", "theme.conf")
CONF2JS = app_file("conf2js.sh", "tools/conf2js.sh")


def read_conf(path):
    """Reads key=value lines from an SDDM-style .conf into a dict, in order.
    Comments, section headers and blank lines are skipped. A missing file
    reads as empty."""
    values = {}
    if not path.exists():
        return values
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line[0] in "#;[" or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip()
    return values


def conf_text(values):
    lines = ["[General]"]
    lines += [f"{key}={value}" for key, value in values.items()]
    return "\n".join(lines) + "\n"


def host_name():
    try:
        return Path("/etc/hostname").read_text().strip()
    except OSError:
        return socket.gethostname()


class Backend(QObject):
    # ok, message: emitted once apply() has finished with both screens.
    applyFinished = Signal(bool, str)

    def __init__(self):
        super().__init__()
        self._sddm_process = None
        self._lock_message = ""

    @Property(str, constant=True)
    def hostName(self):
        return host_name()

    @Property(str, constant=True)
    def userName(self):
        return os.environ.get("USER", "operator")

    @Property(bool, constant=True)
    def sddmInstalled(self):
        return SDDM_THEME_DIR.is_dir()

    @Property(bool, constant=True)
    def lockInstalled(self):
        return LOCK_DIR.is_dir()

    @Slot(result="QVariantMap")
    def load(self):
        """Current choices: defaults, then theme.conf, then settings.conf.
        Booleans come back as real booleans for the checkboxes."""
        values = dict(OPTION_DEFAULTS)
        for source in (read_conf(THEME_CONF), read_conf(USER_CONF)):
            for key in OPTION_DEFAULTS:
                if key in source:
                    values[key] = source[key]
        result = {}
        for key, value in values.items():
            if key in BOOL_OPTIONS:
                result[key] = value.lower() == "true"
            else:
                result[key] = value
        return result

    @Slot("QVariantMap")
    def apply(self, choices):
        values = {}
        for key in OPTION_DEFAULTS:
            value = choices.get(key, OPTION_DEFAULTS[key])
            if key in BOOL_OPTIONS:
                values[key] = "true" if value else "false"
            else:
                # One line per key in the .conf, so no line breaks.
                values[key] = " ".join(str(value).split())

        try:
            USER_CONF.parent.mkdir(parents=True, exist_ok=True)
            USER_CONF.write_text(conf_text(values))
        except OSError as e:
            self.applyFinished.emit(False, f"Could not save {USER_CONF}: {e}")
            return

        self._lock_message = self._apply_lock()
        self._apply_sddm(values)

    def _apply_lock(self):
        if not LOCK_DIR.is_dir():
            return "Lock screen not installed (run install-lock.sh)."
        result = subprocess.run(
            [str(CONF2JS), str(THEME_CONF), str(USER_CONF)],
            capture_output=True, text=True)
        if result.returncode != 0:
            return f"Lock screen not updated: {result.stderr.strip()}"
        (LOCK_DIR / "settings.js").write_text(result.stdout)
        return "Lock screen updated."

    def _apply_sddm(self, values):
        if not SDDM_THEME_DIR.is_dir():
            self._finish(False, "Login screen not installed (run install-sddm.sh).")
            return
        merged = read_conf(SDDM_USER_CONF)
        merged.update(values)

        # pkexec asks for the password through the desktop's polkit agent.
        # Run it asynchronously so the window keeps drawing meanwhile.
        process = QProcess(self)
        process.setStandardOutputFile(QProcess.nullDevice())
        process.finished.connect(self._sddm_finished)
        process.errorOccurred.connect(self._sddm_error)
        self._sddm_process = process
        process.start("pkexec", ["/usr/bin/tee", str(SDDM_USER_CONF)])
        process.write(conf_text(merged).encode())
        process.closeWriteChannel()

    def _sddm_finished(self, exit_code, _status):
        process = self._sddm_process
        self._sddm_process = None
        if exit_code == 0:
            self._finish(True, "Login screen updated.")
        elif exit_code in (126, 127):
            # pkexec: 126 = dialog dismissed, 127 = not authorized.
            self._finish(False, "Login screen not updated: authorization was cancelled or denied.")
        else:
            err = bytes(process.readAllStandardError()).decode(errors="replace").strip()
            self._finish(False, f"Login screen not updated: {err or f'exit code {exit_code}'}")

    def _sddm_error(self, error):
        if error == QProcess.ProcessError.FailedToStart:
            self._sddm_process = None
            self._finish(False, "Login screen not updated: could not run pkexec.")

    def _finish(self, sddm_ok, sddm_message):
        lock_ok = self._lock_message == "Lock screen updated."
        self.applyFinished.emit(sddm_ok and lock_ok, f"{sddm_message} {self._lock_message}")


def main():
    if not os.environ.get("QT_QUICK_CONTROLS_STYLE"):
        QQuickStyle.setStyle("org.kde.desktop")
    app = QGuiApplication(sys.argv)
    app.setApplicationName("datastream-settings")
    app.setApplicationDisplayName("datastream settings")
    app.setDesktopFileName("datastream-settings")
    app.setWindowIcon(QIcon.fromTheme("preferences-desktop-theme"))

    backend = Backend()
    engine = QQmlApplicationEngine()
    engine.rootContext().setContextProperty("backend", backend)
    engine.load(QUrl.fromLocalFile(str(APP_DIR / "Settings.qml")))
    if not engine.rootObjects():
        return 1
    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
