import QtQuick
import "Sky.js" as Sky

/**
 * One depth of sky, turning about a pole off the corner of the screen.
 *
 * ## Why it turns instead of sliding
 *
 * A field that slides has to be drawn twice and handed back to the start, and
 * either the seam shows or the wrap costs a second copy of every star. A field
 * that turns has neither: the stars are laid out once over a disc big enough to
 * cover the screen from wherever the pole is standing, and the whole depth is
 * one rotation the card applies as a matrix. It is also what the real one does.
 *
 * The pole is off the corner rather than in the middle, so nothing on screen is
 * visibly pivoting. Near the pole a star crawls and out at the rim it drifts,
 * which is the parallax without a second mechanism for it.
 *
 * ## Why nothing here is animated
 *
 * Everything is a binding on `elapsed`, which is a number somebody else steps.
 * See the clock in `Sky.qml`: a running animation repaints the whole surface at
 * the compositor's rate whether or not anything moved far enough to see, and at
 * these speeds almost none of those frames are worth drawing.
 */
Item {
  id: depth

  /** How many stars, and how bright this depth is allowed to get. */
  property int count: 120
  property real dim: 0.8

  /** How long the sky has been up, in ms. Everything here is a function of it. */
  property real elapsed: 0

  property color hue: "#ffffff"

  /** Where the sky turns about, in this item's own coordinates. */
  property real poleX: 0
  property real poleY: 0

  property int seed: 1

  /** A multiplier on every star's own size, which is how a depth reads near. */
  property real size: 1

  /** How long a full revolution takes, in ms. */
  property int turn: 2400000

  readonly property real reach: Sky.reach(width, height, depth.poleX, depth.poleY)
  readonly property var stars: Sky.field(depth.count, depth.seed, depth.reach)

  Item {
    x: depth.poleX
    y: depth.poleY
    rotation: depth.elapsed / depth.turn * 360

    Repeater {
      model: depth.stars

      Rectangle {
        id: star

        required property var modelData

        /**
         * The breath, and why the still stars are not paying for it.
         *
         * QML works out what a binding depends on by watching which properties
         * it actually reads. A star that does not twinkle never reaches the
         * side of this expression that mentions `elapsed`, so it never becomes
         * a dependency of it and the clock does not wake it. Fifteen stars
         * re-evaluate on a tick rather than three hundred.
         */
        readonly property real beat: star.modelData.twinkle
          ? 0.66 + 0.34 * Math.sin(depth.elapsed / star.modelData.beat * 2 * Math.PI + star.modelData.phase)
          : 1

        antialiasing: true
        color: depth.hue
        height: width
        opacity: star.modelData.dim * depth.dim * star.beat
        radius: width / 2
        width: star.modelData.size * depth.size
        x: star.modelData.x - width / 2
        y: star.modelData.y - height / 2
      }
    }
  }
}
