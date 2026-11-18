// Stand-ins for kscreenlocker's context objects so the lock screen can be
// screenshotted with the plain `qml` runtime. Password "hack" unlocks,
// anything else fails. Needs lockscreen/settings.js (tools/conf2js.sh); set
// Palette= in theme.conf before generating it to try another palette.
//
//   QT_FORCE_STDERR_LOGGING=1 qml6 harness/lock.qml -- "$PWD/lockscreen" <shot dir>
import QtQuick

Window {
    id: win
    width: 1600
    height: 900
    visible: true
    color: "black"

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
        source: Qt.resolvedUrl(Qt.application.arguments[Qt.application.arguments.length - 2] + "/LockScreen.qml")
        onLoaded: { item.width = Qt.binding(() => win.width); item.height = Qt.binding(() => win.height) }
    }

    function shot(name) {
        loader.grabToImage(r => r.saveToFile(Qt.application.arguments[Qt.application.arguments.length - 1] + "/" + name + ".png"))
    }

    // Script: short boot log, prompt, a failed unlock, then a good one.
    Timer { interval: 700; running: true; onTriggered: win.shot("1-boot") }
    Timer { interval: 3000; running: true; onTriggered: win.shot("2-prompt") }
    Timer { interval: 3300; running: true; onTriggered: authenticator.respond("nope") }
    Timer { interval: 4200; running: true; onTriggered: win.shot("3-denied") }
    Timer { interval: 4600; running: true; onTriggered: authenticator.respond("hack") }
    Timer { interval: 5900; running: true; onTriggered: win.shot("4-granted") }
}
