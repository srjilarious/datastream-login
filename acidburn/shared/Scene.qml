// The acidburn backdrop shared by the SDDM greeter and the lock screen.
//
// Plays an intro once: a wide diamond with a beaded cream border sweeps in,
// burns from the center to white heat, cools into scorched paper while a
// flame pops in as halftone dots, then the diamond breaks into dots and
// liquid plasma floods in behind. The flame drifts up to rest above the
// prompt and stays, flickering, over plasma that never stops flowing.
//
// Layering, back to front, all inside `scene` so the film pass sees it all:
//   plasma (rendered at RenderScale, only used as a texture)
//   emblem (diamond, flame, outro; composites the plasma)
//   children of Scene (the prompt)
//   banner
// The owner puts its prompt inside Scene at y: promptY, shows it once
// promptShown is true, and calls deny() / grant() / heatUp() / skipIntro().
import QtQuick
import "palettes.js" as Palettes

Item {
    id: root

    // Key/value settings from theme.conf: SDDM's `config` object, or the
    // plain JS object the lock screen installer generates.
    property var settings: ({})
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
    readonly property var colors: Palettes.get(cfg("Palette", "film"))
    function pal(key) {
        return cfg(key, colors[key])
    }

    // Prompt styling, read once here so both owners style it the same way.
    readonly property string fontFamily: cfg("Font", "JetBrains Mono")
    readonly property int fontPx: Math.max(14, Math.round(height / 50))
    readonly property color accent: pal("Accent")
    readonly property color textColor: pal("TextColor")
    readonly property color okColor: pal("OkColor")
    readonly property color alertColor: pal("AlertColor")

    readonly property real renderScale: Math.max(0.25, Math.min(1.0, cfgNum("RenderScale", 0.6)))
    readonly property real flowSpeed: cfgNum("FlowSpeed", 0.35)
    readonly property bool pointerSwirl: cfgBool("PointerSwirl", true)
    // Halftone dots stacked across the diamond's height. The dots scale
    // with the emblem, so the flame keeps its detail as it settles.
    readonly property real halftoneDots: Math.max(12, cfgNum("HalftoneDots", 34))

    property real clock: 0
    property real flow: 0

    // Intro progress, each 0..1, animated in order by `intro`.
    property real drawIn: 0
    property real burn: 0
    property real cool: 0
    property real flameOn: 0
    property real dissolve: 0
    // 0: the emblem fills the screen (intro); 1: it rests above the prompt.
    property real settle: 0
    property bool promptShown: false

    // Reactions.
    property real heat: 0
    property real denyAmt: 0
    property real outro: 0
    property real glitch: 0
    property real flash: 0
    property color flashColor: alertColor

    // Pointer whirlpool: target follows the mouse, pointer eases after it.
    property point pointerTarget: Qt.point(0.5, 0.5)
    property point pointer: Qt.point(0.5, 0.5)
    property real swirl: 0

    // Emblem placement. During the intro the diamond nearly fills the
    // screen; at rest the flame sits in the upper part, clear of the prompt.
    readonly property real introScale: Math.min(height * 0.86, width * 0.92 / 1.7)
    readonly property real restScale: height * 0.5
    readonly property real restY: height * 0.34
    readonly property real emblemScale: introScale + (restScale - introScale) * settle
    readonly property real emblemY: height * 0.5 + (restY - height * 0.5) * settle
    // Where the owner should put the top of its prompt.
    readonly property real promptY: restY + restScale * 0.42

    FrameAnimation {
        running: true
        onTriggered: {
            const dt = Math.min(frameTime, 0.1)
            root.clock += dt
            root.flow += dt * (root.flowSpeed + root.heat * 1.2 + root.outro * 2.0)
            root.heat = Math.max(0, root.heat - dt * 0.9)
            root.swirl = Math.max(0, root.swirl - dt * 0.22)
            const k = 1 - Math.exp(-dt * 3.0)
            root.pointer = Qt.point(root.pointer.x + (root.pointerTarget.x - root.pointer.x) * k,
                                    root.pointer.y + (root.pointerTarget.y - root.pointer.y) * k)
        }
    }

    SequentialAnimation {
        id: intro
        PauseAnimation { duration: 300 }
        NumberAnimation { target: root; property: "drawIn"; to: 1; duration: 1100; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "burn"; to: 1; duration: 1400; easing.type: Easing.InQuad }
        ParallelAnimation {
            NumberAnimation { target: root; property: "cool"; to: 1; duration: 1700; easing.type: Easing.OutQuad }
            SequentialAnimation {
                PauseAnimation { duration: 500 }
                NumberAnimation { target: root; property: "flameOn"; to: 1; duration: 1100 }
            }
        }
        PauseAnimation { duration: 500 }
        ParallelAnimation {
            NumberAnimation { target: root; property: "dissolve"; to: 1; duration: 1500; easing.type: Easing.InOutSine }
            SequentialAnimation {
                PauseAnimation { duration: 300 }
                NumberAnimation { target: root; property: "settle"; to: 1; duration: 1600; easing.type: Easing.InOutCubic }
            }
            SequentialAnimation {
                PauseAnimation { duration: 900 }
                PropertyAction { target: root; property: "promptShown"; value: true }
            }
        }
    }

    // Fast-forwards whatever is left of the intro.
    ParallelAnimation {
        id: skipAnim
        PropertyAction { target: root; property: "promptShown"; value: true }
        NumberAnimation { target: root; property: "drawIn"; to: 1; duration: 450 }
        NumberAnimation { target: root; property: "burn"; to: 1; duration: 450 }
        NumberAnimation { target: root; property: "cool"; to: 1; duration: 450 }
        NumberAnimation { target: root; property: "flameOn"; to: 1; duration: 450 }
        NumberAnimation { target: root; property: "dissolve"; to: 1; duration: 600; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "settle"; to: 1; duration: 600; easing.type: Easing.OutCubic }
    }

    function skipIntro() {
        if (!intro.running)
            return
        intro.stop()
        skipAnim.start()
        burst(0.3, 200)
    }

    function heatUp() {
        heat = Math.min(1, heat + 0.3)
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
    NumberAnimation {
        id: denyAnim
        target: root
        property: "denyAmt"
        from: 1
        to: 0
        duration: 1100
        easing.type: Easing.OutCubic
    }

    function deny() {
        denyAnim.restart()
        burst(0.8, 700)
        flashWith(alertColor, 0.22, 600)
        banner.show("ACCESS DENIED", alertColor)
    }
    function grant() {
        skipIntro()
        burst(0.4, 500)
        flashWith(okColor, 0.2, 900)
        banner.show("ACCESS GRANTED", okColor)
        outroAnim.start()
    }
    SequentialAnimation {
        id: outroAnim
        NumberAnimation { target: root; property: "outro"; to: 1; duration: 1000; easing.type: Easing.InQuad }
        NumberAnimation { target: blackout; property: "opacity"; to: 1; duration: 350 }
    }

    // Now and then the flame flares and the picture stutters, so the
    // screen never sits still.
    Timer {
        running: root.cfgBool("IdleGlitch", true) && root.promptShown
        repeat: true
        interval: 9000
        onTriggered: {
            interval = 6000 + Math.random() * 14000
            if (root.glitch < 0.05) {
                root.heat = Math.min(1, root.heat + 0.5 + Math.random() * 0.3)
                root.burst(0.2 + Math.random() * 0.25, 160 + Math.random() * 200)
            }
        }
    }

    Item {
        id: scene
        anchors.fill: parent

        // Film pass shared with datastream: grain, vignette, a little color
        // fringing, and glitch bands when something happens.
        layer.enabled: true
        layer.effect: ShaderEffect {
            property real time: root.clock
            property real glitch: root.glitch
            property real flash: root.flash
            property real scan: root.cfgNum("Scanlines", 0.15)
            property point res: Qt.point(width, height)
            property color flashColor: root.flashColor
            property real mono: 0
            property color monoTint: "white"
            fragmentShader: Qt.resolvedUrl("shaders/post.frag.qsb")
        }

        ShaderEffect {
            id: plasma
            anchors.fill: parent
            blending: false
            property real flow: root.flow
            property real aspect: width / Math.max(1, height)
            // Texture y runs down, the shader's runs up.
            property point pointer: Qt.point(root.pointer.x, 1 - root.pointer.y)
            property real swirl: root.swirl
            property color deep: root.pal("PlasmaDeep")
            property color mid: root.pal("PlasmaMid")
            property color light: root.pal("PlasmaLight")
            property color sheen: root.pal("PlasmaSheen")
            property color streak: root.pal("PlasmaStreak")
            fragmentShader: Qt.resolvedUrl("shaders/plasma.frag.qsb")
        }
        // The plasma is the expensive part; render it smaller and let the
        // emblem pass sample it with filtering.
        ShaderEffectSource {
            id: plasmaTex
            sourceItem: plasma
            hideSource: true
            visible: false
            smooth: true
            textureSize: Qt.size(Math.round(root.width * root.renderScale),
                                 Math.round(root.height * root.renderScale))
        }

        ShaderEffect {
            anchors.fill: parent
            blending: false
            property var plasma: plasmaTex
            property real time: root.clock
            property point res: Qt.point(width, height)
            property point center: Qt.point(width / 2, root.emblemY)
            property real scale: root.emblemScale
            property real cellPx: Math.max(4, root.emblemScale / root.halftoneDots)
            property real drawIn: root.drawIn
            property real burn: root.burn
            property real cool: root.cool
            property real flameOn: root.flameOn
            property real dissolve: root.dissolve
            property real outro: root.outro
            property real heat: root.heat
            property real deny: root.denyAmt
            // A dark pool under the prompt, which sits around promptY.
            property rect shade: Qt.rect(width / 2, root.promptY + root.fontPx * 5,
                                         root.fontPx * 26, root.fontPx * 9)
            property real shadeAmt: root.promptShown ? 0.55 : 0
            Behavior on shadeAmt { NumberAnimation { duration: 900 } }
            property color gold: root.pal("Gold")
            property color cream: root.pal("Cream")
            property color rust: root.pal("Rust")
            property color soot: root.pal("Soot")
            property color skyTint: root.pal("SkyTint")
            property color dotTint: root.pal("DotTint")
            property color flameLow: root.pal("FlameLow")
            property color flameHigh: root.pal("FlameHigh")
            property color alertTint: root.alertColor
            fragmentShader: Qt.resolvedUrl("shaders/emblem.frag.qsb")
        }

        // Tracks the pointer for the whirlpool without taking any clicks.
        MouseArea {
            anchors.fill: parent
            enabled: root.pointerSwirl
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            property real lastX: -1
            property real lastY: -1
            onPositionChanged: (mouse) => {
                if (lastX >= 0) {
                    const moved = Math.hypot(mouse.x - lastX, mouse.y - lastY) / root.height
                    root.swirl = Math.min(1, root.swirl + moved * 1.5)
                }
                lastX = mouse.x
                lastY = mouse.y
                root.pointerTarget = Qt.point(mouse.x / root.width, mouse.y / root.height)
            }
        }

        Item {
            id: overlay
            anchors.fill: parent
        }

        Banner {
            id: banner
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.emblemY - height / 2
            fontFamily: root.fontFamily
            fontPx: Math.round(root.height / 11)
            ghostA: root.pal("GhostA")
            ghostB: root.pal("GhostB")
        }

        Rectangle {
            id: blackout
            anchors.fill: parent
            color: "black"
            opacity: 0
        }
    }

    Component.onCompleted: {
        if (cfgBool("Intro", true)) {
            intro.start()
        } else {
            drawIn = burn = cool = flameOn = dissolve = settle = 1
            promptShown = true
        }
    }
}
