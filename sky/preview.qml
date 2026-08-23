import QtQuick
import "Sky.js" as Sky

/**
 * The sky, rendered offscreen, for any day and any theme.
 *
 * A wallpaper that is different every morning is awkward to check by looking at
 * it: you get one day per day, on whichever screen you happen to be at, and
 * only while nothing is covering it. This renders whichever days you ask for
 * straight to PNGs, with no compositor and without setting the theme.
 *
 *   bin/preview.sh                    a week of this theme's palette
 *   bin/preview.sh --theme gruvbox    the same week in somebody else's
 *
 * `Scene.qml` is all this draws and all the desktop draws, so a day that looks
 * right here looks right there. The half that knows about Wayland does not draw
 * anything, which is why it can be left out.
 */
Item {
  id: shot

  property int days: 7
  property string out: "preview"
  property int seed: 1
  property int tall: 1000
  property int wide: 1600

  property string toml: ""
  property int drawn: 0
  property int saved: 0

  readonly property var palette: Sky.palette(Sky.parsePalette(shot.toml), {
    accent: "#8ab4ff",
    background: "#05070f",
    foreground: "#c9d2ec",
  })

  height: shot.tall
  width: shot.wide

  function arg(name, fallback) {
    var all = Qt.application.arguments

    for (var i = 0; i < all.length - 1; i++) {
      if (all[i] === "--" + name) return all[i + 1]
    }

    return fallback
  }

  /**
   * The theme's colours, handed in already encoded rather than read off disk.
   *
   * Plain QML has no file reading in it. Quickshell's `FileView` does the job
   * on the desktop and is not here on purpose, since the point of this file is
   * to run without Quickshell, and `XMLHttpRequest` against a `file:` URL comes
   * back empty in this Qt rather than erroring, which is a quiet way to spend
   * an afternoon rendering the same fallback palette five times and wondering
   * why every theme looks identical.
   *
   * So `bin/preview.sh` reads the file and passes it base64 on the command
   * line, which has no such opinions.
   */
  function decode(text) {
    if (!text) return ""

    try {
      return Qt.atob(text)
    } catch (e) {
      return ""
    }
  }

  function dayAfter(step) {
    var day = new Date()
    day.setDate(day.getDate() + step)
    return day
  }

  property string over: ""

  Rectangle {
    id: frame

    anchors.fill: parent
    color: shot.palette.dark

    // Flat by default, where a real desktop has a wallpaper. On purpose: the
    // point of a preview is usually the sky, and a picture behind it hides
    // exactly the faint gas being looked at. Pass `--over` a wallpaper to see
    // the two together, which is what the desktop actually shows.
    //
    // `Image` reads a file straight off disk, unlike `XMLHttpRequest`, which is
    // why the palette has to arrive base64 on the command line and this does
    // not.
    Image {
      anchors.fill: parent
      asynchronous: false
      fillMode: Image.PreserveAspectCrop
      source: shot.over ? "file://" + shot.over : ""
      visible: shot.over !== ""
    }

    Scene {
      anchors.fill: parent
      // Far enough in that the slow things have somewhere to have got to, so a
      // preview is not every moon frozen at its own starting angle.
      elapsed: 90000
      palette: shot.palette
      plan: Sky.plan(shot.seed ^ Sky.daySeed(shot.dayAfter(shot.drawn)), shot.palette.hues, shot.wide / shot.tall)
      running: false
      seed: shot.seed
    }
  }

  function shoot() {
    if (shot.drawn >= shot.days) {
      Qt.quit()
      return
    }

    var name = shot.out + "-" + (shot.drawn + 1) + ".png"

    frame.grabToImage(function (result) {
      result.saveToFile(name)
      shot.saved += 1
      shot.drawn += 1
      // A turn of the event loop between frames, so the scene rebuilds on the
      // next day's plan before the next grab rather than every file holding
      // the first day.
      Qt.callLater(shot.shoot)
    })
  }

  Component.onCompleted: {
    shot.over = shot.arg("over", "")
    shot.wide = parseInt(shot.arg("wide", "1600"))
    shot.tall = parseInt(shot.arg("tall", "1000"))
    shot.days = parseInt(shot.arg("days", "7"))
    shot.out = shot.arg("out", "preview")
    shot.seed = parseInt(shot.arg("seed", "1"))
    shot.toml = shot.decode(shot.arg("palette64", ""))

    Qt.callLater(shot.shoot)
  }
}
