import QtQuick
import org.kde.plasma.plasmoid

WallpaperItem {
    id: root

    // ───────────── clock ─────────────
    property real t: 0
    property real last: Date.now()
    Timer {
        interval: 33; repeat: true; running: true
        onTriggered: {
            const n = Date.now();
            root.t += Math.min(0.1, (n - root.last) / 1000);   // lag spikes must not teleport the koi
            root.last = n;
        }
    }

    function h(i) { const x = Math.sin(i * 127.1 + 311.7) * 43758.5453; return x - Math.floor(x); }
    function mix(a, b, k) { return Qt.rgba(a.r + (b.r - a.r) * k, a.g + (b.g - a.g) * k, a.b + (b.b - a.b) * k, 1); }
    function snap(v) { return Math.round(v / px) * px; }

    readonly property real px: Math.max(4, Math.round(height / 150))   // one "pixel"
    readonly property real sw: scene.width
    readonly property real sh: scene.height

    // ───────────── koi ─────────────
    // each koi: Lissajous centre-path, colours, and a follow-lag so the body trails the head
    readonly property var koiList: {
        const W = sw, H = sh;
        return [
            { ax: W * 0.36, ay: H * 0.30, fx: 0.052, fy: 0.071, p1: 0.0, p2: 1.0, base: "#c4c4bb", patch: "#d4601f" },
            { ax: W * 0.30, ay: H * 0.34, fx: 0.064, fy: 0.047, p1: 2.1, p2: 0.3, base: "#d4601f", patch: "#c4c4bb" },
            { ax: W * 0.40, ay: H * 0.26, fx: 0.043, fy: 0.058, p1: 4.0, p2: 2.2, base: "#17171c", patch: "#cfcfc4" },
            { ax: W * 0.26, ay: H * 0.36, fx: 0.071, fy: 0.039, p1: 5.2, p2: 4.4, base: "#cfcfc4", patch: "#17171c" },
            { ax: W * 0.34, ay: H * 0.22, fx: 0.057, fy: 0.066, p1: 1.3, p2: 5.1, base: "#c8741f", patch: "#bdbdb2" }
        ];
    }
    readonly property var segSize: [5, 6, 6, 5, 4, 3, 3, 2, 2]   // in px; head first, tail last

    function pos(k, tt) {
        const s = koiList[k];
        return Qt.point(sw / 2 + s.ax * Math.sin(s.fx * tt + s.p1), sh / 2 + s.ay * Math.sin(s.fy * tt + s.p2));
    }
    // i < 9: body segment; 9/10: pectoral fins. Returns x, y, size (centre-based)
    function seg(k, i, tt) {
        const s = koiList[k];
        const lag = 0.42 + 0.03 * k;
        const j = Math.min(i, 9) === 9 ? 2 : i;
        const q = tt - j * lag;
        const a = pos(k, q), b = pos(k, q + 0.2);
        let dx = b.x - a.x, dy = b.y - a.y;
        const l = Math.max(0.001, Math.hypot(dx, dy));
        const nx = -dy / l, ny = dx / l;
        const wig = Math.sin(tt * 2.0 - j * 0.8) * px * 0.2 * j * (j > 4 ? 1.4 : 0.6);
        let off = wig, size = segSize[j] * px;
        if (i >= 9) { off = (i === 9 ? 1 : -1) * (size * 0.5 + px * 0.8) + wig; size = px * 2; }
        return { x: a.x + nx * off, y: a.y + ny * off, s: size };
    }

    // ───────────── ripples ─────────────
    // 4 slots; the next koi to "surface" takes the next slot
    property var rips: [{ x: 0, y: 0, t0: -100 }, { x: 0, y: 0, t0: -100 }, { x: 0, y: 0, t0: -100 }, { x: 0, y: 0, t0: -100 }]
    property int ripN: 0
    Timer {
        interval: 5200; repeat: true; running: true
        onTriggered: {
            const k = root.ripN % root.koiList.length;
            const p = root.pos(k, root.t);
            const r = root.rips.slice();
            r[root.ripN % 4] = { x: p.x, y: p.y, t0: root.t };
            root.rips = r;
            root.ripN++;
            interval = 4000 + Math.random() * 5000;   // koi don't have deadlines
        }
    }

    // ───────────── scene ─────────────
    Rectangle { anchors.fill: parent; color: "#050d10" }

    Item {
        id: scene
        width: root.width + 40
        height: root.height + 40
        // slow orbit = burn-in insurance: the whole pond shifts ~18px over 10 minutes
        x: -20 + 18 * Math.cos(root.t * 2 * Math.PI / 600)
        y: -20 + 18 * Math.sin(root.t * 2 * Math.PI / 600)

        // water
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#0a2a30" }
                GradientStop { position: 1.0; color: "#06181e" }
            }
        }

        // caustic patches: lighter blocks drifting sideways
        Repeater {
            model: 12
            delegate: Item {
                required property int index
                readonly property real w: (7 + root.h(index) * 12) * root.px
                readonly property real hh: (2 + root.h(index + 40) * 3) * root.px
                readonly property real span: root.sw + w
                x: root.snap(((root.h(index + 80) * span + root.t * (1.5 + root.h(index + 120) * 2.5) * root.px) % span) - w)
                y: root.snap(root.h(index + 160) * root.sh + Math.sin(root.t * 0.2 + index) * root.px * 3)
                opacity: 0.05 + 0.04 * Math.sin(root.t * 0.35 + index * 2)
                Rectangle { width: parent.w; height: parent.hh; color: "#4fb0a8" }
                Rectangle { x: parent.w * 0.3; y: parent.hh; width: parent.w * 0.4; height: root.px; color: "#4fb0a8" }
            }
        }

        // moon reflection: pixel disc, each row wobbling on its own
        Item {
            id: moon
            x: root.sw * (0.5 + 0.28 * Math.sin(root.t / 211)) + Math.sin(root.t * 0.37) * root.px
            y: root.sh * (0.42 + 0.14 * Math.sin(root.t / 157 + 1))
            readonly property var rows: [4, 8, 10, 12, 12, 12, 10, 8, 4]
            Repeater {
                model: 9
                delegate: Rectangle {
                    required property int index
                    readonly property real rw: moon.rows[index] * root.px
                    width: rw; height: root.px + 1
                    x: root.snap(-rw / 2 + Math.sin(root.t * 1.1 + index * 0.9) * root.px * 1.2)
                    y: (index - 4.5) * root.px
                    color: "#c9dce0"
                    opacity: 0.22 + 0.05 * Math.sin(root.t * 0.8 + index)
                }
            }
            Repeater {
                model: 5   // little glints around it
                delegate: Rectangle {
                    required property int index
                    width: root.px; height: root.px
                    x: root.snap(Math.cos(index * 1.9 + root.t * 0.15) * root.px * 11)
                    y: root.snap(Math.sin(index * 2.7 + root.t * 0.12) * root.px * 8)
                    color: "#c9dce0"
                    opacity: Math.max(0, Math.sin(root.t * 0.7 + index * 1.7)) * 0.25
                }
            }
        }

        // koi (under the pads, because pads float)
        Repeater {
            model: root.koiList.length
            delegate: Item {
                id: koi
                required property int index
                Repeater {
                    model: 11
                    delegate: Rectangle {
                        required property int index
                        readonly property var g: root.seg(koi.index, index, root.t)
                        readonly property bool fin: index >= 9
                        width: g.s; height: g.s
                        x: root.snap(g.x - g.s / 2); y: root.snap(g.y - g.s / 2)
                        z: fin ? -1 : 10 - index
                        opacity: fin ? 0.7 : 1
                        color: (!fin && root.h(koi.index * 13 + index) > 0.55 || index === 4 && koi.index % 2 === 0)
                               ? root.koiList[koi.index].patch : root.koiList[koi.index].base
                    }
                }
            }
        }

        // ripples: hollow squares that grow and fade
        Repeater {
            model: 4
            delegate: Rectangle {
                required property int index
                readonly property var r: root.rips[index]
                readonly property real age: root.t - r.t0
                readonly property real sz: root.snap(root.px * (2 + age * 3.2))
                visible: age >= 0 && age < 7
                width: sz; height: sz
                x: root.snap(r.x - sz / 2); y: root.snap(r.y - sz / 2)
                color: "transparent"
                border.width: root.px / 2
                border.color: "#9fd0cc"
                opacity: Math.max(0, 0.35 * (1 - age / 7))
            }
        }

        // lily pads (+ two lotus)
        Repeater {
            model: 6
            delegate: Item {
                id: pad
                required property int index
                readonly property real u: root.px
                x: root.snap(root.sw * (0.1 + 0.8 * root.h(index + 300)) + Math.sin(root.t * 0.05 + index * 2) * u * 9)
                y: root.snap(root.sh * (0.1 + 0.8 * root.h(index + 330)) + Math.cos(root.t * 0.04 + index) * u * 6 + Math.sin(root.t * 0.6 + index) * u * 0.6)
                Rectangle { x: -4 * pad.u; y: -3 * pad.u; width: 8 * pad.u; height: 6 * pad.u; color: "#1d4a2c" }
                Rectangle { x: -3 * pad.u; y: -4 * pad.u; width: 6 * pad.u; height: 8 * pad.u; color: "#1d4a2c" }
                Rectangle { x: -2 * pad.u; y: -2 * pad.u; width: 4 * pad.u; height: 4 * pad.u; color: "#2b6a3c"; opacity: 0.8 }
                Rectangle { x: 0; y: -0.5 * pad.u; width: 4 * pad.u; height: pad.u; color: "#07191e" }   // the notch
                Item {   // lotus on two of the pads
                    visible: pad.index === 1 || pad.index === 4
                    Rectangle { x: -2.5 * pad.u; y: -pad.u; width: 5 * pad.u; height: 2 * pad.u; color: "#b5527f" }
                    Rectangle { x: -pad.u; y: -2.5 * pad.u; width: 2 * pad.u; height: 5 * pad.u; color: "#b5527f" }
                    Rectangle { x: -1.5 * pad.u; y: -1.5 * pad.u; width: 3 * pad.u; height: 3 * pad.u; color: "#d98aae" }
                    Rectangle { x: -0.5 * pad.u; y: -0.5 * pad.u; width: pad.u; height: pad.u; color: "#d9b24a" }
                }
            }
        }

        // fireflies
        Repeater {
            model: 8
            delegate: Item {
                required property int index
                readonly property real blink: Math.pow(Math.max(0, Math.sin(root.t * (0.5 + root.h(index + 500) * 0.5) + index * 3)), 3)
                x: root.snap(root.sw * (0.5 + 0.42 * Math.sin(root.t * (0.03 + root.h(index + 520) * 0.03) + index)))
                y: root.snap(root.sh * (0.5 + 0.40 * Math.sin(root.t * (0.025 + root.h(index + 540) * 0.03) + index * 2.3)))
                Rectangle { x: -root.px; y: -root.px; width: root.px * 3; height: root.px * 3; color: "#b7e86a"; opacity: parent.blink * 0.18 }
                Rectangle { width: root.px; height: root.px; color: "#e4ff9a"; opacity: parent.blink * 0.9 }
            }
        }
    }

    // global dimmer: it's an OLED, the lock screen shouldn't be a flashlight
    Rectangle { anchors.fill: parent; color: "black"; opacity: 0.1 }
}
