import QtQuick
import QtQuick.Shapes

/**
 * A world, built to whatever the day rolled for it.
 *
 * Nothing here is decided in this file. Size, colour, rings, how many moons and
 * where the weather sits all arrive as properties, because a planet that is the
 * same planet every day is scenery and the point of this one is that it is not.
 * `Sky.js` does the rolling; this draws what it is handed.
 *
 * ## The ring is two arcs and not one
 *
 * Half a ring passes in front of the planet and half behind it, and a single
 * ellipse can only be on one side of a disc. So the far half is drawn under the
 * body and the near half over it. That is also what decides where a moon is
 * allowed to be: below the middle of its orbit it is on the near side and in
 * front of everything, above it the planet is in the way.
 */
Item {
  id: world

  /** How wide the body is. Everything else here is a share of it. */
  property real span: 220

  /** The body, and the colour of the light around it. */
  property color hue: "#243356"
  property color lit: "#8ab4ff"

  /** How long the sky has been up, in ms. */
  property real elapsed: 0

  /**
   * The weather, as `{ at, thick, light }` each.
   *
   * `at` is a latitude from -1 at one pole to 1 at the other, and the width of
   * a band follows from it: a circle of radius r is 2*sqrt(r^2 - y^2) across at
   * height y, so a band drawn that wide hugs the sphere without anything having
   * to clip it to the disc. Clipping was the other way to do this, and Qt's
   * `clip` is a rectangle, which is no use against a circle.
   */
  property var bands: []

  /** `{ away, size, period, phase, tilt, lit }` each, orbits in body widths. */
  property var moons: []

  /** Whether it has rings, and how flat they are seen. */
  property bool rings: true
  property real ringTilt: 0.2

  /** How long the weather takes to roll once round, in ms. */
  property int spin: 220000

  readonly property real ringX: world.rings ? world.span * 0.98 : 0
  readonly property real ringY: world.ringX * world.ringTilt
  readonly property real haze: world.span * 1.5

  /**
   * Far enough out to hold the widest thing here, which is the outermost moon
   * on a day that rolled three of them and the haze on a day that did not.
   * Worked out rather than assumed, since a box sized for the body alone cuts
   * the orbits off at its own corner.
   */
  readonly property real bounds: {
    var out = Math.max(world.haze, world.ringX * 1.08)

    for (var i = 0; i < world.moons.length; i++) {
      out = Math.max(out, world.span * (world.moons[i].away + world.moons[i].size))
    }

    return out
  }

  readonly property real cx: width / 2
  readonly property real cy: height / 2

  height: world.bounds * 2
  width: world.bounds * 2

  Glow {
    anchors.fill: parent
    fall: 2.4
    hue: world.lit
    ink: 0.1
    reach: world.haze
    z: -3
  }

  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer
    visible: world.rings
    z: -2

    ShapePath {
      // Flat, because the halves meet where the ellipse runs vertical and the
      // default square cap hangs half a stroke width out past it as a tab.
      capStyle: ShapePath.FlatCap
      fillColor: "transparent"
      strokeColor: Qt.rgba(world.lit.r, world.lit.g, world.lit.b, 0.22)
      strokeWidth: Math.max(1, world.span * 0.05)

      PathAngleArc {
        centerX: world.cx
        centerY: world.cy
        radiusX: world.ringX
        radiusY: world.ringY
        startAngle: 180
        sweepAngle: 180
      }
    }
  }

  Item {
    id: body

    height: world.span
    width: world.span
    x: world.cx - width / 2
    y: world.cy - height / 2
    z: -1

    Rectangle {
      anchors.fill: parent
      antialiasing: true
      radius: width / 2

      // Lit from above rather than from a light source anywhere in particular.
      // A sphere needs a light side and a dark one and nothing more than that
      // to stop reading as a circle.
      gradient: Gradient {
        GradientStop { position: 0; color: Qt.lighter(world.hue, 1.5) }
        GradientStop { position: 0.55; color: world.hue }
        GradientStop { position: 1; color: Qt.darker(world.hue, 1.9) }
      }
    }

    Repeater {
      model: world.bands

      Rectangle {
        id: band

        required property var modelData

        /**
         * Where this band has drifted to, wrapped back to the far pole when it
         * runs off one end. A band is fixed in latitude on a real planet, but a
         * disc this size has no surface to turn, and weather crossing it slowly
         * is what reads as a world rather than as a sticker.
         */
        readonly property real at: {
          var drift = band.modelData.at + world.elapsed / world.spin * 2
          return (((drift + 1) % 2) + 2) % 2 - 1
        }

        readonly property real reach: world.span / 2

        antialiasing: true
        // Well clear of the body either way. The body is already dark, so a
        // band a shade off it is a band nobody can see, which is how the first
        // version of these shipped without anybody noticing they were there.
        color: band.modelData.light ? Qt.lighter(world.hue, 2.1) : Qt.darker(world.hue, 2.1)
        height: Math.max(1, band.modelData.thick * band.reach)
        // Faded out at the poles, where a band is short enough that a hard end
        // to it would read as a scratch on the disc.
        opacity: 0.6 * Math.max(0, 1 - band.at * band.at)
        radius: height / 2
        width: 2 * band.reach * Math.sqrt(Math.max(0, 1 - band.at * band.at))
        x: body.width / 2 - width / 2
        y: body.height / 2 + band.at * band.reach - height / 2
      }
    }
  }

  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer
    visible: world.rings
    z: 1

    ShapePath {
      capStyle: ShapePath.FlatCap
      fillColor: "transparent"
      strokeColor: Qt.rgba(world.lit.r, world.lit.g, world.lit.b, 0.3)
      strokeWidth: Math.max(1, world.span * 0.05)

      PathAngleArc {
        centerX: world.cx
        centerY: world.cy
        radiusX: world.ringX
        radiusY: world.ringY
        startAngle: 0
        sweepAngle: 180
      }
    }
  }

  Repeater {
    model: world.moons

    Rectangle {
      id: moon

      required property var modelData

      /**
       * Where it has got to, with 0 at the right hand edge and the turn running
       * clockwise because y points down. A binding on the clock rather than a
       * `NumberAnimation`, which would repaint the whole surface sixty times a
       * second to move this a fifth of a pixel each time.
       */
      readonly property real marched: (world.elapsed / moon.modelData.period + moon.modelData.phase) * 2 * Math.PI

      readonly property real orbit: world.span * moon.modelData.away

      antialiasing: true
      color: moon.modelData.lit ? Qt.lighter(world.lit, 1.1) : Qt.darker(world.lit, 1.25)
      height: width
      opacity: 0.8
      radius: width / 2
      width: world.span * moon.modelData.size
      x: world.cx + moon.orbit * Math.cos(moon.marched) - width / 2
      y: world.cy + moon.orbit * moon.modelData.tilt * Math.sin(moon.marched) - height / 2

      // Below the middle of the orbit is the near side, and y points down, so a
      // positive sine is a moon in front of everything.
      z: Math.sin(moon.marched) > 0 ? 2 : -2
    }
  }
}
