// The datastream settings window: a live preview of the login screen over
// a short form. `backend` (datastream-settings.py) loads the saved choices
// and applies them to the login and lock screens.
//
// To add an option: add it to OPTION_DEFAULTS in datastream-settings.py,
// read it in shared/Scene.qml (or the owners), and add a control below that
// calls window.set("<Key>", value).
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "shared"
import "shared/palettes.js" as Palettes

Kirigami.ApplicationWindow {
    id: window

    title: "datastream settings"
    width: Kirigami.Units.gridUnit * 40
    height: Kirigami.Units.gridUnit * 38
    minimumWidth: Kirigami.Units.gridUnit * 28
    minimumHeight: Kirigami.Units.gridUnit * 30

    // The choices being edited, as the theme reads them (key -> value).
    // Replaced as a whole on every change so the preview's bindings update.
    property var values: backend.load()
    property bool applying: false

    readonly property string nodeName: values.NodeName !== "" ? values.NodeName : backend.hostName

    function set(key, value) {
        const next = Object.assign({}, values)
        next[key] = value
        values = next
    }

    Connections {
        target: backend
        function onApplyFinished(ok, message) {
            window.applying = false
            result.type = ok ? Kirigami.MessageType.Positive : Kirigami.MessageType.Warning
            result.text = message
            result.visible = true
        }
    }

    pageStack.initialPage: Kirigami.ScrollablePage {
        title: "Login and lock screen"

        ColumnLayout {
            spacing: Kirigami.Units.largeSpacing

            // The real scene at a fixed 1600x900, scaled down to fit, so
            // the terminal and banner keep their on-screen proportions.
            Rectangle {
                id: previewBox
                Layout.fillWidth: true
                Layout.preferredHeight: width * 9 / 16
                color: "black"
                clip: true

                Item {
                    width: 1600
                    height: 900
                    scale: previewBox.width / width
                    transformOrigin: Item.TopLeft

                    Scene {
                        id: scene
                        anchors.fill: parent
                        settings: window.values
                        bannerAnchor: terminal

                        Terminal {
                            id: terminal
                            anchors.centerIn: parent
                            enabled: false
                            fontFamily: scene.fontFamily
                            fontPx: scene.fontPx
                            accent: scene.accent
                            textColor: scene.textColor
                            okColor: scene.okColor
                            alertColor: scene.alertColor

                            title: "MAINFRAME ACCESS NODE // " + window.nodeName.toUpperCase()
                            bootScript: [
                                { msg: "carrier detected on line 0x" + hex(4), status: "OK", ok: true },
                                { msg: "routing through 7 relays", status: "OK", ok: true },
                                { msg: "security clearance", status: "REQUIRED", ok: false }
                            ]
                            userName: backend.userName
                            footerKeys: [{ key: "F10", action: "session" }, { key: "F12", action: "power off" }]
                        }
                    }
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                QQC2.Button {
                    text: "Preview ACCESS GRANTED"
                    onClicked: scene.grant()
                }
                QQC2.Button {
                    text: "Preview ACCESS DENIED"
                    onClicked: scene.deny()
                }
            }

            Kirigami.FormLayout {
                Layout.fillWidth: true

                QQC2.ComboBox {
                    Kirigami.FormData.label: "Palette:"
                    model: Object.keys(Palettes.palettes)
                    currentIndex: Math.max(0, model.indexOf(String(window.values.Palette).toLowerCase()))
                    onActivated: (index) => window.set("Palette", model[index])
                }

                QQC2.TextField {
                    Kirigami.FormData.label: "Node name:"
                    text: window.values.NodeName
                    placeholderText: backend.hostName
                    onTextEdited: window.set("NodeName", text)
                }

                QQC2.CheckBox {
                    Kirigami.FormData.label: "Show:"
                    text: "Flying city"
                    checked: window.values.City
                    onToggled: window.set("City", checked)
                }
                QQC2.CheckBox {
                    text: "Hex rain"
                    checked: window.values.Rain
                    onToggled: window.set("Rain", checked)
                }
            }

            Kirigami.InlineMessage {
                id: result
                Layout.fillWidth: true
                showCloseButton: true
                visible: false
            }

            Kirigami.InlineMessage {
                Layout.fillWidth: true
                type: Kirigami.MessageType.Information
                visible: !backend.sddmInstalled || !backend.lockInstalled
                text: !backend.sddmInstalled && !backend.lockInstalled
                    ? "Neither screen is installed yet; Apply only saves the choices."
                    : (!backend.sddmInstalled
                       ? "The login screen is not installed; Apply only updates the lock screen."
                       : "The lock screen is not installed; Apply only updates the login screen.")
            }
        }

        footer: QQC2.ToolBar {
            contentItem: RowLayout {
                Item { Layout.fillWidth: true }
                QQC2.BusyIndicator {
                    running: window.applying
                    visible: running
                    Layout.preferredHeight: applyButton.height
                }
                QQC2.Button {
                    id: applyButton
                    text: "Apply"
                    icon.name: "dialog-ok-apply"
                    enabled: !window.applying
                    onClicked: {
                        window.applying = true
                        result.visible = false
                        backend.apply(window.values)
                    }
                }
                QQC2.Button {
                    text: "Close"
                    icon.name: "window-close"
                    onClicked: window.close()
                }
            }
        }
    }
}
