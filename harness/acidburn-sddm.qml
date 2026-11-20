// Stand-ins for SDDM's context objects so the acidburn theme can be
// screenshotted with the plain `qml` runtime. Password "hack" succeeds,
// anything else fails. An optional third argument picks the palette
// (default film).
//
//   QT_FORCE_STDERR_LOGGING=1 qml6 harness/acidburn-sddm.qml -- "$PWD/acidburn/sddm" <shot dir> [palette]
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
        property string hostName: "gibson"
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
    property var config: ({ Palette: win.args.length > 2 ? win.args[2] : "film" })
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
    function at(ms, fn) {
        const t = Qt.createQmlObject("import QtQuick; Timer { running: true }", win)
        t.interval = ms
        t.triggered.connect(fn)
    }

    // Script: the intro phase by phase, the prompt, typing, a failed login,
    // the pointer whirlpool, then a good login.
    Component.onCompleted: {
        at(900, () => shot("01-draw-in"))
        at(1500, () => shot("02-border"))
        at(2300, () => shot("03-burn"))
        at(3000, () => shot("04-white"))
        at(4100, () => shot("05-cool"))
        at(5000, () => shot("06-flame"))
        at(5900, () => shot("07-dissolve"))
        at(6500, () => shot("08-settle"))
        at(8000, () => shot("09-prompt"))
        at(8200, () => { loader.item.scene.heat = 1 })
        at(8300, () => shot("10-heat"))
        at(9000, () => sddm.login("jeffdw", "nope", 0))
        at(9850, () => shot("11-denied"))
        at(10300, () => shot("12-denied-later"))
        at(11500, () => { const s = loader.item.scene; s.pointerTarget = Qt.point(0.25, 0.7); s.pointer = Qt.point(0.25, 0.7); s.swirl = 1 })
        at(11900, () => shot("13-swirl"))
        at(12300, () => sddm.login("jeffdw", "hack", 0))
        at(13400, () => shot("14-granted"))
        at(14200, () => shot("15-outro"))
        at(14800, () => Qt.quit())
    }
}
