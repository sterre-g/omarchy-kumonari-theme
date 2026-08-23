import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import qs.Commons
import qs.Ui
import "Sky.js" as Sky

/**
 * The Kumonari sky, on the layer between the wallpaper and the windows.
 *
 * ## Why this is not a background plugin
 *
 * The obvious way to put something animated on a desktop is to clone
 * `omarchy.background` and draw over the picture it was already drawing. That
 * costs the clone the whole of Omarchy's wallpaper handling, which it then owns
 * and has to keep up with, and it takes `omarchy.background` out of service for
 * every other theme on the machine. A theme that switches the desk's wallpaper
 * renderer off is a theme you can still see after you have taken it off.
 *
 * So this adds instead of replacing. `WlrLayer.Bottom` is the layer directly
 * above the one wallpapers are drawn on and directly below windows, which is
 * exactly the gap this belongs in: Omarchy goes on painting the picture and
 * doing its own transitions, this is what is in front of it, and taking the
 * theme off leaves nothing behind to undo.
 *
 * ## Why it asks which theme is on
 *
 * A plugin is the desk's rather than a theme's. It is enabled once and it draws
 * until somebody turns it off, and switching theme never reaches it at all. So
 * it asks: `theme.name` is the slug Omarchy writes on its way through a theme
 * change, before it hands the shell the new colours, which makes it both the
 * earliest the answer is knowable and early enough that the sky is gone before
 * the new wallpaper wipes across.
 *
 * Off means the layer surface is destroyed rather than hidden, so a desktop
 * wearing anything else is not paying for this at all.
 */
Item {
  id: root

  readonly property string stateHome: Quickshell.env("HOME") + "/.local/state"

  /**
   * The theme this sky belongs to, which is the directory Omarchy cloned it
   * into: `omarchy theme install` names a theme after its repository, and
   * `omarchy-kumonari-theme` is installed as `kumonari`.
   */
  readonly property string mine: "kumonari"

  /** Empty until the file has been read, and empty is not this theme. */
  property string wearing: ""
  readonly property bool worn: root.wearing === root.mine

  /**
   * The gas. Two of them are named here rather than taken from the palette
   * because the shell only publishes accent, foreground, background, muted and
   * urgent, and a sky with one hue in it is a fog. They are `magenta` and
   * `cyan` out of this theme's own `colors.toml`; the third follows the accent,
   * so a `colors.toml` overlaid on this theme still reaches the sky.
   */
  readonly property color drift: "#bb8cf5"
  readonly property color haze: "#63dcd4"

  FileView {
    path: root.stateHome + "/omarchy/current/theme.name"
    printErrors: false
    watchChanges: true

    onLoaded: root.wearing = String(text() || "").trim()
    onLoadFailed: root.wearing = ""
    // `text()` still holds the old contents inside the change signal itself, so
    // both paths go through a reload rather than one of them reading stale.
    onFileChanged: reload()
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: panel

      required property var modelData

      anchors {
        bottom: true
        left: true
        right: true
        top: true
      }
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      screen: panel.modelData
      visible: root.worn && !remapGuard.remapping

      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      WlrLayershell.layer: WlrLayer.Bottom
      WlrLayershell.namespace: "kumonari-sky"

      /**
       * Nothing up here is clickable, and an empty input region is how that is
       * said to the compositor. Without it this surface swallows every click
       * meant for the desktop under it, and Omarchy's own double click to the
       * wallpaper, which opens the background and theme pickers, stops working
       * for as long as the theme is on.
       */
      mask: Region {}

      /**
       * Whether this screen is showing its desktop at all.
       *
       * Gaps are zero and windows are opaque, so a single window on this
       * monitor's active workspace means the whole sky is behind it and every
       * animation up there is being drawn for nobody. `Hyprland.toplevels` is
       * fed by the compositor's event socket, so this settles when a window
       * opens, closes or changes workspace and at no other time. A sky nobody
       * can see costs one idle timer.
       */
      readonly property bool bare: (function () {
        var monitor = Hyprland.monitorFor(panel.screen)
        if (!monitor)
          return false

        var space = monitor.activeWorkspace
        if (!space)
          return true

        var windows = Hyprland.toplevels.values
        for (var i = 0; i < windows.length; i++) {
          if (windows[i].workspace === space)
            return false
        }

        return true
      })()

      readonly property bool live: root.worn && panel.bare

      /**
       * The clock the whole sky moves on, in ms since this screen last had
       * nothing on it.
       *
       * ## Why there is a clock and not twenty animations
       *
       * Every running animation in Qt Quick asks for a frame, and a frame here
       * is the whole of a 2560 by 1600 layer surface redrawn. It costs the same
       * whether the thing that moved crossed the screen or moved a fifth of a
       * pixel, and at these speeds it is nearly always the second: the moon
       * covers about 7px a second and the outermost star a fraction of that.
       *
       * Written the obvious way, with a `NumberAnimation` per moving part, this
       * cost about 10% of a core on a 2560x1600 screen. Turning off half the
       * scene changed nothing, and turning off the other half changed nothing
       * either, which is the shape of a cost that is per frame rather than per
       * moving part.
       *
       * So the frames are rationed instead. One timer steps a number and
       * everything up here is a binding on it. Five frames a second of motion
       * this slow is not distinguishable from sixty, and the same sky measures
       * 1.8% against a 0.1% shell that is drawing nothing. The other half of
       * that came from caching the gradients; see `Glow.qml`.
       *
       * Raise the rate if you want, it is one number. The comet does not use it
       * and keeps its own animations: it crosses in about a second and would be
       * a flip book at this rate. It is also the only thing here that is not
       * drawing most of the time.
       */
      property real elapsed: 0

      readonly property int tick: 200

      Timer {
        interval: panel.tick
        repeat: true
        running: panel.live

        onTriggered: panel.elapsed += panel.tick
      }

      /**
       * A different sky per monitor, and the same one back after a reboot.
       *
       * Two screens seeded alike are the same field of stars twice, which is
       * the one arrangement a pair of monitors never has and the thing the eye
       * picks up immediately when they are side by side.
       */
      readonly property int seed: Sky.hash(panel.modelData.name || "sky")

      ScreenMoveRemap {
        id: remapGuard

        window: panel
      }

      Nebula {
        elapsed: panel.elapsed
        hue: root.drift
        ink: 0.15
        reach: panel.height * 0.44
        squash: 0.58
        tilt: -18
        x: panel.width * 0.2 - width / 2
        y: panel.height * 0.3 - height / 2
      }

      Nebula {
        elapsed: panel.elapsed
        hue: root.haze
        ink: 0.1
        period: 67000
        reach: panel.height * 0.32
        squash: 0.7
        tilt: 24
        wander: 97000
        x: panel.width * 0.74 - width / 2
        y: panel.height * 0.16 - height / 2
      }

      Nebula {
        elapsed: panel.elapsed
        hue: Color.accent
        ink: 0.12
        period: 89000
        reach: panel.height * 0.5
        squash: 0.42
        tilt: 6
        wander: 143000
        x: panel.width * 0.46 - width / 2
        y: panel.height * 0.92 - height / 2
      }

      // Three depths, each about its own pole, so they pull apart as they turn
      // instead of moving as one sheet with three sizes of dot in it.
      Starfield {
        anchors.fill: parent
        count: 170
        dim: 0.55
        elapsed: panel.elapsed
        hue: Color.foreground
        poleX: -panel.width * 0.25
        poleY: panel.height * 1.35
        seed: panel.seed
        size: 0.85
        turn: 3600000
      }

      Starfield {
        anchors.fill: parent
        count: 95
        dim: 0.8
        elapsed: panel.elapsed
        hue: Color.foreground
        poleX: -panel.width * 0.3
        poleY: panel.height * 1.4
        seed: panel.seed ^ 0x9e37
        size: 1.15
        turn: 2400000
      }

      Starfield {
        anchors.fill: parent
        count: 40
        dim: 1
        elapsed: panel.elapsed
        hue: Color.foreground
        poleX: -panel.width * 0.35
        poleY: panel.height * 1.45
        seed: panel.seed ^ 0x51ed
        size: 1.6
        turn: 1500000
      }

      Planet {
        elapsed: panel.elapsed
        hue: "#243356"
        lit: Color.accent
        period: 214000
        span: panel.height * 0.15
        x: panel.width * 0.79 - width / 2
        y: panel.height * 0.74 - height / 2
      }

      Comet {
        anchors.fill: parent
        hue: Color.foreground
        running: panel.live
      }
    }
  }
}
