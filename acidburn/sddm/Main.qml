// acidburn for SDDM: the shared scene and prompt, wired to the `sddm`,
// `userModel`, `sessionModel`, `keyboard` and `config` context objects the
// greeter provides.
//
// Keys: F10 cycles sessions, F11 reboots, F12 powers off, Up/Down on the
// handle cycle users. Any key during the intro skips to the prompt.
import QtQuick
import "shared"

Rectangle {
    id: root

    width: Screen.width
    height: Screen.height
    color: "black"

    // Exposed for the harness.
    readonly property alias scene: scene

    // Name shown above the handle: NodeName from theme.conf, or the host
    // name when it is not set.
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
            if (users.itemAt(k).userName === prompt.currentUser)
                i = k
        i = (i + step + users.count) % users.count
        prompt.setUser(users.itemAt(i).userName)
    }

    function footerKeys() {
        const keys = []
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

        Prompt {
            id: prompt
            anchors.horizontalCenter: parent.horizontalCenter
            y: scene.promptY
            shown: scene.promptShown
            fontFamily: scene.fontFamily
            fontPx: scene.fontPx
            accent: scene.accent
            textColor: scene.textColor
            okColor: scene.okColor
            alertColor: scene.alertColor
            focus: true

            caption: "node // " + root.nodeName
            userName: userModel.lastUser
            sessionLabel: root.sessionName(root.sessionIndex)
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
            onActivity: scene.skipIntro()
            onTyped: scene.heatUp()
            onDenied: scene.deny()
            onGranted: scene.grant()
        }
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            prompt.fail("access denied // attempt " + (prompt.failures + 1) + " logged")
        }
        function onLoginSucceeded() {
            prompt.succeed("access granted // welcome, " + prompt.currentUser)
        }
        function onInformationMessage(message) {
            prompt.say(message)
        }
    }

    Component.onCompleted: prompt.forceActiveFocus()
}
