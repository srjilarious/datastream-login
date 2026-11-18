.pragma library
// Color palettes, picked with Palette= in theme.conf. Every key here can
// also be set on its own in theme.conf, which overrides the palette's value.
//
// Monochrome (0..1) runs the final image through a single phosphor color in
// the CRT pass, by brightness: 0 leaves colors alone, 1 is a pure one-color
// tube. MonochromeTint is that phosphor color.
//
// To add a palette, copy an entry, give it a new lowercase name and change
// the colors; Palette=<name> then selects it.

var palettes = {
    // The original: cyan, magenta and amber towers under green rain.
    neon: {
        Accent: "#00e5ff",
        TextColor: "#b8f7ff",
        OkColor: "#39ff88",
        AlertColor: "#ff2b4f",
        TintA: "#00e5ff",
        TintB: "#ff2bd6",
        TintC: "#ffb000",
        GroundTint: "#7a2cff",
        RainTint: "#1aff7a",
        RainHeadTint: "#e8fff2",
        // The two misaligned copies behind the ACCESS banner.
        GhostA: "#ff2bd6",
        GhostB: "#00e5ff",
        Monochrome: "0",
        MonochromeTint: "#33ff66"
    },

    // Green phosphor monitor: everything in shades of one green. Denials
    // show in the hottest, near-white green rather than red.
    phosphor: {
        Accent: "#33ff66",
        TextColor: "#8cff9e",
        OkColor: "#33ff66",
        AlertColor: "#e6ffe6",
        TintA: "#20ff60",
        TintB: "#10a838",
        TintC: "#a0ffb0",
        GroundTint: "#0c7a2a",
        RainTint: "#22ff55",
        RainHeadTint: "#e6ffe6",
        GhostA: "#0c7a2a",
        GhostB: "#5cff80",
        Monochrome: "1",
        MonochromeTint: "#33ff66"
    }
};

function get(name) {
    const key = String(name || "").trim().toLowerCase()
    return palettes.hasOwnProperty(key) ? palettes[key] : palettes.neon
}
