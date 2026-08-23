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

  /**
   * The colours the sky is made of, out of the theme's own `colors.toml`.
   *
   * The shell publishes five colours and no more: foreground, background,
   * accent, urgent, muted. That is enough to tint something and not enough to
   * build a sky out of, because a nebula wants several hues that are not each
   * other and a palette of one accent gives a fog. The file has the rest of
   * them, so the file is read.
   *
   * ## Read on the theme changing, not watched
   *
   * `omarchy-theme-set` builds the next theme in a staging directory and then
   * `mv`s it over `current/theme`, so every file in there is a new inode on
   * every switch and an inotify watch on `colors.toml` dies with the first one.
   * `theme.name` survives because it is written in place, which makes it the
   * thing to watch and this the thing to re-read when it moves.
   *
   * That ordering is also why this is not a race: the theme directory is moved
   * into place before `theme.name` is written, so by the time the name says
   * kumonari, kumonari's `colors.toml` is already the file at that path.
   */
  property var palette: Sky.palette({}, root.shellColours)

  readonly property var shellColours: ({
    accent: String(Color.accent),
    background: String(Color.background),
    foreground: String(Color.foreground),
  })

  function rereadPalette() {
    paletteFile.reload()
  }

  onWearingChanged: root.rereadPalette()

  // The shell can repaint from an IPC payload without any file this watches
  // having moved, so the palette follows that too. Cheap: a parse of thirty
  // lines, only when the desktop actually changes colour.
  onShellColoursChanged: root.rereadPalette()

  FileView {
    id: paletteFile

    path: root.stateHome + "/omarchy/current/theme/colors.toml"
    printErrors: false
    watchChanges: false

    onLoaded: root.palette = Sky.palette(Sky.parsePalette(text()), root.shellColours)
    // A theme is not obliged to ship colours at all: one of mine is an empty
    // directory. The shell's own five are the floor, and a sky can be built out
    // of an accent alone.
    onLoadFailed: root.palette = Sky.palette({}, root.shellColours)
  }

  /**
   * Which day it is, which is what the sky is rolled from.
   *
   * `SystemClock` and not a `Timer`, and that distinction has bitten this
   * codebase's neighbour before: a Timer counts monotonic time, which is time
   * this machine has been awake for, so a laptop closed at eleven and opened at
   * nine still has most of the night left to run on its counter and goes on
   * showing yesterday's planets. `SystemClock` is the wall clock, which is the
   * thing a calendar day is actually a function of.
   */
  property int today: Sky.daySeed()

  SystemClock {
    precision: SystemClock.Minutes

    onDateChanged: root.today = Sky.daySeed()
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
       * pixel, and at these speeds it is nearly always the second: the moons
       * cover a few pixels a second and the outermost star a fraction of that.
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

      /**
       * Tonight, on this screen.
       *
       * The day and the monitor together, so that both hold: a new sky every
       * morning, and two screens that are one evening rather than one picture
       * printed twice. Re-rolled when `today` moves, which is at midnight and
       * when a lid comes up on a different date.
       */
      readonly property var plan: Sky.plan(panel.seed ^ root.today, root.palette.hues, panel.width / Math.max(1, panel.height))

      ScreenMoveRemap {
        id: remapGuard

        window: panel
      }

      // Everything that is actually drawn, which is next door in `Scene.qml`
      // because none of it needs to know about Wayland. That split is what
      // lets `preview.qml` render any day of this offscreen.
      Scene {
        anchors.fill: parent
        elapsed: panel.elapsed
        palette: root.palette
        plan: panel.plan
        running: panel.live
        seed: panel.seed
      }
    }
  }
}
