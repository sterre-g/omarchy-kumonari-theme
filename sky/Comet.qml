import QtQuick

/**
 * A streak that crosses now and then and is gone.
 *
 * One rectangle and one timer, reused. A pool of comets, or one spawned per
 * flight, would be a lot of object churn for something the eye sees for a
 * second at a time and never sees two of.
 *
 * The wait between them is rerolled after every flight rather than fixed. A
 * fixed interval is a metronome, and a metronome is the thing that turns an
 * ornament into a tic somebody starts counting.
 */
Item {
  id: sky

  property color hue: "#ffffff"

  /** The gap between crossings, in ms, rolled fresh inside this range. */
  property int rarest: 27000
  property int soonest: 9000

  /** How long one crossing takes, rolled per flight. */
  property int dash: 900

  property real thickness: 1.6
  property bool running: true

  function next() {
    return sky.soonest + Math.floor(Math.random() * (sky.rarest - sky.soonest))
  }

  function fly() {
    if (sky.width <= 0 || sky.height <= 0)
      return

    // Down and to the right, at a shallow lean. Steeper than about 45 and it
    // stops reading as something falling a very long way away.
    var lean = 16 + Math.random() * 28
    var rad = lean * Math.PI / 180
    var span = sky.width * (0.26 + Math.random() * 0.34)

    // Started high and left of centre, since it has to have somewhere to go.
    var fromX = sky.width * (Math.random() * 0.72 - 0.12)
    var fromY = sky.height * (Math.random() * 0.44 - 0.1)

    sky.dash = 700 + Math.floor(Math.random() * 700)

    streak.rotation = lean
    streak.width = 70 + Math.random() * 160

    slide.from = fromX
    slide.to = fromX + span * Math.cos(rad)
    fall.from = fromY
    fall.to = fromY + span * Math.sin(rad)

    flight.restart()
  }

  onRunningChanged: {
    if (!sky.running) {
      flight.stop()
      streak.opacity = 0
    }
  }

  Rectangle {
    id: streak

    height: Math.max(1, sky.thickness)
    opacity: 0
    transformOrigin: Item.Center

    // Bright at the leading end and nothing at the other, which is the whole of
    // what makes a moving line read as something with a tail behind it.
    gradient: Gradient {
      orientation: Gradient.Horizontal

      GradientStop { position: 0; color: "transparent" }
      GradientStop { position: 0.72; color: Qt.rgba(sky.hue.r, sky.hue.g, sky.hue.b, 0.45) }
      GradientStop { position: 1; color: sky.hue }
    }
  }

  ParallelAnimation {
    id: flight

    NumberAnimation {
      id: slide

      duration: sky.dash
      easing.type: Easing.InQuad
      property: "x"
      target: streak
    }
    NumberAnimation {
      id: fall

      duration: sky.dash
      easing.type: Easing.InQuad
      property: "y"
      target: streak
    }
    SequentialAnimation {
      NumberAnimation {
        duration: sky.dash * 0.22
        from: 0
        property: "opacity"
        target: streak
        to: 1
      }
      NumberAnimation {
        duration: sky.dash * 0.78
        easing.type: Easing.InQuad
        property: "opacity"
        target: streak
        to: 0
      }
    }
  }

  Timer {
    interval: sky.next()
    repeat: true
    running: sky.running

    onTriggered: {
      sky.fly()
      interval = sky.next()
    }
  }
}
