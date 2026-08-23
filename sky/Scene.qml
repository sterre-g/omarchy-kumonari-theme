import QtQuick

/**
 * The sky itself, with nothing in it that knows about Wayland.
 *
 * Split from `Sky.qml` so that it can be looked at without being worn. Every
 * component below is plain Qt Quick, so `preview.qml` renders this offscreen
 * with the `qml` runtime and any day or palette can be checked without setting
 * the theme, waiting for midnight, or taking a photograph of somebody's actual
 * desktop. The half that does know about Wayland, the layer surface and the
 * theme gate and the clock, stays next door.
 *
 * What is drawn is handed in. `plan` is a day from `Sky.js` and `palette` is a
 * theme's colours off the same, and this arranges them and nothing else.
 */
Item {
  id: scene

  /** How long the sky has been up, in ms. */
  property real elapsed: 0

  /** `{ ground, hues, ink }`, from `Sky.palette`. */
  property var palette

  /** A day on one screen, from `Sky.plan`. */
  property var plan

  /** This screen's own number, which is what makes two monitors two skies. */
  property int seed: 1

  /** Whether the comet is allowed to run. It keeps its own animations. */
  property bool running: true

  Repeater {
    model: scene.plan.nebulae

    Nebula {
      required property var modelData

      elapsed: scene.elapsed
      hue: modelData.hue
      ink: modelData.ink
      period: modelData.period
      reach: scene.height * modelData.reach
      squash: modelData.squash
      sway: modelData.sway
      tilt: modelData.tilt
      wander: modelData.wander
      x: scene.width * modelData.x - width / 2
      y: scene.height * modelData.y - height / 2
    }
  }

  Galaxy {
    elapsed: scene.elapsed
    hue: scene.plan.galaxy.hue
    lean: scene.plan.galaxy.lean
    reach: scene.height * scene.plan.galaxy.reach
    visible: scene.plan.feature === "galaxy"
    x: scene.width * scene.plan.galaxy.at.x - width / 2
    y: scene.height * scene.plan.galaxy.at.y - height / 2
  }

  // Three depths, each about its own pole, so they pull apart as they turn
  // instead of moving as one sheet with three sizes of dot in it.
  Starfield {
    anchors.fill: parent
    count: Math.round(170 * scene.plan.stars)
    dim: 0.55
    elapsed: scene.elapsed
    hue: scene.palette.ink
    poleX: -scene.width * 0.25
    poleY: scene.height * 1.35
    seed: scene.seed
    size: 0.85
    turn: 3600000
  }

  Starfield {
    anchors.fill: parent
    count: Math.round(95 * scene.plan.stars)
    dim: 0.8
    elapsed: scene.elapsed
    hue: scene.palette.ink
    poleX: -scene.width * 0.3
    poleY: scene.height * 1.4
    seed: scene.seed ^ 0x9e37
    size: 1.15
    turn: 2400000
  }

  Starfield {
    anchors.fill: parent
    count: Math.round(40 * scene.plan.stars)
    dim: 1
    elapsed: scene.elapsed
    hue: scene.palette.ink
    poleX: -scene.width * 0.35
    poleY: scene.height * 1.45
    seed: scene.seed ^ 0x51ed
    size: 1.6
    turn: 1500000
  }

  Belt {
    count: scene.plan.belt.count
    elapsed: scene.elapsed
    hue: scene.palette.ink
    period: scene.plan.belt.period
    reach: scene.height * scene.plan.belt.reach
    seed: scene.seed ^ scene.plan.turn
    // The plan carries the belt's lean in degrees, which is how far over it is
    // seen; what an ellipse wants is the share of its height that survives.
    tilt: Math.abs(Math.sin(scene.plan.belt.tilt * Math.PI / 180)) * 0.6 + 0.08
    visible: scene.plan.feature === "belt"
    x: scene.width * scene.plan.belt.at.x - width / 2
    y: scene.height * scene.plan.belt.at.y - height / 2
  }

  Repeater {
    model: scene.plan.worlds

    Planet {
      required property var modelData

      bands: modelData.bands
      elapsed: scene.elapsed
      hue: modelData.body
      lit: modelData.hue
      moons: modelData.moons
      ringTilt: modelData.ringTilt
      rings: modelData.rings
      span: scene.height * modelData.span
      spin: modelData.spin
      x: scene.width * modelData.x - width / 2
      y: scene.height * modelData.y - height / 2
    }
  }

  Comet {
    anchors.fill: parent
    hue: scene.palette.ink
    running: scene.running
  }
}
