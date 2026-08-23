import QtQuick

/**
 * Another galaxy, far enough off to be one smudge of light.
 *
 * A squashed lens with a brighter core in it and a faint halo around it, which
 * is all a spiral is at this distance. Drawn out of the same `Glow` as the gas
 * rather than as anything of its own: three lights of different flatness stack
 * into something the eye reads as edge-on, and a real spiral would be a texture
 * nobody could see at this size.
 *
 * It turns, slowly enough that nobody catches it, which is the only reason to
 * prefer it to a picture.
 */
Item {
  id: far

  property real elapsed: 0
  property color hue: "#ffffff"

  /** Which way it lies, and how long a full turn takes. */
  property real lean: -20
  property int period: 900000

  property real reach: 180

  height: far.reach * 2
  width: far.reach * 2

  rotation: far.lean + far.elapsed / far.period * 360

  Glow {
    anchors.fill: parent
    fall: 2.2
    hue: far.hue
    ink: 0.13
    reach: far.reach
    squash: 0.2
  }

  Glow {
    anchors.fill: parent
    fall: 2.8
    hue: far.hue
    ink: 0.1
    reach: far.reach * 0.62
    squash: 0.44
  }

  Glow {
    anchors.fill: parent
    fall: 2.6
    hue: Qt.lighter(far.hue, 1.4)
    ink: 0.3
    reach: far.reach * 0.2
    squash: 0.8
  }
}
