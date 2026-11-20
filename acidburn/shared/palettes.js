.pragma library
// acidburn color palettes, picked with Palette= in acidburn/theme.conf.
// Every key here can also be set on its own in theme.conf, which overrides
// the palette's value.
//
// To add a palette, copy an entry, give it a new lowercase name and change
// the colors; Palette=<name> then selects it.

var palettes = {
    // The film: blue liquid plasma, a cream and gold diamond, a scorched
    // rust interior and a lavender-white halftone flame.
    film: {
        // Plasma.
        PlasmaDeep: "#02040f",
        PlasmaMid: "#2043d8",
        PlasmaLight: "#cdd5ff",
        PlasmaSheen: "#2bd98a",
        PlasmaStreak: "#d0303a",
        // Diamond and scorched paper.
        Gold: "#c8ad6c",
        Cream: "#efe3c0",
        Rust: "#a4471e",
        Soot: "#2a1408",
        SkyTint: "#a9cbe6",
        // Flame: dots before the plasma shows, then a ramp over the plasma.
        DotTint: "#cfd0f5",
        FlameLow: "#3b3522",
        FlameHigh: "#f6f2ff",
        // Prompt.
        Accent: "#e2c98a",
        TextColor: "#efe6cc",
        OkColor: "#9fe0ff",
        AlertColor: "#ff4a2a",
        // The two misaligned copies behind the ACCESS banner.
        GhostA: "#2a4cff",
        GhostB: "#e2c98a"
    },

    // Toxic: green plasma with magenta streaks, a hot pink emblem.
    toxic: {
        PlasmaDeep: "#020c06",
        PlasmaMid: "#1aa844",
        PlasmaLight: "#d8ffd0",
        PlasmaSheen: "#ff3fd0",
        PlasmaStreak: "#ffe14a",
        Gold: "#e0559f",
        Cream: "#ffd9ef",
        Rust: "#6e1a7e",
        Soot: "#1a0420",
        SkyTint: "#7affc8",
        DotTint: "#e8ffe0",
        FlameLow: "#3a0838",
        FlameHigh: "#fff0fa",
        Accent: "#ff6fcf",
        TextColor: "#ffe6f6",
        OkColor: "#7aff9a",
        AlertColor: "#ffe14a",
        GhostA: "#1aa844",
        GhostB: "#ff4fb8"
    }
};

function get(name) {
    const key = String(name || "").trim().toLowerCase()
    return palettes.hasOwnProperty(key) ? palettes[key] : palettes.film
}
