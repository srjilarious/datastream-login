// Big flickering status word with two offset ghost copies that jitter like
// a misaligned CRT gun. show() runs the whole sequence; it hides itself.
import QtQuick

Item {
    id: banner

    property string fontFamily: "monospace"
    property int fontPx: 96
    property string label: ""
    property color tint: "white"
    property real jitter: 0
    // Colors of the two offset ghost copies.
    property color ghostA: "#ff2bd6"
    property color ghostB: "#00e5ff"

    width: main.implicitWidth
    height: main.implicitHeight
    opacity: 0

    function show(text, color) {
        label = text
        tint = color
        seq.restart()
    }

    Text {
        x: banner.jitter * 6
        y: -banner.jitter * 2
        text: banner.label
        font.family: banner.fontFamily
        font.pixelSize: banner.fontPx
        font.bold: true
        color: banner.ghostA
        opacity: 0.55
    }
    Text {
        x: -banner.jitter * 5
        y: banner.jitter * 3
        text: banner.label
        font.family: banner.fontFamily
        font.pixelSize: banner.fontPx
        font.bold: true
        color: banner.ghostB
        opacity: 0.55
    }
    Text {
        id: main
        text: banner.label
        font.family: banner.fontFamily
        font.pixelSize: banner.fontPx
        font.bold: true
        color: banner.tint
        style: Text.Outline
        styleColor: Qt.darker(banner.tint, 3)
    }

    SequentialAnimation {
        id: seq
        // Stutter on like a sign with a bad ballast.
        PropertyAction { target: banner; property: "opacity"; value: 1 }
        PropertyAction { target: banner; property: "jitter"; value: 1 }
        PauseAnimation { duration: 60 }
        PropertyAction { target: banner; property: "opacity"; value: 0 }
        PauseAnimation { duration: 50 }
        PropertyAction { target: banner; property: "opacity"; value: 1 }
        PauseAnimation { duration: 90 }
        PropertyAction { target: banner; property: "opacity"; value: 0.2 }
        PauseAnimation { duration: 40 }
        PropertyAction { target: banner; property: "opacity"; value: 1 }
        NumberAnimation { target: banner; property: "jitter"; to: 0; duration: 400; easing.type: Easing.OutElastic }
        PauseAnimation { duration: 1100 }
        PropertyAction { target: banner; property: "jitter"; value: -0.7 }
        PauseAnimation { duration: 50 }
        PropertyAction { target: banner; property: "jitter"; value: 0 }
        NumberAnimation { target: banner; property: "opacity"; to: 0; duration: 350 }
    }
}
