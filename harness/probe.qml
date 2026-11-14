import QtQuick
Item {
    QtObject { id: config }
    function cfg(key, fallback) { const v = config[key]; return (v === undefined || v === null || v === "") ? fallback : v }
    Component.onCompleted: { console.log("Font:", typeof config["Font"], "->", cfg("Font", "x"), "Accent ->", cfg("Accent", "y")); Qt.quit() }
}
