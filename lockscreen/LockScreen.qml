// datastream for the Plasma lock screen (kscreenlocker_greet). Same scene
// and terminal as the SDDM theme, with a short boot log, a fixed user and
// kscreenlocker's `authenticator` in place of sddm.login().
//
// kscreenlocker provides these context properties:
//   authenticator          PAM front end: startAuthenticating(), respond(),
//                          succeeded / failed(kind, ...) signals, messages
//   kscreenlocker_userName the locked user's login name
// It also looks for the root properties and signals marked below.
//
// Keys: Enter unlocks, F12 sleeps (when the system can suspend), Escape
// clears the password and lets kscreenlocker blank the screen.
import QtQuick
import org.kde.plasma.private.sessions
import org.kde.plasma.private.keyboardindicator as KeyboardIndicator
import "shared"
import "settings.js" as Settings

Item {
    id: root

    // Root API kscreenlocker_greet expects from a lock screen.
    property bool debug: false
    property string notification
    signal clearPassword()
    signal notificationRepeated()
    property bool viewVisible: false

    implicitWidth: 800
    implicitHeight: 600

    readonly property string userName: typeof kscreenlocker_userName === "string" ? kscreenlocker_userName : ""
    readonly property string hostName: Settings.values.HostName || "localhost"
    readonly property string lockedAt: Qt.formatDateTime(new Date(), "HH:mm:ss")
    // How long ACCESS GRANTED and the warp play before the greeter exits.
    readonly property int unlockDelay: Math.max(0, Number(Settings.values.UnlockDelay) || 1200)

    property bool awake: false
    property bool unlocking: false

    onClearPassword: terminal.clearPassword()

    SessionManagement {
        id: sessionManagement
    }
    Connections {
        target: sessionManagement
        function onAboutToSuspend() {
            terminal.clearPassword()
        }
    }

    KeyboardIndicator.KeyState {
        id: capsLockState
        key: Qt.Key_CapsLock
    }

    // Start PAM on the first key press or click, like Breeze does, rather
    // than while the worker may still be starting up.
    function wake() {
        if (root.unlocking)
            return
        root.awake = true
        authenticator.startAuthenticating()
    }

    Connections {
        target: authenticator
        // kind is non-zero for fingerprint, smartcard and other noninteractive
        // authenticators; only a rejected password counts as a denial.
        function onFailed(kind) {
            if (kind != 0)
                return
            terminal.fail("access denied // attempt " + (terminal.failures + 1) + " logged")
            authenticator.startAuthenticating()
        }
        function onSucceeded() {
            // Stops pending authenticators, preventing timeouts.
            authenticator.stopAuthenticating()
            root.unlocking = true
            terminal.succeed("access granted // welcome back, " + root.userName)
            quitTimer.start()
        }
        function onInfoMessageChanged() {
            if (authenticator.infoMessage)
                terminal.say(authenticator.infoMessage)
        }
        function onErrorMessageChanged() {
            if (authenticator.errorMessage)
                terminal.say(authenticator.errorMessage, terminal.alertColor)
        }
    }

    // Heartbeat that keeps the PAM conversation alive until unlocked, the
    // same thing Breeze's lock screen does while its UI is showing.
    Timer {
        interval: 1000
        repeat: true
        running: root.awake && !root.unlocking && !authenticator.unlocked
        onTriggered: authenticator.startAuthenticating()
    }

    Timer {
        id: quitTimer
        interval: root.unlockDelay
        onTriggered: Qt.quit()
    }

    Scene {
        id: scene
        anchors.fill: parent
        settings: Settings.values
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

            title: "SESSION LOCK // " + root.hostName.toUpperCase()
            bootScript: [
                { msg: "link suspended at " + root.lockedAt, status: "LOCKED", ok: false },
                { msg: "operator " + root.userName + " on node " + root.hostName, status: "AWAY", ok: true },
                { msg: "security clearance", status: "REQUIRED", ok: false }
            ]
            userName: root.userName
            userEditable: false
            footerKeys: sessionManagement.canSuspend ? [{ key: "F12", action: "sleep" }] : []
            capsLock: capsLockState.locked

            onSubmitted: (user, password) => {
                root.wake()
                authenticator.respond(password)
            }
            onKeyCommand: (key) => {
                if (key === "F12" && sessionManagement.canSuspend)
                    sessionManagement.suspend()
            }
            onActivity: root.wake()
            onDenied: scene.deny()
            onGranted: scene.grant()
            onGlitchRequested: (amount) => scene.burst(amount, 250)
        }
    }

    // Any click brings keyboard focus back to the password line.
    MouseArea {
        anchors.fill: parent
        z: -1
        onPressed: (mouse) => {
            Window.window.requestActivate()
            terminal.forceActiveFocus()
            root.wake()
            mouse.accepted = false
        }
    }

    Component.onCompleted: terminal.forceActiveFocus()
}
