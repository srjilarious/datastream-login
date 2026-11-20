// Stand-ins for kscreenlocker's context objects so the acidburn lock screen
// can be screenshotted with the plain `qml` runtime. Password "hack"
// unlocks, anything else fails. Needs acidburn/lockscreen/settings.js
// (tools/conf2js.sh); set Palette= in acidburn/theme.conf before generating
// it to try another palette.
//
//   tools/conf2js.sh acidburn/theme.conf > acidburn/lockscreen/settings.js
//   QT_FORCE_STDERR_LOGGING=1 qml6 harness/acidburn-lock.qml -- "$PWD/acidburn/lockscreen" <shot dir>
import QtQuick

Window {
    id: win
    width: 1600
    height: 900
    visible: true
    color: "black"

    // Arguments after "--": lock screen dir, shot dir.
    readonly property var args: {
        const a = Qt.application.arguments
        return a.slice(a.indexOf("--") + 1)
    }

    property string kscreenlocker_userName: "jeffdw"

    QtObject {
        id: authenticator
        property bool unlocked: false
        property bool pamTimeout: false
        property string infoMessage: ""
        property string errorMessage: ""
        signal succeeded()
        signal failed(int kind)
        function startAuthenticating() {}
        function stopAuthenticating() {}
        function respond(p) { p === "hack" ? okTimer.start() : failTimer.start() }
    }
    Timer { id: failTimer; interval: 700; onTriggered: authenticator.failed(0) }
    // Like kscreenlocker 6.8: after a success, stopAuthenticating() kills the
    // PAM worker, which reports one more failed(0) shortly afterwards.
    Timer { id: okTimer; interval: 700; onTriggered: { authenticator.unlocked = true; authenticator.succeeded(); lateFailTimer.start() } }
    Timer { id: lateFailTimer; interval: 250; onTriggered: authenticator.failed(0) }

    Loader {
        id: loader
        anchors.fill: parent
        source: Qt.resolvedUrl(win.args[0] + "/LockScreen.qml")
        onLoaded: { item.width = Qt.binding(() => win.width); item.height = Qt.binding(() => win.height) }
    }

    function shot(name) {
        loader.grabToImage(r => r.saveToFile(win.args[1] + "/" + name + ".png"))
    }

    // Script: the intro is cut short by a key press (as when you come back
    // to a locked screen and start typing), a failed unlock, a good one.
    Timer { interval: 1500; running: true; onTriggered: { loader.item.scene.skipIntro(); loader.item.scene.heatUp() } }
    Timer { interval: 2600; running: true; onTriggered: win.shot("1-prompt") }
    Timer { interval: 2900; running: true; onTriggered: authenticator.respond("nope") }
    Timer { interval: 3800; running: true; onTriggered: win.shot("2-denied") }
    Timer { interval: 4600; running: true; onTriggered: authenticator.respond("hack") }
    Timer { interval: 5800; running: true; onTriggered: win.shot("3-granted") }
    // The greeter quits itself UnlockDelay ms after the success.
}
