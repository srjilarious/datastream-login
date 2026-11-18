// The datastream backdrop shared by the SDDM greeter and the lock screen:
// a flight through a neon city of hex-covered towers with hex rain on top,
// a CRT pass over everything and an ACCESS GRANTED / DENIED banner.
//
// Layering, back to front, all inside `scene` so the CRT pass sees it all:
//   city (raycast shader, rendered at RenderScale and upscaled)
//   rain (screen-space hex streams)
//   children of Scene (the terminal)
//   banner
// The owner puts its terminal inside Scene, points `bannerAnchor` at it and
// calls deny() / grant() / burst() as the login goes.
import QtQuick
import "palettes.js" as Palettes

Item {
    id: root

    // Key/value settings from theme.conf: SDDM's `config` object, or the
    // plain JS object the lock screen installer generates.
    property var settings: ({})
    // The banner sits just above this item.
    property Item bannerAnchor: null
    default property alias content: overlay.data

    // theme.conf values arrive as strings. A missing key can come back as
    // undefined or even as an unrelated object (QML resolves "Font" to its
    // own type namespace), so anything that is not a plain value falls back.
    function cfg(key, fallback) {
        const v = settings ? settings[key] : undefined
        const plain = typeof v === "string" || typeof v === "number" || typeof v === "boolean"
        return (!plain || v === "") ? fallback : v
    }
    function cfgNum(key, fallback) {
        const n = Number(cfg(key, fallback))
        return isNaN(n) ? fallback : n
    }
    function cfgBool(key, fallback) {
        return String(cfg(key, fallback)).toLowerCase() === "true"
    }

    // Palette= picks a set of colors from palettes.js; a color key set in
    // theme.conf overrides the palette's value for that key.
    readonly property var colors: Palettes.get(cfg("Palette", "neon"))
    function pal(key) {
        return cfg(key, colors[key])
    }

    // Terminal styling, read once here so both owners style it the same way.
    readonly property string fontFamily: cfg("Font", "JetBrains Mono")
    readonly property int fontPx: Math.max(13, Math.round(height / 64))
    readonly property color accent: pal("Accent")
    readonly property color textColor: pal("TextColor")
    readonly property color okColor: pal("OkColor")
    readonly property color alertColor: pal("AlertColor")

    readonly property color tintA: pal("TintA")
    readonly property color tintB: pal("TintB")
    readonly property color tintC: pal("TintC")
    readonly property color groundTint: pal("GroundTint")
    readonly property color rainTint: pal("RainTint")
    readonly property color rainHead: pal("RainHeadTint")
    readonly property real monochrome: {
        const n = Number(pal("Monochrome"))
        return isNaN(n) ? 0 : Math.max(0, Math.min(1, n))
    }
    readonly property color monochromeTint: pal("MonochromeTint")
    readonly property real baseSpeed: cfgNum("FlySpeed", 0.9)
    readonly property real renderScale: Math.max(0.25, Math.min(1.0, cfgNum("RenderScale", 0.75)))
    // City=false leaves a black screen behind the rain; Rain=false drops the rain.
    readonly property bool cityOn: cfgBool("City", true)
    readonly property bool rainOn: cfgBool("Rain", true)

    property real clock: 0
    property real travel: 0
    property real speed: baseSpeed
    property real climb: 0
    property real glitch: 0
    property real flash: 0
    property color flashColor: "#ff2b4f"

    // Integrate distance from speed so the warp on login can ramp smoothly
    // without the camera jumping.
    FrameAnimation {
        running: true
        onTriggered: {
            root.clock += frameTime
            root.travel += frameTime * root.speed
        }
    }

    // Now and then rise above the rooftops for a skyline pass, then dive.
    SequentialAnimation on climb {
        running: root.cfgBool("Climb", true)
        loops: Animation.Infinite
        PauseAnimation { duration: 22000 }
        NumberAnimation { to: 1; duration: 7000; easing.type: Easing.InOutSine }
        PauseAnimation { duration: 11000 }
        NumberAnimation { to: 0; duration: 6000; easing.type: Easing.InOutCubic }
    }

    function burst(amount, ms) {
        glitchAnim.stop()
        glitchAnim.from = amount
        glitchAnim.duration = ms
        glitchAnim.start()
    }
    NumberAnimation {
        id: glitchAnim
        target: root
        property: "glitch"
        to: 0
        easing.type: Easing.OutQuad
    }
    function flashWith(c, amount, ms) {
        flashColor = c
        flashAnim.stop()
        flashAnim.from = amount
        flashAnim.duration = ms
        flashAnim.start()
    }
    NumberAnimation {
        id: flashAnim
        target: root
        property: "flash"
        to: 0
        easing.type: Easing.OutCubic
    }

    function deny() {
        burst(1.0, 900)
        flashWith(alertColor, 0.35, 700)
        banner.show("ACCESS DENIED", alertColor)
    }
    function grant() {
        burst(0.5, 600)
        flashWith(okColor, 0.25, 1200)
        banner.show("ACCESS GRANTED", okColor)
        warp.start()
    }

    // Small idle glitches so the screen never feels static.
    Timer {
        running: root.cfgBool("IdleGlitch", true)
        repeat: true
        interval: 7000
        onTriggered: {
            interval = 4000 + Math.random() * 10000
            if (root.glitch < 0.05)
                root.burst(0.25 + Math.random() * 0.3, 180 + Math.random() * 220)
        }
    }

    Item {
        id: scene
        anchors.fill: parent

        layer.enabled: true
        layer.effect: ShaderEffect {
            property real time: root.clock
            property real glitch: root.glitch
            property real flash: root.flash
            property real scan: root.cfgNum("Scanlines", 0.6)
            property point res: Qt.point(width, height)
            property color flashColor: root.flashColor
            property real mono: root.monochrome
            property color monoTint: root.monochromeTint
            fragmentShader: Qt.resolvedUrl("shaders/post.frag.qsb")
        }

        Item {
            anchors.fill: parent
            visible: root.cityOn
            // The raycast is the expensive part; render it smaller and let
            // the layer upscale. The CRT pass hides the softness.
            layer.enabled: root.renderScale < 1.0
            layer.smooth: true
            layer.textureSize: Qt.size(Math.round(width * root.renderScale),
                                       Math.round(height * root.renderScale))

            ShaderEffect {
                anchors.fill: parent
                blending: false
                property real time: root.clock
                property real travel: root.travel
                property real aspect: width / Math.max(1, height)
                property real climb: root.climb
                property color tintA: root.tintA
                property color tintB: root.tintB
                property color tintC: root.tintC
                property color groundTint: root.groundTint
                fragmentShader: Qt.resolvedUrl("shaders/city.frag.qsb")
            }
        }

        ShaderEffect {
            anchors.fill: parent
            visible: root.rainOn && density > 0
            opacity: root.cfgNum("RainOpacity", 0.55)
            property real time: root.clock
            property real density: root.cfgNum("RainDensity", 0.45)
            property point res: Qt.point(width, height)
            property real cellPx: Math.max(8, Math.round(root.height / 60))
            property color rainTint: root.rainTint
            property color headTint: root.rainHead
            fragmentShader: Qt.resolvedUrl("shaders/rain.frag.qsb")
        }

        Item {
            id: overlay
            anchors.fill: parent
        }

        Banner {
            id: banner
            anchors.horizontalCenter: parent.horizontalCenter
            y: (root.bannerAnchor ? root.bannerAnchor.y : root.height * 0.3) - height - root.height * 0.04
            fontFamily: root.fontFamily
            fontPx: Math.round(root.height / 11)
            ghostA: root.pal("GhostA")
            ghostB: root.pal("GhostB")
        }
    }

    NumberAnimation {
        id: warp
        target: root
        property: "speed"
        to: root.baseSpeed * 14
        duration: 1600
        easing.type: Easing.InQuad
    }
}
