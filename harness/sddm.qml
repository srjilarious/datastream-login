// Stand-ins for SDDM's context objects so the theme can be screenshotted
// with the plain `qml` runtime. Password "hack" succeeds, anything else fails.
// An optional third argument picks the palette (default neon).
//
//   QT_FORCE_STDERR_LOGGING=1 qml6 harness/sddm.qml -- "$PWD/sddm" <shot dir> [palette]
import QtQuick

Window {
    id: win
    width: 1600
    height: 900
    visible: true
    color: "black"

    // Arguments after "--": theme dir, shot dir, optional palette.
    readonly property var args: {
        const a = Qt.application.arguments
        return a.slice(a.indexOf("--") + 1)
    }

    QtObject {
        id: sddm
        property string hostName: "zero-cool"
        property bool canReboot: true
        property bool canPowerOff: true
        signal loginFailed()
        signal loginSucceeded()
        signal informationMessage(string message)
        function login(u, p, s) { p === "hack" ? okTimer.start() : failTimer.start() }
        function reboot() { console.log("reboot") }
        function powerOff() { console.log("powerOff") }
    }
    Timer { id: failTimer; interval: 700; onTriggered: sddm.loginFailed() }
    Timer { id: okTimer; interval: 700; onTriggered: sddm.loginSucceeded() }
    // Stands in for SDDM's config map; Main.qml reads it as `config`.
    property var config: ({ Palette: win.args.length > 2 ? win.args[2] : "neon" })
    QtObject { id: keyboard; property bool capsLock: false }
    ListModel {
        id: userModel
        property string lastUser: "jeffdw"
        property int lastIndex: 0
        ListElement { name: "jeffdw"; realName: "Jeff" }
        ListElement { name: "guest"; realName: "Guest" }
    }
    ListModel {
        id: sessionModel
        property int lastIndex: 0
        ListElement { name: "Plasma (Wayland)" }
        ListElement { name: "Plasma (X11)" }
    }

    Loader {
        id: loader
        anchors.fill: parent
        source: Qt.resolvedUrl(win.args[0] + "/Main.qml")
        onLoaded: { item.width = Qt.binding(() => win.width); item.height = Qt.binding(() => win.height) }
    }

    function shot(name) {
        loader.grabToImage(r => r.saveToFile(win.args[1] + "/" + name + ".png"))
    }

    // Script: boot log, idle with prompt, a failed login, then a skyline view.
    Timer { interval: 1200; running: true; onTriggered: win.shot("1-boot") }
    Timer { interval: 4500; running: true; onTriggered: win.shot("2-prompt") }
    Timer { interval: 5000; running: true; onTriggered: sddm.login("jeffdw", "nope", 0) }
    Timer { interval: 5900; running: true; onTriggered: win.shot("3-denied") }
    Timer { interval: 6300; running: true; onTriggered: win.shot("4-denied-later") }
    Timer { interval: 6600; running: true; onTriggered: sddm.login("jeffdw", "hack", 0) }
    Timer { interval: 7500; running: true; onTriggered: win.shot("5-granted") }
    Timer { interval: 8800; running: true; onTriggered: { loader.item.scene.climb = 1; loader.item.scene.speed = 0.9 } }
    Timer { interval: 9500; running: true; onTriggered: win.shot("6-skyline") }
    Timer { interval: 10500; running: true; onTriggered: Qt.quit() }
}
