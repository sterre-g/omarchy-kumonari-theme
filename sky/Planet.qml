import QtQuick
import QtQuick.Shapes

/**
 * A ringed world low in the frame, with one moon going round it.
 *
 * The moon is the only thing on this desktop that moves fast enough to catch
 * without waiting for it, which is the point of it. Everything else up there is
 * on a timescale of minutes so that the wallpaper is still a wallpaper.
 *
 * ## The ring is two arcs and not one
 *
 * Half a ring passes in front of the planet and half behind it, and a single
 * ellipse can only be on one side of a disc. So the far half is drawn under the
 * body and the near half over it, which is also what decides where the moon is
 * allowed to be: below the middle of the ellipse it is on the near side and in
 * front of everything, above it the planet is in the way.
 */
Item {
  id: world

  /** How wide the world is. Everything else here is a share of it. */
  property real span: 220

  /** The body, the ring, and the light the whole thing sits in. */
  property color hue: "#243356"
  property color lit: "#8ab4ff"

  /** How flat the ring is seen, 0 being edge on and 1 being from above. */
  property real tilt: 0.2

  /** How long the moon takes to go round, in ms. */
  property int period: 168000

  /** How long the sky has been up, in ms. */
  property real elapsed: 0

  // Three spans across, which is exactly the haze at its widest. Anything
  // tighter clips the atmosphere off at the box.
  height: world.span * 3
  width: world.span * 3

  readonly property real cx: width / 2
  readonly property real cy: height / 2
  readonly property real ringX: span * 0.98
  readonly property real ringY: span * 0.98 * world.tilt

  /**
   * Where the moon has got to, in radians, with 0 at the right hand edge and
   * the turn running clockwise because y points down.
   *
   * A binding on the clock rather than a `NumberAnimation`, which would repaint
   * the whole surface sixty times a second to move this moon a fifth of a pixel
   * each time. See the clock in `Sky.qml`.
   */
  readonly property real marched: world.elapsed / world.period * 2 * Math.PI

  Glow {
    anchors.fill: parent
    fall: 2.4
    hue: world.lit
    ink: 0.1
    reach: world.span * 1.5
    z: -3
  }

  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer
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

  Rectangle {
    height: width
    radius: width / 2
    width: world.span
    x: world.cx - width / 2
    y: world.cy - height / 2
    z: -1

    // Lit from above rather than from a light source anywhere in particular. A
    // sphere needs a light side and a dark one and nothing more than that to
    // stop reading as a circle.
    gradient: Gradient {
      GradientStop { position: 0; color: Qt.lighter(world.hue, 1.5) }
      GradientStop { position: 0.55; color: world.hue }
      GradientStop { position: 1; color: Qt.darker(world.hue, 1.9) }
    }
  }

  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer
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

  Rectangle {
    antialiasing: true
    color: Qt.lighter(world.lit, 1.1)
    height: width
    opacity: 0.75
    radius: width / 2
    width: world.span * 0.11
    x: world.cx + world.ringX * Math.cos(world.marched) - width / 2
    y: world.cy + world.ringY * Math.sin(world.marched) - height / 2

    // Below the middle of the ellipse is the near side of the orbit, and y
    // points down, so a positive sine is a moon in front of everything.
    z: Math.sin(world.marched) > 0 ? 2 : -2
  }
}
