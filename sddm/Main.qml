// datastream for SDDM: the shared scene and terminal, wired to the `sddm`,
// `userModel`, `sessionModel`, `keyboard` and `config` context objects the
// greeter provides.
//
// Keys: F10 cycles sessions, F11 reboots, F12 powers off, Up/Down on the
// login line cycle users.
import QtQuick
import "shared"

Rectangle {
    id: root

    width: Screen.width
    height: Screen.height
    color: "black"

    // Exposed for harness/sddm.qml.
    readonly property alias scene: scene

    // Name shown in the header and boot log: NodeName from theme.conf, or
    // the host name when it is not set.
    readonly property string nodeName: scene.cfg("NodeName", sddm.hostName)

    property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0

    // Collect user and session names; the models only expose them through
    // roles, so a hidden Repeater is the plain way to read them by index.
    Repeater {
        id: users
        model: userModel
        delegate: Item { property string userName: model.name }
    }
    Repeater {
        id: sessions
        model: sessionModel
        delegate: Item { property string sessionName: model.name }
    }
    // Reading sessions.count makes bindings that call this re-run once the
    // Repeater has filled in; itemAt() alone would not notify.
    function sessionName(i) {
        if (i < 0 || i >= sessions.count)
            return "default"
        return sessions.itemAt(i).sessionName
    }

    function cycleUser(step) {
        if (users.count === 0)
            return
        let i = 0
        for (let k = 0; k < users.count; k++)
            if (users.itemAt(k).userName === terminal.currentUser)
                i = k
        i = (i + step + users.count) % users.count
        terminal.setUser(users.itemAt(i).userName)
    }

    function footerKeys() {
        const keys = [{ key: "F10", action: "session" }]
        if (sddm.canReboot)
            keys.push({ key: "F11", action: "reboot" })
        if (sddm.canPowerOff)
            keys.push({ key: "F12", action: "power off" })
        return keys
    }

    Scene {
        id: scene
        anchors.fill: parent
        settings: config
        bannerAnchor: terminal

        Terminal {
            id: terminal
            anchors.centerIn: parent
            fontFamily: scene.fontFamily
            fontPx: scene.fontPx
            accent: scene.accent
            textColor: scene.textColor
            okColor: scene.okColor
            alertColor: scene.alertColor
            focus: true

            title: "MAINFRAME ACCESS NODE // " + root.nodeName.toUpperCase()
            bootScript: [
                { msg: "carrier detected on line 0x" + hex(4), status: "OK", ok: true },
                { msg: "handshake " + hex(4) + ":" + hex(4) + ":" + hex(4), status: "OK", ok: true },
                { msg: "routing through 7 relays", status: "OK", ok: true },
                { msg: "mounting /dev/mainframe", status: "OK", ok: true },
                { msg: "integrity of node " + root.nodeName, status: "VERIFIED", ok: true },
                { msg: "security clearance", status: "REQUIRED", ok: false }
            ]
            userName: userModel.lastUser
            sessionLabel: root.sessionName(root.sessionIndex) + "  <F10>"
            footerKeys: root.footerKeys()
            capsLock: keyboard.capsLock

            onSubmitted: (user, password) => sddm.login(user, password, root.sessionIndex)
            onUserCycleRequested: (step) => root.cycleUser(step)
            onKeyCommand: (key) => {
                if (key === "F10" && sessions.count > 0)
                    root.sessionIndex = (root.sessionIndex + 1) % sessions.count
                else if (key === "F11" && sddm.canReboot)
                    sddm.reboot()
                else if (key === "F12" && sddm.canPowerOff)
                    sddm.powerOff()
            }
            onDenied: scene.deny()
            onGranted: scene.grant()
            onGlitchRequested: (amount) => scene.burst(amount, 250)
        }
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            terminal.fail("access denied // attempt " + (terminal.failures + 1) + " logged")
        }
        function onLoginSucceeded() {
            terminal.succeed("access granted // welcome, " + terminal.currentUser)
        }
        function onInformationMessage(message) {
            terminal.say(message)
        }
    }

    Component.onCompleted: terminal.forceActiveFocus()
}
