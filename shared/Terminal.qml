// The retro login terminal shared by the SDDM greeter and the lock screen.
// It types out `bootScript`, then shows login and password prompts. It knows
// nothing about SDDM or kscreenlocker: the owner listens for submitted() and
// keyCommand(), and reports back with fail(), succeed() and say().
//
// Keys: Enter on the login line moves to the password line, Enter on the
// password line submits, Tab / Shift+Tab switch lines, Up/Down on the login
// line emit userCycleRequested(), Escape clears the password, and F-keys
// listed in footerKeys emit keyCommand("F<n>"). Any key during the boot log
// skips to the prompt; a printable key also lands in the focused field.
import QtQuick

FocusScope {
    id: term

    property string fontFamily: "monospace"
    property int fontPx: 16
    property color accent: "#00e5ff"
    property color textColor: "#b8f7ff"
    property color okColor: "#39ff88"
    property color alertColor: "#ff2b4f"

    // Header line, left side.
    property string title: ""
    // Lines typed out before the prompt: { msg, status, ok }.
    property var bootScript: []
    // Login line contents. When userEditable is false the line is read-only
    // and focus starts on the password line.
    property string userName: ""
    property bool userEditable: true
    // What the login line holds right now (userName is only the start value).
    readonly property string currentUser: userInput.text
    // Text for the session line; empty hides the line. Clicking it emits
    // keyCommand(sessionKey).
    property string sessionLabel: ""
    property string sessionKey: "F10"
    // Footer entries: { key: "F12", action: "power off" }.
    property var footerKeys: []
    property bool capsLock: false

    signal submitted(string user, string password)
    signal userCycleRequested(int step)
    signal keyCommand(string key)
    // Any key press, so the lock screen can keep PAM awake.
    signal activity()
    signal denied()
    signal granted()
    signal glitchRequested(real amount)

    readonly property int cols: 64
    // advanceWidth() is a method and does not notify, so read fm.font first
    // to re-measure when the family or size settles.
    readonly property real charW: {
        fm.font
        return fm.advanceWidth("M")
    }
    readonly property real lineH: fm.height * 1.25
    readonly property real pad: charW * 2

    property bool bootDone: false
    property bool busy: false
    property int failures: 0
    property string statusText: ""
    property color statusColor: textColor

    width: cols * charW + pad * 2
    height: body.implicitHeight + pad * 2

    FontMetrics {
        id: fm
        font.family: term.fontFamily
        font.pixelSize: term.fontPx
    }

    function hex(n) {
        let s = ""
        for (let i = 0; i < n; i++)
            s += "0123456789ABCDEF"[Math.floor(Math.random() * 16)]
        return s
    }
    // Pads a log message with a dot leader that runs up to its status tag,
    // which is right-aligned: "> " + msg + " " + dots + " " + "[" status "]".
    function leader(msg, status) {
        return msg + " " + ".".repeat(Math.max(3, cols - 2 - msg.length - 2 - (status.length + 2)))
    }

    // Called by the owner once the login attempt has been rejected.
    function fail(message) {
        busy = false
        failures++
        passInput.text = ""
        statusColor = alertColor
        statusText = message
        passInput.forceActiveFocus()
        shake.restart()
        denied()
    }
    // Called by the owner once the login attempt has been accepted.
    function succeed(message) {
        statusColor = okColor
        statusText = message
        granted()
    }
    // Informational line from the backend (PAM messages and the like).
    function say(message, color) {
        statusColor = color === undefined ? textColor : color
        statusText = message
    }
    function clearPassword() {
        passInput.text = ""
    }
    function setUser(name) {
        userInput.text = name
    }

    ListModel { id: bootLog }
    property int bootStep: 0
    property int typed: 0
    property int hold: 0

    Timer {
        id: typer
        interval: 16
        repeat: true
        running: true
        onTriggered: {
            if (term.bootStep >= term.bootScript.length) {
                term.finishBoot()
                return
            }
            const line = term.bootScript[term.bootStep]
            const full = term.leader(line.msg, line.status)
            if (bootLog.count <= term.bootStep)
                bootLog.append({ msg: "", status: "", ok: line.ok })
            if (term.typed < full.length) {
                // Uneven typing: sometimes a burst, sometimes one char.
                term.typed = Math.min(full.length, term.typed + 2 + Math.floor(Math.random() * 4))
                bootLog.setProperty(term.bootStep, "msg", full.slice(0, term.typed))
                term.hold = 3 + Math.floor(Math.random() * 10)
            } else if (term.hold > 0) {
                term.hold--
            } else {
                bootLog.setProperty(term.bootStep, "status", line.status)
                if (Math.random() < 0.35)
                    term.glitchRequested(0.2)
                term.bootStep++
                term.typed = 0
            }
        }
    }

    function finishBoot() {
        if (bootDone)
            return
        typer.stop()
        for (let i = 0; i < bootScript.length; i++) {
            const line = bootScript[i]
            if (i < bootLog.count) {
                bootLog.setProperty(i, "msg", leader(line.msg, line.status))
                bootLog.setProperty(i, "status", line.status)
            } else {
                bootLog.append({ msg: leader(line.msg, line.status), status: line.status, ok: line.ok })
            }
        }
        bootStep = bootScript.length
        bootDone = true
        firstField().forceActiveFocus()
    }

    function firstField() {
        return (userInput.text.length > 0 || !userEditable) ? passInput : userInput
    }

    function submit() {
        if (busy || !bootDone)
            return
        if (userInput.text.length === 0) {
            userInput.forceActiveFocus()
            return
        }
        busy = true
        statusColor = accent
        statusText = "authenticating"
        submitted(userInput.text, passInput.text)
    }

    function isFooterKey(name) {
        for (let i = 0; i < footerKeys.length; i++)
            if (footerKeys[i].key === name)
                return true
        return false
    }

    // Inputs see keys first; whatever they do not accept bubbles up here.
    // Key presses on the inputs still count as activity through their own
    // handlers below.
    Keys.onPressed: (event) => {
        activity()
        if (!bootDone) {
            finishBoot()
            // Keep a typed character instead of eating it, so typing the
            // password straight away during the boot log works.
            if (event.text.length === 1 && event.text >= " " && event.key !== Qt.Key_Escape) {
                const field = firstField()
                field.insert(field.cursorPosition, event.text)
            }
            event.accepted = true
            return
        }
        if (event.key >= Qt.Key_F1 && event.key <= Qt.Key_F35) {
            const name = "F" + (event.key - Qt.Key_F1 + 1)
            if (isFooterKey(name) || (sessionLabel !== "" && name === sessionKey))
                keyCommand(name)
            event.accepted = true
        }
    }

    SequentialAnimation {
        id: shake
        property real amp: term.charW * 1.5
        NumberAnimation { target: frame; property: "anchors.horizontalCenterOffset"; to: shake.amp; duration: 40 }
        NumberAnimation { target: frame; property: "anchors.horizontalCenterOffset"; to: -shake.amp; duration: 60 }
        NumberAnimation { target: frame; property: "anchors.horizontalCenterOffset"; to: shake.amp * 0.6; duration: 60 }
        NumberAnimation { target: frame; property: "anchors.horizontalCenterOffset"; to: -shake.amp * 0.3; duration: 60 }
        NumberAnimation { target: frame; property: "anchors.horizontalCenterOffset"; to: 0; duration: 60 }
    }

    Item {
        id: frame
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width
        height: parent.height

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0.005, 0.01, 0.03, 0.82)
            border.color: Qt.rgba(term.accent.r, term.accent.g, term.accent.b, 0.35)
            border.width: 1
        }

        // Bright corner brackets over the dim border.
        Repeater {
            model: 4
            delegate: Item {
                required property int index
                readonly property bool atRight: index % 2 === 1
                readonly property bool atBottom: index >= 2
                readonly property real len: term.charW * 3
                x: atRight ? frame.width - len : 0
                y: atBottom ? frame.height - len : 0
                width: len
                height: len
                Rectangle { width: parent.width; height: 2; y: parent.atBottom ? parent.height - 2 : 0; color: term.accent }
                Rectangle { width: 2; height: parent.height; x: parent.atRight ? parent.width - 2 : 0; color: term.accent }
            }
        }

        Column {
            id: body
            x: term.pad
            y: term.pad
            width: term.cols * term.charW
            spacing: 0

            Item {
                width: parent.width
                height: term.lineH
                TermText {
                    text: term.title
                    color: term.accent
                    font.bold: true
                }
                TermText {
                    id: clock
                    anchors.right: parent.right
                    color: term.accent
                    text: Qt.formatDateTime(new Date(), "yyyy-MM-dd HH:mm:ss")
                    Timer {
                        interval: 1000
                        repeat: true
                        running: true
                        onTriggered: clock.text = Qt.formatDateTime(new Date(), "yyyy-MM-dd HH:mm:ss")
                    }
                }
            }
            Rectangle {
                width: parent.width
                height: 1
                color: term.accent
                opacity: 0.5
            }
            Item { width: 1; height: term.lineH * 0.5 }

            Repeater {
                model: bootLog
                delegate: Item {
                    required property string msg
                    required property string status
                    required property bool ok
                    width: body.width
                    height: term.lineH
                    TermText {
                        text: "> " + msg
                        opacity: 0.85
                    }
                    TermText {
                        anchors.right: parent.right
                        text: status === "" ? "" : "[" + status + "]"
                        color: ok ? term.okColor : term.alertColor
                        font.bold: true
                    }
                }
            }

            Item { width: 1; height: term.lineH * 0.6 }

            Column {
                width: parent.width
                opacity: term.bootDone ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 250 } }

                PromptLine {
                    label: "login:"
                    TermInput {
                        id: userInput
                        text: term.userName
                        readOnly: !term.userEditable
                        activeFocusOnTab: term.userEditable
                        KeyNavigation.tab: passInput
                        KeyNavigation.backtab: passInput
                        Keys.onReturnPressed: passInput.forceActiveFocus()
                        Keys.onEnterPressed: passInput.forceActiveFocus()
                        Keys.onUpPressed: term.userCycleRequested(-1)
                        Keys.onDownPressed: term.userCycleRequested(1)
                    }
                }
                PromptLine {
                    label: "password:"
                    TermInput {
                        id: passInput
                        echoMode: TextInput.Password
                        passwordCharacter: "*"
                        passwordMaskDelay: 0
                        KeyNavigation.tab: term.userEditable ? userInput : passInput
                        KeyNavigation.backtab: term.userEditable ? userInput : passInput
                        Keys.onReturnPressed: term.submit()
                        Keys.onEnterPressed: term.submit()
                        Keys.onEscapePressed: (event) => {
                            text = ""
                            // Let the lock screen see Escape too.
                            event.accepted = false
                        }
                        // Every keystroke nudges the screen a little.
                        onTextEdited: {
                            term.activity()
                            if (Math.random() < 0.18)
                                term.glitchRequested(0.12)
                        }
                    }
                }
                PromptLine {
                    label: "session:"
                    visible: term.sessionLabel !== ""
                    TermText {
                        text: term.sessionLabel
                        color: term.accent
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: term.keyCommand(term.sessionKey)
                        }
                    }
                }

                Item { width: 1; height: term.lineH * 0.5 }

                Item {
                    width: parent.width
                    height: term.lineH
                    TermText {
                        id: statusLine
                        color: term.statusColor
                        text: term.statusText === "" ? "" : "> " + term.statusText + (term.busy ? " " + spinner.frame : "")
                    }
                    TermText {
                        anchors.right: parent.right
                        visible: term.capsLock
                        color: term.alertColor
                        text: "[CAPS LOCK]"
                    }
                    Timer {
                        id: spinner
                        property int n: 0
                        readonly property string frame: "|/-\\"[n % 4] + " " + "#".repeat(n % 12) + ".".repeat(11 - n % 12)
                        interval: 90
                        repeat: true
                        running: term.busy
                        onTriggered: n++
                    }
                }
            }

            Item {
                width: 1
                height: term.lineH * 0.5
                visible: term.footerKeys.length > 0
            }
            Rectangle {
                width: parent.width
                height: 1
                color: term.accent
                opacity: 0.3
                visible: term.footerKeys.length > 0
            }
            Row {
                height: term.lineH
                spacing: term.charW * 3
                visible: term.footerKeys.length > 0
                Repeater {
                    model: term.footerKeys
                    delegate: FooterKey {
                        required property var modelData
                        key: modelData.key
                        action: modelData.action
                        onActivated: term.keyCommand(modelData.key)
                    }
                }
            }
        }
    }

    component TermText: Text {
        font.family: term.fontFamily
        font.pixelSize: term.fontPx
        color: term.textColor
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    }

    component PromptLine: Row {
        property string label
        width: body.width
        height: term.lineH
        spacing: term.charW
        TermText {
            width: term.charW * 10
            horizontalAlignment: Text.AlignRight
            text: parent.label
            color: term.accent
        }
    }

    component TermInput: TextInput {
        width: term.charW * 40
        anchors.verticalCenter: parent.verticalCenter
        font.family: term.fontFamily
        font.pixelSize: term.fontPx
        color: term.textColor
        selectionColor: term.accent
        selectedTextColor: "black"
        clip: true
        enabled: !term.busy
        cursorDelegate: Rectangle {
            width: term.charW
            color: term.accent
            visible: parent.activeFocus
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: true
                NumberAnimation { to: 0.9; duration: 0 }
                PauseAnimation { duration: 500 }
                NumberAnimation { to: 0.0; duration: 0 }
                PauseAnimation { duration: 400 }
            }
        }
    }

    component FooterKey: TermText {
        id: fk
        property string key
        property string action
        signal activated()
        textFormat: Text.StyledText
        text: "<font color=\"" + term.accent + "\">&lt;" + key + "&gt;</font> " + action
        opacity: hover.containsMouse ? 1.0 : 0.7
        MouseArea {
            id: hover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: fk.activated()
        }
    }
}
