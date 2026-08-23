import QtQuick
import "Sky.js" as Sky

/**
 * A belt of rubble, seen at enough of an angle to be an ellipse.
 *
 * One `Repeater` of dots on a ring, each at its own angle and its own distance
 * out, turning together. The scatter is what makes it rubble: evenly spaced
 * dots on a clean ellipse is a dotted line, and a dotted line is a diagram.
 *
 * Positions come off `Sky.js`'s own generator so the same day gives the same
 * belt, which matters on a wallpaper that is redrawn every time a window closes
 * over it.
 */
Item {
  id: belt

  property int count: 90
  property real elapsed: 0
  property color hue: "#ffffff"
  property int period: 400000
  property real reach: 300
  property int seed: 1
  property real tilt: 0.26

  height: belt.reach * 2
  width: belt.reach * 2

  readonly property var rubble: {
    var roll = Sky.rng(belt.seed)
    var bits = []

    for (var i = 0; i < belt.count; i++) {
      bits.push({
        angle: 2 * Math.PI * roll(),
        // Squared towards the outside, so the belt is denser at its rim than
        // at its inner edge, which is the way a shepherded ring actually sits.
        away: 0.82 + 0.18 * Math.pow(roll(), 0.6),
        dim: 0.25 + 0.6 * roll(),
        size: 1 + 1.8 * roll(),
      })
    }

    return bits
  }

  Item {
    x: belt.width / 2
    y: belt.height / 2

    Repeater {
      model: belt.rubble

      Rectangle {
        id: rock

        required property var modelData

        readonly property real orbit: belt.reach * rock.modelData.away

        /**
         * Where this rock has got to, advanced along the ellipse rather than by
         * turning the ellipse.
         *
         * Rotating the whole belt was the first way and it is plainly wrong the
         * moment you see it: a flat ellipse rotated ninety degrees stands on
         * its end, so the belt swung from lying down to standing up like a coin
         * on a table. Rock positions move; the orbit they move on does not.
         */
        readonly property real marched: rock.modelData.angle + belt.elapsed / belt.period * 2 * Math.PI

        antialiasing: true
        color: belt.hue
        height: width
        opacity: rock.modelData.dim
        radius: width / 2
        width: rock.modelData.size
        x: rock.orbit * Math.cos(rock.marched) - width / 2
        y: rock.orbit * belt.tilt * Math.sin(rock.marched) - height / 2
      }
    }
  }
}
