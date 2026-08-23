import QtQuick
import QtQuick.Shapes

/**
 * A round light, brightest at the middle and gone by its own edge.
 *
 * Every soft thing up there is one of these: the gas, the haze around the
 * planet, the lit side of it. A radial gradient on a Shape rather than a
 * blurred rectangle, because a blur wide enough to pass for gas is wide enough
 * to cost a frame every frame, and this is one fill the card does in a pass and
 * then caches for as long as nothing about it changes.
 *
 * ## Why there is a ladder of stops and not two ends
 *
 * Alpha runs dead straight between two stops. Where two straight runs meet at
 * different slopes the eye finds a ring, and a light that gives out on a curve
 * drawn as one straight line is all ring. Six stops on a fall this steep leaves
 * nowhere for one to show, and they are generated from `fall` rather than typed
 * out so that changing the falloff cannot leave the ladder behind.
 */
Shape {
  id: glow

  /** Where the light is, in this item's own coordinates. */
  property real cx: width / 2
  property real cy: height / 2

  /**
   * How fast it gives out, as the exponent on the way out from the middle.
   *
   * At 1 it thins evenly and ends on a visible hem, which reads as a disc with
   * a soft edge rather than as a light. Past about 4 it is gone before it has
   * left whatever it came off.
   */
  property real fall: 2.2

  /** The colour of it, and how heavy it is at the middle. */
  property color hue: "#ffffff"
  property real ink: 0.2

  /** How far it reaches before there is none of it left, in px. */
  property real reach: 0

  /**
   * How much of its height it keeps. Gas is not round, and a cloud drawn round
   * is a ball of wool; squashing the light is cheaper than drawing an ellipse
   * and is the same picture.
   */
  property real squash: 1

  function at(out) {
    return Qt.rgba(glow.hue.r, glow.hue.g, glow.hue.b, glow.ink * Math.pow(1 - out, glow.fall))
  }

  preferredRendererType: Shape.CurveRenderer
  visible: glow.ink > 0 && glow.reach > 0

  /**
   * Rasterised once and then treated as a picture.
   *
   * A gradient this size is tessellated on the CPU, and without this it is
   * tessellated again on every frame the surface is redrawn for whatever other
   * reason, which on a wallpaper is every frame there is. Cached, a breath is a
   * scale and an opacity on a texture the card already holds, which is free.
   * The cost is one texture the size of this item, and these are bounded by the
   * screen.
   */
  layer.enabled: true
  layer.smooth: true

  transform: Scale {
    origin.x: glow.cx
    origin.y: glow.cy
    yScale: glow.squash
  }

  ShapePath {
    fillGradient: RadialGradient {
      centerRadius: glow.reach
      centerX: glow.cx
      centerY: glow.cy
      focalX: glow.cx
      focalY: glow.cy

      GradientStop { position: 0; color: glow.at(0) }
      GradientStop { position: 0.2; color: glow.at(0.2) }
      GradientStop { position: 0.4; color: glow.at(0.4) }
      GradientStop { position: 0.6; color: glow.at(0.6) }
      GradientStop { position: 0.8; color: glow.at(0.8) }
      GradientStop { position: 1; color: glow.at(1) }
    }
    strokeColor: "transparent"

    PathAngleArc {
      centerX: glow.cx
      centerY: glow.cy
      radiusX: glow.reach
      radiusY: glow.reach
      startAngle: 0
      sweepAngle: 360
    }
  }
}
