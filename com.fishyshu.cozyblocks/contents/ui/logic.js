.pragma library

// a stream counts as "other audio" if it isn't us, isn't paused, and is actually
// making noise. vesktop & friends keep silent streams open forever, so stream-exists
// alone is useless. our own QtMultimedia stream has no process.binary, only node.name.
function isOtherAudible(props, corked, peak) {
    const p = props || {};
    const who = p["application.process.binary"] || p["node.name"];
    return who !== "plasmashell" && !corked && peak > 0.002; // silent streams read exactly 0, quiet ones still count
}

// "file:///.../game_water_axolotl.ogg" -> "Axolotl"
function trackTitle(file) {
    return String(file).replace(/^.*\//, "").replace(/\.ogg$/i, "")
        .replace(/^(game|menu|creative)_/, "").replace(/^water_/, "")
        .split("_").filter(w => w).map(w => w[0].toUpperCase() + w.slice(1)).join(" ");
}

// month 0-11 -> season (northern hemisphere)
function season(month) {
    return ["winter", "winter", "spring", "spring", "spring", "summer",
            "summer", "summer", "autumn", "autumn", "autumn", "winter"][month];
}

// r in [0,1). mostly clear, otherwise whatever fits the season
function pickWeather(s, r) {
    if (r < 0.55) return "clear";
    if (s === "winter") return "snow";
    if (s === "autumn") return r < 0.8 ? "leaves" : "rain";
    if (s === "spring") return r < 0.8 ? "petals" : "rain";
    return "rain";
}

// does the middle of rect g land on the screen at (x, y, w, h)?
function centerInside(g, x, y, w, h) {
    const cx = g.x + g.width / 2, cy = g.y + g.height / 2;
    return cx >= x && cx < x + w && cy >= y && cy < y + h;
}

if (typeof module !== "undefined") module.exports = { isOtherAudible, trackTitle, season, pickWeather, centerInside };
