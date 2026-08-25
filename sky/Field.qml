import QtQuick

/**
 * The sky as one item, drawn by `sky.frag`.
 *
 * Everything that used to be an object up here is arithmetic in the shader now,
 * so this file is not a scene: it is the plan turned into uniforms, and a clock.
 * `sky.frag` carries why that swap happened and what it measured.
 *
 * Plain Qt Quick with nothing of Quickshell in it, like the scene it replaced,
 * so `preview.qml` can still render any day of it offscreen without the theme
 * being worn or a compositor being involved.
 */
Item {
    id: field

    /** `{ ground, hues, ink }`, from `Sky.palette`. */
    property var palette

    /** A day on one screen, from `Sky.plan`. */
    property var plan

    /** Whether the clock runs at all. False costs nothing. */
    property bool running: true

    /**
     * How far through the night it is, 0 to 1, which the colour drifts across.
     *
     * Handed in rather than read here, because the wall clock belongs to the
     * half of this that knows what a desktop is, and a preview wants to ask for
     * an hour rather than wait for one.
     */
    property real night: 0.5

    /**
     * How often the sky is redrawn when nothing is falling.
     *
     * Twelve a second, and the number is not about what looks smooth. Nothing
     * up here moves faster than about eight pixels a second, so twelve frames
     * is under a pixel of travel between them, and motion under a pixel does
     * not step no matter how few frames it arrives in. Rate buys nothing above
     * that and costs about 0.11% of a core for every frame a second, measured
     * on this desk.
     *
     * A meteor is the exception, and `flying` is what it does about it.
     */
    property int idle: 83

    /** Whether a meteor is in the air, and so whether the card's rate is wanted. */
    property bool flying: false

    /**
     * How far in the sky already is when it first draws, in seconds.
     *
     * Only a preview has any use for this. A still of a sky at zero is every
     * moon frozen at the angle it was rolled at and every cloud at the bottom
     * of its breath, which is the one moment of the night that looks arranged.
     */
    property real from: 0

    readonly property real seconds: shader.seconds

    function tint(hex, a) {
        var c = Qt.color(hex || "#ffffff")
        return Qt.vector4d(c.r, c.g, c.b, a)
    }

    /**
     * The nth of something the day may not have rolled.
     *
     * The shader takes a fixed three clouds and three worlds because a uniform
     * block has a fixed shape, and the day rolls between two and four of the
     * one and one and three of the other. Absent has to be cheap rather than
     * undefined, so an absent thing is sent with its size or its ink at zero,
     * which the shader leaves alone in one comparison.
     */
    function nth(list, i) {
        return list && i < list.length ? list[i] : null
    }

    function cloudHue(i) {
        var n = field.nth(field.plan ? field.plan.nebulae : null, i)
        return n ? field.tint(n.hue, n.ink) : Qt.vector4d(0, 0, 0, 0)
    }

    function cloudAt(i) {
        var n = field.nth(field.plan ? field.plan.nebulae : null, i)
        return n ? Qt.vector4d(n.x, n.y, field.height * n.reach, n.squash) : Qt.vector4d(0, 0, 0, 0)
    }

    function worldAt(i) {
        var w = field.nth(field.plan ? field.plan.worlds : null, i)
        if (!w)
            return Qt.vector4d(0, 0, 0, 0)

        // `w.seed` is what the shader rolls this world's moons and weather off.
        // See `Sky.plan`, which keeps the night and hands the detail over.
        return Qt.vector4d(field.width * w.x, field.height * w.y, field.height * w.span, w.seed)
    }

    function worldLit(i) {
        var w = field.nth(field.plan ? field.plan.worlds : null, i)
        return w ? field.tint(w.hue, w.rings ? w.ringTilt : 0) : Qt.vector4d(0, 0, 0, 0)
    }

    function worldBody(i) {
        var w = field.nth(field.plan ? field.plan.worlds : null, i)
        return w ? field.tint(w.body, w.spin / 1000) : Qt.vector4d(0, 0, 0, 0)
    }

    ShaderEffect {
        id: shader

        anchors.fill: parent

        /**
         * The clock, and the whole of what the processor does per frame.
         *
         * Stepped by the interval rather than read off a wall clock, so the sky
         * runs at the same speed whichever rate the timer is on and switching
         * between them does not jump. A wallpaper does not care that this
         * drifts from real seconds.
         */
        property real seconds: 0

        property vector4d frame: Qt.vector4d(shader.width, shader.height, shader.seconds, field.night)
        property vector4d ink: field.tint(field.palette ? field.palette.ink : "#c9d2ec", field.plan ? field.plan.stars : 1)

        property vector4d gas0: field.cloudHue(0)
        property vector4d gas1: field.cloudHue(1)
        property vector4d gas2: field.cloudHue(2)
        property vector4d at0: field.cloudAt(0)
        property vector4d at1: field.cloudAt(1)
        property vector4d at2: field.cloudAt(2)

        property vector4d world0: field.worldAt(0)
        property vector4d world1: field.worldAt(1)
        property vector4d world2: field.worldAt(2)
        property vector4d lit0: field.worldLit(0)
        property vector4d lit1: field.worldLit(1)
        property vector4d lit2: field.worldLit(2)
        property vector4d body0: field.worldBody(0)
        property vector4d body1: field.worldBody(1)
        property vector4d body2: field.worldBody(2)

        property vector4d far: field.plan && field.plan.feature === "galaxy"
            ? Qt.vector4d(field.width * field.plan.galaxy.at.x, field.height * field.plan.galaxy.at.y,
                          field.height * field.plan.galaxy.reach, field.plan.galaxy.lean * Math.PI / 180)
            : Qt.vector4d(0, 0, 0, 0)
        property vector4d farHue: field.plan ? field.tint(field.plan.galaxy.hue, 1) : Qt.vector4d(0, 0, 0, 0)

        // The plan carries the belt's lean in degrees, which is how far over it
        // is seen; what an ellipse wants is the share of its height that lives.
        property vector4d belt: field.plan && field.plan.feature === "belt"
            ? Qt.vector4d(field.width * field.plan.belt.at.x, field.height * field.plan.belt.at.y,
                          field.height * field.plan.belt.reach,
                          Math.abs(Math.sin(field.plan.belt.tilt * Math.PI / 180)) * 0.6 + 0.08)
            : Qt.vector4d(0, 0, 0, 0)
        property vector4d beltHue: field.plan
            ? field.tint(field.palette ? field.palette.ink : "#c9d2ec", (field.plan.belt.period - 300000) / 240000)
            : Qt.vector4d(0, 0, 0, 0)

        /** Where a meteor is falling, and `w` below zero while none is. */
        property vector4d meteor: Qt.vector4d(0, 0, 0, -1)

        blending: true
        fragmentShader: "sky.frag.qsb"

        Component.onCompleted: shader.seconds = field.from

        Timer {
            interval: field.flying ? 16 : field.idle
            repeat: true
            running: field.running

            onTriggered: shader.seconds += interval / 1000
        }
    }

    /**
     * A meteor now and then, and the frames to draw one with.
     *
     * The wait is rerolled after every crossing rather than fixed. A fixed
     * interval is a metronome, and a metronome is the thing that turns an
     * ornament into a tic somebody starts counting.
     *
     * This is the only thing in the sky worth spending the card's own frame
     * rate on, so it is the only thing that gets it: `flying` is up for about
     * the second it takes to cross and the sky is back to its idle rate after.
     * A second of frames every twenty is a rounding error on the average and
     * the difference between a streak and a row of dashes.
     */
    Timer {
        id: fuse

        interval: 9000
        repeat: true
        running: field.running

        onTriggered: {
            // Started high and left of centre, since it has to have somewhere
            // to go, and leaning down and to the right. Steeper than about
            // forty five degrees and it stops reading as something falling a
            // very long way away.
            shader.meteor = Qt.vector4d(field.width * (Math.random() * 0.72 - 0.12),
                                        field.height * (Math.random() * 0.44 - 0.1),
                                        (16 + Math.random() * 28) * Math.PI / 180,
                                        shader.seconds)
            field.flying = true
            done.restart()
            fuse.interval = 9000 + Math.floor(Math.random() * 18000)
        }
    }

    Timer {
        id: done

        // The crossing is 1.1s in the shader; this is that and a little, so the
        // rate drops back after the tail has gone rather than during it.
        interval: 1300

        onTriggered: field.flying = false
    }

    onRunningChanged: {
        if (!field.running) {
            field.flying = false
            shader.meteor = Qt.vector4d(0, 0, 0, -1)
        }
    }
}
