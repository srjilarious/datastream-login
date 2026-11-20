// The acidburn login prompt: the node name, the user's handle in big
// spaced capitals, and a slim diamond-tipped field where each password
// character drops in as a halftone dot. It has the same owner-facing API as
// datastream's Terminal (submitted / fail / succeed / say ...), so the SDDM
// and lock screen wiring stays the same; it knows nothing about either.
//
// Keys: Enter on the handle moves to the password, Enter on the password
// submits, Tab / Shift+Tab switch between them, Up/Down on the handle emit
// userCycleRequested(), Escape clears the password, and F-keys listed in
// footerKeys (or sessionKey) emit keyCommand("F<n>").
import QtQuick

FocusScope {
    id: prompt

    property string fontFamily: "monospace"
    property int fontPx: 16
    property color accent: "#e2c98a"
    property color textColor: "#efe6cc"
    property color okColor: "#9fe0ff"
    property color alertColor: "#ff4a2a"

    // Small spaced line above the handle.
    property string caption: ""
    // Handle line contents. When userEditable is false it is read-only and
    // focus starts on the password.
    property string userName: ""
    property bool userEditable: true
    // What the handle line holds right now (userName is only the start value).
    readonly property string currentUser: userInput.text
    // Session line text; empty hides it. Clicking it emits keyCommand(sessionKey).
    property string sessionLabel: ""
    property string sessionKey: "F10"
    // Footer entries: { key: "F12", action: "power off" }.
    property var footerKeys: []
    property bool capsLock: false
    // Fades the prompt in; keys work either way.
    property bool shown: true

    signal submitted(string user, string password)
    signal userCycleRequested(int step)
    signal keyCommand(string key)
    // Any key press, so the owner can skip the intro and keep PAM awake.
    signal activity()
    // A character typed into the password.
    signal typed()
    signal denied()
    signal granted()

    property bool busy: false
    // Set by succeed(); the login is over from then on.
    property bool accepted: false
    property int failures: 0
    property string statusText: ""
    property color statusColor: textColor

    readonly property real dotSize: Math.round(fontPx * 0.62)
    readonly property real dotGap: Math.round(fontPx * 0.42)
    readonly property int maxDots: Math.max(0, Math.floor((field.width - fontPx * 4) / (dotSize + dotGap)))

    width: fontPx * 32
    height: column.implicitHeight
    opacity: shown ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }

    // Called by the owner once the login attempt has been rejected. Ignored
    // after succeed(), so a late failure from a backend that is shutting
    // down cannot turn ACCESS GRANTED into ACCESS DENIED.
    function fail(message) {
        if (accepted)
            return
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
        if (accepted)
            return
        accepted = true
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

    function firstField() {
        return (userInput.text.length > 0 || !userEditable) ? passInput : userInput
    }

    function submit() {
        if (busy || accepted)
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

    // The inputs see keys first; whatever they do not accept bubbles up here.
    Keys.onPressed: (event) => {
        activity()
        if (event.key >= Qt.Key_F1 && event.key <= Qt.Key_F35) {
            const name = "F" + (event.key - Qt.Key_F1 + 1)
            if (isFooterKey(name) || (sessionLabel !== "" && name === sessionKey))
                keyCommand(name)
            event.accepted = true
        }
    }

    SequentialAnimation {
        id: shake
        property real amp: prompt.fontPx * 1.2
        NumberAnimation { target: column; property: "anchors.horizontalCenterOffset"; to: shake.amp; duration: 40 }
        NumberAnimation { target: column; property: "anchors.horizontalCenterOffset"; to: -shake.amp; duration: 60 }
        NumberAnimation { target: column; property: "anchors.horizontalCenterOffset"; to: shake.amp * 0.6; duration: 60 }
        NumberAnimation { target: column; property: "anchors.horizontalCenterOffset"; to: -shake.amp * 0.3; duration: 60 }
        NumberAnimation { target: column; property: "anchors.horizontalCenterOffset"; to: 0; duration: 60 }
    }

    // Runs while authenticating: the dots pulse in a wave.
    property real wave: 0
    NumberAnimation on wave {
        running: prompt.busy
        loops: Animation.Infinite
        from: 0
        to: Math.PI * 2
        duration: 900
    }

    Column {
        id: column
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width
        spacing: prompt.fontPx * 0.7

        PromptText {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: prompt.caption !== ""
            text: prompt.caption.toUpperCase()
            color: prompt.accent
            opacity: 0.75
            font.letterSpacing: prompt.fontPx * 0.45
        }

        // The handle.
        Item {
            width: parent.width
            height: userInput.height
            TextInput {
                id: userInput
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.max(contentWidth, prompt.fontPx) + prompt.fontPx
                horizontalAlignment: TextInput.AlignHCenter
                text: prompt.userName
                readOnly: !prompt.userEditable
                activeFocusOnTab: prompt.userEditable
                font.family: prompt.fontFamily
                font.pixelSize: Math.round(prompt.fontPx * 2.1)
                font.bold: true
                font.letterSpacing: prompt.fontPx * 0.5
                font.capitalization: Font.AllUppercase
                color: prompt.textColor
                selectionColor: prompt.accent
                selectedTextColor: "black"
                cursorVisible: false
                cursorDelegate: Item {}
                KeyNavigation.tab: passInput
                KeyNavigation.backtab: passInput
                Keys.onReturnPressed: passInput.forceActiveFocus()
                Keys.onEnterPressed: passInput.forceActiveFocus()
                Keys.onUpPressed: prompt.userCycleRequested(-1)
                Keys.onDownPressed: prompt.userCycleRequested(1)
                onTextEdited: prompt.activity()
            }
            // Underline while the handle is being edited.
            Rectangle {
                anchors.top: userInput.bottom
                anchors.horizontalCenter: userInput.horizontalCenter
                width: userInput.contentWidth
                height: 2
                color: prompt.accent
                visible: userInput.activeFocus && prompt.userEditable
            }
            // Arrows hint that Up/Down switch users.
            PromptText {
                anchors.verticalCenter: userInput.verticalCenter
                anchors.right: userInput.left
                anchors.rightMargin: prompt.fontPx
                text: "◂"
                color: prompt.accent
                visible: userInput.activeFocus && prompt.userEditable
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: prompt.userCycleRequested(-1) }
            }
            PromptText {
                anchors.verticalCenter: userInput.verticalCenter
                anchors.left: userInput.right
                anchors.leftMargin: prompt.fontPx
                text: "▸"
                color: prompt.accent
                visible: userInput.activeFocus && prompt.userEditable
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: prompt.userCycleRequested(1) }
            }
            MouseArea {
                anchors.fill: userInput
                enabled: prompt.userEditable
                onClicked: userInput.forceActiveFocus()
            }
        }

        // The password field: a slim bar with diamond tips.
        Item {
            id: field
            width: parent.width * 0.82
            height: Math.round(prompt.fontPx * 2.4)
            anchors.horizontalCenter: parent.horizontalCenter

            readonly property color edge: passInput.activeFocus ? prompt.accent : Qt.rgba(prompt.accent.r, prompt.accent.g, prompt.accent.b, 0.45)

            Rectangle {
                anchors.fill: parent
                anchors.leftMargin: tipL.width / 2
                anchors.rightMargin: tipR.width / 2
                color: Qt.rgba(0.0, 0.0, 0.02, 0.55)
                border.color: field.edge
                border.width: 1.5
            }
            Rectangle {
                id: tipL
                width: field.height * 0.5
                height: width
                rotation: 45
                anchors.verticalCenter: parent.verticalCenter
                x: 0
                color: field.edge
            }
            Rectangle {
                id: tipR
                width: field.height * 0.5
                height: width
                rotation: 45
                anchors.verticalCenter: parent.verticalCenter
                x: parent.width - width
                color: field.edge
            }

            Row {
                id: dots
                anchors.centerIn: parent
                spacing: prompt.dotGap
                Repeater {
                    model: Math.min(passInput.length, prompt.maxDots)
                    delegate: Rectangle {
                        required property int index
                        width: prompt.dotSize
                        height: width
                        radius: width / 2
                        color: prompt.accent
                        opacity: prompt.busy ? 0.35 + 0.65 * (0.5 + 0.5 * Math.sin(prompt.wave - index * 0.7)) : 1
                        // Each new dot lands big and settles.
                        NumberAnimation on scale { from: 1.9; to: 1; duration: 220; easing.type: Easing.OutBack }
                    }
                }
                // Blinking diamond cursor after the last dot.
                Rectangle {
                    width: prompt.dotSize * 0.8
                    height: width
                    rotation: 45
                    anchors.verticalCenter: parent.verticalCenter
                    color: prompt.accent
                    visible: passInput.activeFocus && !prompt.busy
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

            PromptText {
                anchors.centerIn: parent
                visible: passInput.length === 0 && !passInput.activeFocus
                text: "password"
                opacity: 0.45
                font.letterSpacing: prompt.fontPx * 0.3
            }

            // Takes the keys; the dots above stand in for its text.
            TextInput {
                id: passInput
                anchors.fill: parent
                echoMode: TextInput.Password
                color: "transparent"
                selectionColor: "transparent"
                selectedTextColor: "transparent"
                cursorDelegate: Item {}
                enabled: !prompt.busy
                font.pixelSize: prompt.fontPx
                KeyNavigation.tab: prompt.userEditable ? userInput : passInput
                KeyNavigation.backtab: prompt.userEditable ? userInput : passInput
                Keys.onReturnPressed: prompt.submit()
                Keys.onEnterPressed: prompt.submit()
                Keys.onEscapePressed: (event) => {
                    text = ""
                    // Let the lock screen see Escape too.
                    event.accepted = false
                }
                onTextEdited: {
                    prompt.activity()
                    prompt.typed()
                }
            }
        }

        // Status line, with caps lock on the same line when it is on.
        PromptText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: {
                const parts = []
                if (prompt.statusText !== "")
                    parts.push(prompt.statusText)
                if (prompt.capsLock)
                    parts.push("caps lock")
                return parts.join("  ·  ")
            }
            color: prompt.capsLock && prompt.statusText === "" ? prompt.alertColor : prompt.statusColor
            height: prompt.fontPx * 1.4
        }

        // Session and power keys.
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: prompt.fontPx * 2
            KeyHint {
                visible: prompt.sessionLabel !== ""
                key: prompt.sessionKey
                action: prompt.sessionLabel
                onActivated: prompt.keyCommand(prompt.sessionKey)
            }
            Repeater {
                model: prompt.footerKeys
                delegate: KeyHint {
                    required property var modelData
                    key: modelData.key
                    action: modelData.action
                    onActivated: prompt.keyCommand(modelData.key)
                }
            }
        }
    }

    component PromptText: Text {
        font.family: prompt.fontFamily
        font.pixelSize: prompt.fontPx
        color: prompt.textColor
    }

    component KeyHint: PromptText {
        id: hint
        property string key
        property string action
        signal activated()
        textFormat: Text.StyledText
        text: "<font color=\"" + prompt.accent + "\">" + key + "</font>  " + action
        font.pixelSize: Math.round(prompt.fontPx * 0.85)
        opacity: hover.containsMouse ? 1.0 : 0.6
        MouseArea {
            id: hover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: hint.activated()
        }
    }

    Component.onCompleted: firstField().forceActiveFocus()
}
