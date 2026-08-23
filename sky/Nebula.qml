import QtQuick

/**
 * A cloud of gas that breathes and drifts.
 *
 * The breath is a swell in brightness and size together, because gas that only
 * changes brightness reads as a lamp on a dimmer. The drift is a few dozen
 * pixels over a minute or two, under the threshold at which anybody catches it
 * moving and over the one at which the desktop looks like a photograph.
 *
 * The two periods are deliberately not multiples of each other. Where they are,
 * the pair lines up every so often and the cloud pulses on a beat, which is the
 * one thing gas never does.
 *
 * Both are cosines of `elapsed` rather than animations. See the clock in
 * `Sky.qml` for why nothing up here runs at the compositor's rate.
 */
Item {
  id: cloud

  /** How long the sky has been up, in ms. */
  property real elapsed: 0

  property color hue: "#ffffff"
  property real ink: 0.12

  /** How far it drifts and how long the round trip takes. */
  property real sway: 40
  property int wander: 121000

  /** How far the light reaches, and how much of its height it keeps. */
  property real reach: 300
  property real squash: 0.62

  /** The swell, as a share of `reach` at the top of the breath. */
  property real swell: 1.25
  property int period: 53000

  property real tilt: -14

  // Big enough to hold the light it contains, so a caller places the middle of
  // the cloud and never has to know how far the gas gets.
  height: cloud.reach * 2
  width: cloud.reach * 2

  // A cosine starts at its own top, so every cloud would be at the peak of its
  // breath on the first frame and the sky would open on a flash. Half a period
  // of offset starts them at the bottom instead, on the way up.
  readonly property real breath: 0.5 - 0.5 * Math.cos((cloud.elapsed / cloud.period + 1) * Math.PI)
  readonly property real drift: 0.5 - 0.5 * Math.cos(cloud.elapsed / cloud.wander * Math.PI)

  transform: Translate { x: cloud.drift * cloud.sway }

  Glow {
    anchors.fill: parent
    fall: 2.6
    hue: cloud.hue
    ink: cloud.ink
    opacity: 0.55 + 0.45 * cloud.breath
    reach: cloud.reach
    rotation: cloud.tilt
    scale: 1 + (cloud.swell - 1) * cloud.breath
    squash: cloud.squash
  }
}
