const assert = require("assert");
// qml's ".pragma library" isn't valid js, strip it before loading
const src = require("fs").readFileSync(__dirname + "/com.fishyshu.cozyblocks/contents/ui/logic.js", "utf8").replace(".pragma library", "");
const m = { exports: {} }; new Function("module", src)(m);
const f = m.exports.isOtherAudible;
const { trackTitle, season, pickWeather, centerInside } = m.exports;
const bin = b => ({ "application.process.binary": b });
assert.strictEqual(f(bin("plasmashell"), false, 0.8), false);          // plasmashell sounds
assert.strictEqual(f({ "node.name": "plasmashell" }, false, 0.8), false); // our own music stream
assert.strictEqual(f(bin("electron"), false, 0), false);              // vesktop idling
assert.strictEqual(f(bin("firefox"), true, 0.5), false);              // paused
assert.strictEqual(f(undefined, false, 0.5), true);                   // unknown loud stream
assert.strictEqual(f(bin("mpv"), false, 0.3), true);
assert.strictEqual(f(bin("mpv"), false, 0.001), false);              // below noise floor
assert.strictEqual(trackTitle("file:///x/minecraft/game_a_familiar_room.ogg"), "A Familiar Room");
assert.strictEqual(trackTitle("game_water_axolotl.ogg"), "Axolotl");
assert.strictEqual(trackTitle("menu_mutation.ogg"), "Mutation");
assert.strictEqual(trackTitle("game_wending.ogg"), "Wending");
assert.strictEqual(season(10), "autumn"); assert.strictEqual(season(11), "winter"); assert.strictEqual(season(6), "summer");
assert.strictEqual(pickWeather("winter", 0.1), "clear");
assert.strictEqual(pickWeather("winter", 0.9), "snow");
assert.strictEqual(pickWeather("autumn", 0.6), "leaves");
assert.strictEqual(pickWeather("autumn", 0.9), "rain");
for (const se of ["winter", "spring", "summer", "autumn"]) for (let r = 0; r < 1; r += 0.05)
    assert.ok(["clear", "rain", "snow", "leaves", "petals"].includes(pickWeather(se, r)));
const oled = [1920, 0, 2649, 1490], lcd = [0, 0, 1920, 1080];
assert.strictEqual(centerInside({ x: 1920, y: 0, width: 2649, height: 1490 }, ...oled), true);
assert.strictEqual(centerInside({ x: 1920, y: 0, width: 2649, height: 1490 }, ...lcd), false);
assert.strictEqual(centerInside({ x: 0, y: 0, width: 1920, height: 1080 }, ...oled), false);
console.log("ok");
