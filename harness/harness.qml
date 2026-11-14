// Stand-ins for SDDM's context objects so the theme can be screenshotted
// with the plain `qml` runtime. Password "hack" succeeds, anything else fails.
import QtQuick

Window {
    id: win
    width: 1600
    height: 900
    visible: true
    color: "black"

    property string outDir: ""
    property var shots: []

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
    QtObject { id: config }
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
        source: Qt.resolvedUrl(Qt.application.arguments[Qt.application.arguments.length - 2] + "/Main.qml")
        onLoaded: { item.width = Qt.binding(() => win.width); item.height = Qt.binding(() => win.height) }
    }

    function shot(name) {
        loader.grabToImage(r => r.saveToFile(Qt.application.arguments[Qt.application.arguments.length - 1] + "/" + name + ".png"))
    }

    // Script: boot log, idle with prompt, a failed login, then a skyline view.
    Timer { interval: 1200; running: true; onTriggered: win.shot("1-boot") }
    Timer { interval: 4500; running: true; onTriggered: win.shot("2-prompt") }
    Timer { interval: 5000; running: true; onTriggered: sddm.login("jeffdw", "nope", 0) }
    Timer { interval: 5900; running: true; onTriggered: win.shot("3-denied") }
    Timer { interval: 6300; running: true; onTriggered: win.shot("4-denied-later") }
    Timer { interval: 6600; running: true; onTriggered: sddm.login("jeffdw", "hack", 0) }
    Timer { interval: 7500; running: true; onTriggered: win.shot("5-granted") }
    Timer { interval: 8800; running: true; onTriggered: { loader.item.climb = 1; loader.item.speed = 0.9 } }
    Timer { interval: 9500; running: true; onTriggered: win.shot("6-skyline") }
    Timer { interval: 10500; running: true; onTriggered: Qt.quit() }
}
