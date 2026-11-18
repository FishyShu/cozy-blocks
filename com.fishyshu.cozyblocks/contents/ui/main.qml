import QtQuick
import QtCore
import QtMultimedia
import Qt.labs.folderlistmodel
import org.kde.plasma.plasmoid
import org.kde.plasma.private.volume as PA
import org.kde.taskmanager as TaskManager
import "logic.js" as Logic

WallpaperItem {
    id: root

    // ───────────── clocks ─────────────
    // t = seconds since load (animation clock). walk = distance the cat walked; ground and
    // legs follow walk instead of t, so when the cat stops the world stops too
    property real t: 0
    property real walk: 0
    // 30fps is plenty for a scene this slow; an animation would redraw at 240hz on both screens.
    // advance by measured time (timers drift), capped so waking from a pause doesn't teleport the cat
    property double lastTick: 0
    Timer {
        interval: 33; repeat: true
        running: !root.screenFullscreen   // nobody can see this screen, stop burning cpu
        onRunningChanged: root.lastTick = 0
        onTriggered: {
            const now = Date.now();
            const dt = root.lastTick ? Math.min(0.1, (now - root.lastTick) / 1000) : 0.033;
            root.lastTick = now;
            root.t += dt;
            root.walk += dt * root.walkSpeed;
        }
    }

    // real wall clock drives the sky, the pixel clock and the season
    property real hourF: 12
    property string clockText: "00:00"
    property bool colonOn: true
    property string seasonName: "summer"
    Timer {
        interval: 1000; repeat: true; running: true; triggeredOnStart: true
        onTriggered: {
            const d = new Date();
            root.hourF = d.getHours() + d.getMinutes() / 60 + d.getSeconds() / 3600;
            root.clockText = Qt.formatTime(d, "HH:mm");
            root.colonOn = d.getSeconds() % 2 === 0;
            root.seasonName = Logic.season(d.getMonth());
        }
    }

    readonly property real sw: width
    readonly property real sh: height
    readonly property real bs: Math.max(16, Math.round(sh / 24))   // block size

    // sun height: +1 at noon, -1 at midnight. sunrise 06:00, sunset 18:00, close enough
    readonly property real sun: Math.sin(Math.PI * (hourF - 6) / 12)
    readonly property real dayK: clamp(sun * 2.5, 0, 1)
    readonly property real night: clamp(-sun * 2.5, 0, 1)

    function clamp(v, a, b) { return Math.max(a, Math.min(b, v)); }
    function h(i) { const x = Math.sin(i * 127.1 + 311.7) * 43758.5453; return x - Math.floor(x); }
    function mix(a, b, k) { return Qt.rgba(a.r + (b.r - a.r) * k, a.g + (b.g - a.g) * k, a.b + (b.b - a.b) * k, 1); }
    function c(s) { return Qt.color(s); }
    function sky3(dusk, day, nite) { return sun >= 0 ? mix(c(dusk), c(day), dayK) : mix(c(dusk), c(nite), night); }

    // ───────────── weather ─────────────
    property string weather: "clear"
    property real wetK: weather === "rain" ? 1 : 0   // darkens clouds
    Behavior on wetK { NumberAnimation { duration: 8000 } }
    Timer {
        interval: 90000; repeat: true; running: !root.screenFullscreen
        onTriggered: { root.weather = Logic.pickWeather(root.seasonName, Math.random()); interval = (15 + Math.random() * 20) * 60000; }
    }

    // ───────────── cat brain ─────────────
    // naps 4 of every 15 min at night, unless something's going on
    readonly property bool asleep: night > 0.6 && (t % 900) < 240 && !critterActive && !petting
    property real sleepK: asleep ? 1 : 0
    Behavior on sleepK { NumberAnimation { duration: 1500 } }

    // idle actions: sit, groom, stretch
    property string action: ""
    property real actionStart: -1000
    property real actionDur: 0
    readonly property bool acting: t - actionStart < actionDur && !asleep
    property real sitK: acting && (action === "sit" || action === "groom") ? 1 : 0
    Behavior on sitK { NumberAnimation { duration: 600 } }
    property real stretchK: acting && action === "stretch" ? 1 : 0
    Behavior on stretchK { NumberAnimation { duration: 900 } }
    property real groomK: acting && action === "groom" ? 1 : 0
    Behavior on groomK { NumberAnimation { duration: 400 } }
    Timer {
        interval: 60000; repeat: true; running: !root.screenFullscreen
        onTriggered: {
            interval = (60 + Math.random() * 90) * 1000;
            if (root.asleep || root.critterActive) return;
            root.action = ["sit", "groom", "stretch"][Math.floor(Math.random() * 3)];
            root.actionDur = { sit: 14, groom: 9, stretch: 4 }[root.action];
            root.actionStart = root.t;
        }
    }
    property real walkSpeed: asleep || acting ? 0 : 1
    Behavior on walkSpeed { NumberAnimation { duration: 1200 } }

    // critter: sky fish at night, butterfly by day. the cat drops everything to chase it.
    // first one after 45s so you actually get to see it
    property real critterStart: -1000
    property bool critterFly: false
    readonly property real critterP: (t - critterStart) / 28
    readonly property bool critterActive: critterP >= 0 && critterP <= 1
    readonly property real chase: critterActive ? Math.pow(Math.sin(Math.PI * critterP), 0.6) : 0
    Timer {
        interval: 45000; repeat: true; running: !root.screenFullscreen
        onTriggered: {
            root.critterFly = root.dayK > 0.5;
            root.critterStart = root.t;
            root.actionStart = -1000;   // forget grooming, there's a FISH
            interval = (8 + Math.random() * 12) * 60000;
        }
    }

    // shooting stars, only when it's actually night
    property real shootStart: -1000
    property real shootX: 0
    property real shootY: 0
    Timer {
        interval: 60000; repeat: true; running: !root.screenFullscreen
        onTriggered: {
            interval = (40 + Math.random() * 80) * 1000;
            if (root.night < 0.5) return;
            root.shootX = Math.random() * 0.7; root.shootY = Math.random() * 0.3; root.shootStart = root.t + 1.5; // cat spots it first
        }
    }

    readonly property bool lookUp: t - shootStart > -1.5 && t - shootStart < 1.5 && sleepK < 0.5
    property real petStart: -1000
    readonly property bool petting: t - petStart < 20   // stays awake a bit after pets
    readonly property real petP: (t - petStart) / 2.5
    property real musicHopStart: -1000
    readonly property real musicHopP: (t - musicHopStart) / 1.2

    property string toastText: ""
    property real toastStart: -1000
    function toast(s) { toastText = s; toastStart = t; }

    // 3x5 pixel font. hand-drawn, one energy drink
    readonly property var glyphs: ({
        "0": "111101101101111", "1": "010110010010111", "2": "111001111100111", "3": "111001111001111",
        "4": "101101111001001", "5": "111100111001111", "6": "111100111101111", "7": "111001010010010",
        "8": "111101111101111", "9": "111101111001111", ":": "01010"
    })

    // ───────────── sky (gradient, no edges, safe to leave unshifted) ─────────────
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: root.sky3("#3a2f5e", "#4c79ad", "#13132e") }
            GradientStop { position: 1; color: root.sky3("#9a6a86", "#93b6cf", "#2a2a5a") }
        }
    }

    // everything with edges lives in here and slowly orbits a few px: OLED pixel shift
    Item {
        id: scene
        width: root.sw + 40; height: root.sh + 40
        x: -20 + 14 * Math.sin(root.t / 190)
        y: -20 + 10 * Math.cos(root.t / 270)
        // whole pixels: it only notifies when it actually moves, not 30x a second
        readonly property real groundY: Math.round(height - 20 - 3 * root.bs - 0.25 * root.bs * (1 + Math.sin(root.t / 95)))

        // stars
        Repeater {
            model: 70
            Rectangle {
                required property int index
                width: Math.max(2, root.bs / 7); height: width
                x: root.h(index) * scene.width
                y: root.h(index + 100) * scene.height * 0.6
                color: "#f3ead0"
                opacity: (0.2 + 0.5 * (0.5 + 0.5 * Math.sin(root.t * (0.4 + root.h(index + 200) * 1.2) + index)))
                         * root.clamp(root.night + 0.25 * (1 - root.dayK), 0, 1)
            }
        }

        // pixel sun by day, moon by night, arcing across with the real clock
        Item {
            readonly property real p: ((root.hourF - 6 + 24) % 12) / 12
            readonly property bool isSun: root.hourF >= 6 && root.hourF < 18
            width: root.bs * 2; height: width
            x: p * (scene.width + 4 * root.bs) - 2 * root.bs
            y: scene.height * 0.1 + scene.height * 0.22 * Math.pow(2 * p - 1, 2)
            Rectangle { anchors.fill: parent; color: parent.isSun ? "#f0cf86" : "#d8d1b2" }
            Rectangle { visible: !parent.isSun; x: root.bs * 0.3; y: root.bs * 0.4; width: root.bs * 0.45; height: width; color: "#beb698" }
            Rectangle { visible: !parent.isSun; x: root.bs * 1.1; y: root.bs * 1.1; width: root.bs * 0.5; height: width; color: "#beb698" }
            Rectangle { visible: !parent.isSun; x: root.bs * 1.25; y: root.bs * 0.3; width: root.bs * 0.3; height: width; color: "#c7bf9f" }
            Rectangle { visible: parent.isSun; x: root.bs * 0.3; y: root.bs * 0.3; width: root.bs * 1.4; height: width; color: "#f6dea0" }
        }

        // pixel clock, wanders around the top of the sky (never parks, OLED)
        Row {
            id: clockRow
            readonly property real c: Math.max(4, Math.round(root.bs * 0.28))
            spacing: c
            x: scene.width * (0.5 + 0.3 * Math.sin(root.t / 517)) - width / 2
            y: scene.height * (0.07 + 0.05 * Math.sin(root.t / 389))
            opacity: 0.45
            Repeater {
                model: root.clockText.split("")
                Grid {
                    required property string modelData
                    columns: modelData === ":" ? 1 : 3
                    opacity: modelData === ":" && !root.colonOn ? 0.3 : 1
                    Repeater {
                        model: (root.glyphs[parent.modelData] || "").split("")
                        Rectangle {
                            required property string modelData
                            width: clockRow.c; height: width
                            color: "#efe6ff"; opacity: modelData === "1" ? 1 : 0
                        }
                    }
                }
            }
        }

        // blocky clouds, whiter by day, grey and heavier in the rain
        Repeater {
            model: 7
            Item {
                required property int index
                readonly property real s: 0.6 + 0.7 * root.h(index + 500)
                readonly property real speed: root.bs * (0.12 + 0.25 * root.h(index + 300))
                readonly property real span: scene.width + 10 * root.bs
                readonly property color col: root.mix(root.c("#fff3fb"), root.c("#8a8ea6"), root.wetK)
                x: ((root.t * speed + root.h(index + 400) * span) % span) - 7 * root.bs
                y: scene.height * (0.08 + 0.38 * root.h(index + 600))
                opacity: 0.10 + 0.10 * root.h(index + 700) + 0.35 * root.dayK + 0.3 * root.wetK
                Rectangle { y: root.bs * s; width: 6 * root.bs * s; height: root.bs * s; color: parent.col }
                Rectangle { x: root.bs * s; width: 3 * root.bs * s; height: root.bs * s; color: parent.col }
            }
        }

        // shooting star: a little pixel streak
        Repeater {
            model: 6
            Rectangle {
                required property int index
                readonly property real p: (root.t - root.shootStart) / 1.2
                visible: p >= 0 && p <= 1
                width: Math.max(3, root.bs / 6); height: width
                x: scene.width * root.shootX + (p * 14 - index * 0.6) * root.bs
                y: scene.height * root.shootY + (p * 14 - index * 0.6) * root.bs * 0.45
                color: "#fff6dc"
                opacity: (1 - index / 6) * (1 - p) * 0.9
            }
        }

        // far hills, scrolling slowly. heights are periodic over N columns so the loop is seamless
        Item {
            id: far
            readonly property int n: Math.ceil(scene.width / root.bs) + 1
            readonly property real off: (root.walk * root.bs * 0.2) % (n * root.bs)
            readonly property color fill: root.mix(root.c("#2b3b57"), root.c("#56788e"), root.dayK)
            readonly property color cap: root.seasonName === "winter" ? root.mix(root.c("#7d8aa3"), root.c("#c9d3df"), root.dayK)
                                                                      : root.mix(root.c("#3a5172"), root.c("#6a8ea0"), root.dayK)
            anchors.fill: parent
            Repeater {
                model: far.n * 2
                Rectangle {
                    required property int index
                    readonly property int j: index % far.n
                    readonly property int blocks: Math.round(5 + 1.6 * Math.sin(2 * Math.PI * 2 * j / far.n)
                                                             + 1.2 * Math.sin(2 * Math.PI * 5 * j / far.n + 1))
                    x: index * root.bs - far.off
                    width: root.bs + 1
                    height: blocks * root.bs
                    y: scene.groundY + root.bs - height
                    color: far.fill
                    Rectangle { width: parent.width; height: root.bs * 0.35; color: far.cap }
                }
            }
        }

        // near ground: grass + dirt tiles with flowers, scrolls faster (parallax). grass follows the season
        Item {
            id: near
            readonly property int n: Math.ceil(scene.width / root.bs) + 1
            readonly property real off: (root.walk * root.bs * 0.7) % (n * root.bs)
            readonly property var grass: ({ winter: ["#c3ccd8", "#b9c3d0"], spring: ["#55a060", "#4f985a"],
                                            summer: ["#4f8f5a", "#4a8755"], autumn: ["#7f8a45", "#78823f"] })[root.seasonName]
            readonly property real flowerCut: root.seasonName === "spring" ? 0.6 : root.seasonName === "winter" ? 0.95 : 0.78
            anchors.fill: parent
            Rectangle { // slow ±4% brightness drift, OLED again
                z: 1; y: scene.groundY; width: parent.width; height: parent.height - y
                color: "black"; opacity: 0.04 * (1 + Math.sin(root.t / 137))
            }
            Repeater {
                model: near.n * 2
                Item {
                    required property int index
                    readonly property int j: index % near.n
                    x: index * root.bs - near.off
                    y: scene.groundY
                    width: root.bs + 1; height: scene.height - y
                    Rectangle { anchors.fill: parent; color: j % 2 ? "#4f3b2e" : "#4a372b" }
                    Rectangle { width: parent.width; height: root.bs * 0.4; color: near.grass[j % 2] }
                    Rectangle { // dirt speckle
                        x: root.bs * root.h(j + 900) * 0.7; y: root.bs * (0.8 + root.h(j + 950) * 1.6)
                        width: root.bs * 0.2; height: width; color: "#3c2d23"
                    }
                    Item { // flower on some tiles, bows when the cat brushes past
                        visible: root.h(j + 800) > near.flowerCut
                        x: root.bs * 0.4; y: -root.bs * 0.5
                        width: root.bs * 0.2; height: root.bs * 0.5
                        transformOrigin: Item.Bottom
                        // short-circuit: hidden flowers never read cat.x, so they don't re-evaluate every frame
                        rotation: !visible ? 0 : 28 * Math.max(0, 1 - Math.abs(parent.x + root.bs * 0.5 - cat.x - cat.width * 0.45) / (root.bs * 1.6))
                        Rectangle { x: root.bs * 0.06; y: root.bs * 0.15; width: root.bs * 0.08; height: root.bs * 0.35; color: "#3f7a4a" }
                        Rectangle {
                            width: root.bs * 0.2; height: width
                            color: root.seasonName === "autumn" ? (root.h(j + 850) > 0.5 ? "#d9823b" : "#c4532f")
                                                                : (root.h(j + 850) > 0.5 ? "#d98aa5" : "#d9c27a")
                        }
                    }
                }
            }
        }

        // fireflies at night
        Repeater {
            model: 14
            Rectangle {
                required property int index
                width: Math.max(3, root.bs / 8); height: width
                x: root.h(index + 1000) * scene.width + root.bs * 2 * Math.sin(root.t * 0.23 + index)
                y: scene.groundY - root.bs * (0.4 + 2.6 * root.h(index + 1100)) + root.bs * 0.6 * Math.sin(root.t * 0.41 + index * 2)
                color: "#e6f59a"
                opacity: root.clamp((root.night - 0.55) * 3, 0, 1) * Math.pow(0.5 + 0.5 * Math.sin(root.t * 1.7 + index * 3), 3)
            }
        }

        // critter: fish (night) or butterfly (day). yes the fish swims in the sky, physics is optional
        Item {
            id: critter
            readonly property real u: root.bs / 3
            visible: root.critterActive
            width: 6 * u; height: 3 * u
            x: root.critterP * (scene.width + 12 * u) - 6 * u
            y: root.critterFly ? scene.groundY - 2.6 * root.bs + Math.sin(root.critterP * 25) * root.bs * 0.8
                               : scene.groundY - 5 * root.bs + Math.sin(root.critterP * 40) * u
            Item {
                visible: !root.critterFly
                Rectangle { x: 0; y: 0.5 * critter.u; width: critter.u; height: 2 * critter.u; color: "#4a97b0"
                            transformOrigin: Item.Right; rotation: 15 * Math.sin(root.t * 9) }
                Rectangle { x: critter.u; y: 0.6 * critter.u; width: 0.6 * critter.u; height: 1.8 * critter.u; color: "#4a97b0" }
                Rectangle { x: 1.6 * critter.u; width: 3.6 * critter.u; height: 3 * critter.u; color: "#6cbcd1" }
                Rectangle { x: 2.4 * critter.u; y: -0.4 * critter.u; width: 1.6 * critter.u; height: 0.5 * critter.u; color: "#4a97b0" }
                Rectangle { x: 4.2 * critter.u; y: 0.8 * critter.u; width: 0.55 * critter.u; height: width; color: "#1e2a38" }
                Rectangle { x: 2.6 * critter.u; y: 1.9 * critter.u; width: 1.4 * critter.u; height: 0.4 * critter.u; color: "#9ad6e4" }
            }
            Item {
                visible: root.critterFly
                readonly property real flap: Math.abs(Math.sin(root.t * 12))
                Rectangle { x: 1.3 * critter.u; y: (1.5 - 1.3 * parent.flap) * critter.u; width: 1.3 * critter.u; height: 1.3 * critter.u * parent.flap + 1; color: "#e79ac0" }
                Rectangle { x: 3.0 * critter.u; y: (1.5 - 1.3 * parent.flap) * critter.u; width: 1.3 * critter.u; height: 1.3 * critter.u * parent.flap + 1; color: "#e79ac0" }
                Rectangle { x: 1.5 * critter.u; y: 1.5 * critter.u; width: 1 * critter.u; height: 0.8 * critter.u; color: "#d9c27a" }
                Rectangle { x: 3.1 * critter.u; y: 1.5 * critter.u; width: 1 * critter.u; height: 0.8 * critter.u; color: "#d9c27a" }
                Rectangle { x: 2.6 * critter.u; y: 0.8 * critter.u; width: 0.4 * critter.u; height: 1.8 * critter.u; color: "#3a2a3a" }
            }
        }

        // the cat. walks in place while the ground scrolls, wanders across the screen
        Item {
            id: cat
            readonly property real u: root.bs / 3
            readonly property real step: Math.sin(root.walk * 7)
            readonly property real walkK: Math.max(0, 1 - root.sitK - root.sleepK)
            readonly property real hop: (root.petP >= 0 && root.petP <= 1 ? Math.sin(Math.PI * root.petP) * 2.5 : 0)
                                        + (root.musicHopP >= 0 && root.musicHopP <= 1 ? Math.sin(Math.PI * root.musicHopP) * 1.2 : 0)
                                        + Math.pow(root.chase, 4) * Math.abs(Math.sin(root.t * 6)) * 1.5
            readonly property real wanderX: scene.width * (0.5 + 0.33 * Math.sin(root.walk / 83)) - width / 2
            width: 10 * u; height: 7 * u
            x: wanderX + (critter.x - width * 0.6 - wanderX) * root.chase * 0.85
            y: scene.groundY - height - (Math.abs(step) * 0.25 * walkK + hop) * u
            transformOrigin: Item.BottomLeft
            rotation: 7 * root.stretchK   // butt up, chest down. a proper stretch

            // walking body
            Item {
                anchors.fill: parent
                opacity: cat.walkK
                Rectangle {
                    x: 0.3 * cat.u; y: 0.6 * cat.u; width: cat.u; height: 3 * cat.u; color: "#d98c4f"
                    transformOrigin: Item.Bottom; rotation: -20 + 18 * Math.sin(root.t * 2.2) * (1 - root.chase) + 25 * Math.sin(root.t * 11) * root.chase
                }
                Repeater {
                    model: 4
                    Rectangle {
                        required property int index
                        x: (1.3 + index * 1.4 + (index > 1 ? 0.6 : 0)) * cat.u
                        y: 6 * cat.u
                        width: cat.u * 0.9
                        height: cat.u * (index % 2 ? 0.6 + 0.4 * Math.max(0, cat.step) : 0.6 + 0.4 * Math.max(0, -cat.step))
                        color: "#c27a42"
                    }
                }
                Rectangle { x: cat.u; y: 3 * cat.u; width: 6 * cat.u; height: 3 * cat.u; color: "#d98c4f" }
                Rectangle { x: 2.6 * cat.u; y: 3 * cat.u; width: 0.8 * cat.u; height: 1.2 * cat.u; color: "#b8703c" }
                Rectangle { x: 4.4 * cat.u; y: 3 * cat.u; width: 0.8 * cat.u; height: 1.2 * cat.u; color: "#b8703c" }
            }

            // sitting body
            Item {
                anchors.fill: parent
                opacity: root.sitK
                visible: opacity > 0
                Rectangle { x: 0.6 * cat.u; y: 6.2 * cat.u; width: 2.6 * cat.u; height: 0.8 * cat.u; color: "#c27a42" }
                Rectangle { x: 0.6 * cat.u; y: (5.4 - 0.3 * Math.max(0, Math.sin(root.t * 2))) * cat.u; width: 0.8 * cat.u; height: 0.8 * cat.u; color: "#c27a42" }
                Rectangle { x: 2.4 * cat.u; y: 2.8 * cat.u; width: 4.4 * cat.u; height: 4.2 * cat.u; color: "#d98c4f" }
                Rectangle { x: 2.4 * cat.u; y: 3.6 * cat.u; width: 1.4 * cat.u; height: 0.7 * cat.u; color: "#b8703c" }
                Rectangle { x: 2.4 * cat.u; y: 4.8 * cat.u; width: 1.4 * cat.u; height: 0.7 * cat.u; color: "#b8703c" }
                Rectangle { x: 5.2 * cat.u; y: 5.2 * cat.u; width: 0.8 * cat.u; height: 1.8 * cat.u; color: "#c27a42" }
                Rectangle { x: 6.0 * cat.u; y: 5.2 * cat.u; width: 0.8 * cat.u; height: 1.8 * cat.u; color: "#c27a42" }
            }

            // curled-up loaf, breathing
            Item {
                anchors.fill: parent
                opacity: root.sleepK
                visible: opacity > 0
                transform: Scale { origin.y: 7 * cat.u; yScale: 1 + 0.05 * Math.sin(root.t * 1.6) }
                Rectangle { x: 0.5 * cat.u; y: 6.2 * cat.u; width: 6 * cat.u; height: 0.8 * cat.u; color: "#c27a42" }
                Rectangle { x: cat.u; y: 3.6 * cat.u; width: 6 * cat.u; height: 3 * cat.u; color: "#d98c4f" }
                Rectangle { x: 2.6 * cat.u; y: 3.6 * cat.u; width: 0.8 * cat.u; height: 1.2 * cat.u; color: "#b8703c" }
                Rectangle { x: 4.4 * cat.u; y: 3.6 * cat.u; width: 0.8 * cat.u; height: 1.2 * cat.u; color: "#b8703c" }
                Repeater {
                    model: 3
                    Text {
                        required property int index
                        readonly property real p: ((root.t / 3) + index / 3) % 1
                        text: "z"; color: "#cfc6ff"
                        font.family: "monospace"; font.bold: true; font.pixelSize: cat.u * (1.2 + index * 0.4)
                        x: 9 * cat.u + p * 2 * cat.u; y: 2 * cat.u - p * 4 * cat.u
                        opacity: Math.sin(Math.PI * p) * 0.8
                    }
                }
            }

            // one head, slides between poses
            Item {
                x: (6 * cat.walkK + 4.6 * root.sitK + 5.6 * root.sleepK) * cat.u
                y: (1.2 * cat.walkK + 0.4 * root.sitK + 3.6 * root.sleepK) * cat.u
                width: 4 * cat.u; height: 3.4 * cat.u
                rotation: -12 * root.groomK
                Rectangle { y: -cat.u; width: cat.u; height: cat.u; color: "#d98c4f" }
                Rectangle { x: 3 * cat.u; y: -cat.u; width: cat.u; height: cat.u; color: "#d98c4f" }
                Rectangle { width: 4 * cat.u; height: 3.4 * cat.u; color: "#e09a5c" }
                // eyes: blink every ~7s, shut while napping or grooming. the blink math took longer than the cat
                Repeater {
                    model: 2
                    Rectangle {
                        required property int index
                        readonly property bool shut: root.sleepK > 0.5 || root.groomK > 0.5 || Math.sin(root.t * 0.9) > 0.985
                                                    || Math.sin(root.t * 0.13) > 0.995   // the slow blink. cat for "i love you"
                        x: (0.8 + index * 1.7) * cat.u
                        y: (shut ? 1.45 : 1.1 - (root.lookUp ? 0.35 : 0)) * cat.u
                        width: 0.7 * cat.u; height: (shut ? 0.15 : 0.75) * cat.u
                        color: "#2b2033"
                    }
                }
                Rectangle { x: 1.75 * cat.u; y: 2.2 * cat.u; width: 0.5 * cat.u; height: 0.35 * cat.u; color: "#d97a8a" }
                Rectangle { x: 0.2 * cat.u; y: 2.3 * cat.u; width: 0.6 * cat.u; height: 0.4 * cat.u; color: "#e8909c"; opacity: 0.6 }
                Rectangle { x: 3.2 * cat.u; y: 2.3 * cat.u; width: 0.6 * cat.u; height: 0.4 * cat.u; color: "#e8909c"; opacity: 0.6 }
            }
            // grooming paw
            Rectangle {
                opacity: root.groomK
                x: 6.3 * cat.u; y: (4.4 - (0.5 + 0.5 * Math.sin(root.t * 5)) * 1.4) * cat.u
                width: 0.9 * cat.u; height: 1.3 * cat.u; color: "#e09a5c"
            }

            // pet heart
            Grid {
                columns: 5
                visible: root.petP >= 0 && root.petP <= 1
                x: 6.5 * cat.u; y: -1.5 * cat.u - root.petP * 3 * cat.u
                opacity: 1 - root.petP
                Repeater {
                    model: "0101011111111110111000100".split("")
                    Rectangle {
                        required property string modelData
                        width: cat.u * 0.45; height: width
                        color: "#e86f8c"; opacity: modelData === "1" ? 1 : 0
                    }
                }
            }
        }

        // now-playing bubble over the cat
        Item {
            readonly property real p: (root.t - root.toastStart) / 7
            visible: p >= 0 && p <= 1
            opacity: Math.min(1, p * 8, (1 - p) * 5)
            width: label.implicitWidth + root.bs * 0.8; height: label.implicitHeight + root.bs * 0.4
            x: root.clamp(cat.x + cat.width / 2 - width / 2, root.bs, scene.width - width - root.bs)
            y: cat.y - height - root.bs * 0.8
            Rectangle { anchors.fill: parent; color: "#1c1830"; opacity: 0.75; border.color: "#cfc6ff"; border.width: Math.max(2, root.bs / 20) }
            Text {
                id: label
                anchors.centerIn: parent
                text: root.toastText; color: "#efe6ff"
                font.family: "monospace"; font.bold: true; font.pixelSize: root.bs * 0.38
            }
        }

        // weather particles. one Repeater, the look depends on the weather
        Item {
            id: wx
            anchors.fill: parent
            opacity: root.weather === "clear" ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: 6000 } }
            visible: opacity > 0
            // keep drawing the old kind while it fades out
            property string kind: "rain"
            Connections { target: root; function onWeatherChanged() { if (root.weather !== "clear") wx.kind = root.weather; } }
            Repeater {
                model: wx.visible ? 90 : 0
                Rectangle {
                    required property int index
                    readonly property string k: wx.kind
                    readonly property bool rain: k === "rain"
                    readonly property real speed: root.bs * (rain ? 14 : k === "snow" ? 1.2 : 1.0) * (0.8 + 0.4 * root.h(index + 1200))
                    readonly property real span: scene.height + 2 * root.bs
                    readonly property real fy: ((root.t * speed + root.h(index + 1300) * span) % span) - root.bs
                    readonly property real sway: rain ? 0 : root.bs * (k === "snow" ? 0.6 : 1.5) * Math.sin(root.t * 0.8 + index)
                    x: root.h(index + 1400) * scene.width + sway - (rain ? fy * 0.12 : 0)
                    y: fy
                    width: rain ? Math.max(2, root.bs / 14) : root.bs / (k === "snow" ? 7 : 5)
                    height: rain ? root.bs * 0.5 : width
                    rotation: rain ? 7 : (k === "snow" ? 0 : 40 * Math.sin(root.t * 1.3 + index))
                    color: rain ? "#9fb4d6" : k === "snow" ? "#eef2f8"
                         : k === "petals" ? "#e8a6c0" : (index % 2 ? "#d9823b" : "#c4532f")
                    opacity: rain ? 0.35 : 0.75
                }
            }
            Repeater { // splashes
                model: wx.visible && wx.kind === "rain" ? 14 : 0
                Item {
                    required property int index
                    readonly property real p: (root.t * (0.9 + 0.5 * root.h(index + 1500)) + root.h(index + 1600)) % 1
                    x: root.h(index + 1700 + Math.floor(root.t / 3)) * scene.width
                    y: scene.groundY
                    visible: p < 0.35
                    opacity: 0.5 * (1 - p / 0.35)
                    Rectangle { x: -root.bs * 0.25 * parent.p / 0.35; y: -root.bs * 0.25 * Math.sin(Math.PI * parent.p / 0.35); width: Math.max(2, root.bs / 12); height: width; color: "#b9c9e6" }
                    Rectangle { x: root.bs * 0.25 * parent.p / 0.35; y: -root.bs * 0.25 * Math.sin(Math.PI * parent.p / 0.35); width: Math.max(2, root.bs / 12); height: width; color: "#b9c9e6" }
                }
            }
        }
    }

    // ───────────── hotkeys: `cozy next|mute|pet` drops a file in ~/.cache/cozyblocks ─────────────
    // a dir watch is the cheapest IPC a wallpaper gets
    FolderListModel {
        id: cmds
        folder: StandardPaths.writableLocation(StandardPaths.GenericCacheLocation) + "/cozyblocks"
        showDirs: false
    }
    property var seenCmds: ({})
    property bool cmdsPrimed: false
    Timer {
        interval: 400; repeat: true; running: true
        onTriggered: {
            if (cmds.status !== FolderListModel.Ready) return;
            const present = {};
            for (let i = 0; i < cmds.count; i++) {
                const n = cmds.get(i, "fileName");
                present[n] = true;
                if (!root.seenCmds[n] && root.cmdsPrimed) root.runCmd(n.split(".")[0]);   // files from before we loaded are stale
            }
            root.seenCmds = present;   // the script deletes old files, so this stays tiny
            root.cmdsPrimed = true;
        }
    }
    function runCmd(c) {
        if (c === "pet") { petStart = t; return; }
        if (["clear", "rain", "snow", "leaves", "petals"].includes(c)) { weather = c; return; }
        if (!musicOn) return;   // music commands only on the music screen
        if (c === "mute") { userMuted = !userMuted; toast(userMuted ? "♪ muted" : "♪ unmuted"); }
        else if (c === "next") { gap.stop(); nextTrack(); if (!shouldPlay) toast("♪ queued: " + Logic.trackTitle(player.source)); }
    }

    // ───────────── music ─────────────
    readonly property bool musicOn: root.configuration.Music === true
    property bool userMuted: false
    property bool anyFullscreen: false      // any screen: pauses music
    property bool screenFullscreen: false   // this screen: pauses animation. a video on the LCD mustn't freeze the OLED
    property bool otherAudio: false
    readonly property bool shouldPlay: musicOn && !userMuted && !anyFullscreen && !otherAudio && tracks.count > 0

    // fullscreen anywhere (any screen) pauses music + animation
    TaskManager.TasksModel {
        id: tasks
        groupMode: TaskManager.TasksModel.GroupDisabled
        filterByActivity: true
        onDataChanged: root.checkFullscreen()
        onCountChanged: root.checkFullscreen()
    }
    function checkFullscreen() {
        let fs = false, mine = false;
        for (let i = 0; i < tasks.count; i++) {
            const idx = tasks.index(i, 0);
            if (!tasks.data(idx, TaskManager.AbstractTasksModel.IsFullScreen)
                || tasks.data(idx, TaskManager.AbstractTasksModel.IsMinimized)) continue;
            fs = true;
            const g = tasks.data(idx, TaskManager.AbstractTasksModel.ScreenGeometry);
            if (g && Logic.centerInside(g, Screen.virtualX, Screen.virtualY, Screen.width, Screen.height)) mine = true;
        }
        anyFullscreen = fs;
        screenFullscreen = mine;
    }

    // per-stream peak meters (same thing the volume applet uses for its level bars)
    Instantiator {
        id: streams
        active: root.musicOn
        model: PA.SinkInputModel {}
        // wrapper so the monitor can attach a beat late: new streams aren't wired to a
        // sink yet when they show up, and a monitor attached that early stays dead
        delegate: QtObject {
            id: s
            required property var model
            readonly property var obj: model.PulseObject
            property bool ready: false
            readonly property bool audible: Logic.isOtherAudible(obj ? obj.properties : null, obj ? obj.corked : true, mon.volume)
            onAudibleChanged: if (audible) root.lastHeard = Date.now()
            property PA.VolumeMonitor mon: PA.VolumeMonitor { target: ready ? obj : null }
            property Timer arm: Timer { interval: 1500; running: true; onTriggered: s.ready = true }
        }
    }
    property double lastHeard: 0
    Timer {
        interval: 500; repeat: true; running: root.musicOn
        onTriggered: {
            for (let i = 0; i < streams.count; i++) {
                const o = streams.objectAt(i);
                if (o && o.audible) root.lastHeard = Date.now();
            }
            // hold 4s so pauses in a video/voice don't make minecraft pop back in
            root.otherAudio = Date.now() - root.lastHeard < 4000;
        }
    }

    FolderListModel {
        id: tracks
        folder: StandardPaths.writableLocation(StandardPaths.MusicLocation) + "/minecraft"
        nameFilters: ["*.ogg"] // nether/end tracks live in spooky/, too spooky for a cat
        showDirs: false
    }

    property int lastIdx: -1
    function nextTrack() {
        if (tracks.count === 0) return;
        let i;
        do { i = Math.floor(Math.random() * tracks.count); } while (tracks.count > 1 && i === lastIdx);
        lastIdx = i;
        player.source = tracks.get(i, "fileUrl");
        if (shouldPlay) player.play();
    }

    property string announced: ""
    MediaPlayer {
        id: player
        // cubic curve like pulseaudio, so 50 actually sounds like half
        audioOutput: AudioOutput { volume: root.level * Math.pow(root.configuration.Volume / 100, 3) }
        onMediaStatusChanged: {
            if (mediaStatus === MediaPlayer.EndOfMedia || mediaStatus === MediaPlayer.InvalidMedia) {
                gap.interval = 20000 + Math.random() * 40000; // minecraft-style silence between songs
                gap.restart();
            }
        }
        onPlaybackStateChanged: {
            // new song actually audible -> bubble + a happy hop. resumes don't count
            if (playbackState === MediaPlayer.PlayingState && source.toString() !== root.announced) {
                root.announced = source.toString();
                root.toast("♪ " + Logic.trackTitle(source));
                root.musicHopStart = root.t;
            }
        }
    }
    Timer { id: gap; onTriggered: root.nextTrack() }

    // fade instead of hard cut
    property real level: shouldPlay ? 1 : 0
    Behavior on level { NumberAnimation { duration: 2500 } }
    onLevelChanged: if (level === 0) player.pause()
    onShouldPlayChanged: {
        if (!shouldPlay || gap.running) return;
        if (player.source.toString() === "") nextTrack(); else player.play();
    }

    Component.onCompleted: checkFullscreen()
}
