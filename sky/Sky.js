// Where the stars go, worked out once and the same every time.
//
// Pure arithmetic, no QML in it, so the whole of it runs under node and the
// tests are `./run-tests` rather than a screenshot and a squint. QML picks it
// up with `import "Sky.js" as Sky`; node picks it up through the guarded
// `module.exports` at the bottom, which QML's engine steps over because it has
// no `module` to find.

/**
 * A stream of numbers from a seed, which is mulberry32.
 *
 * Small enough to read, and without the short cycles and visible lattice that
 * make a hand rolled `sin(i) * 43758` sit its stars on diagonal lines. A
 * wallpaper is looked at for a long time and a lattice in it is the sort of
 * thing somebody notices in month two and cannot stop seeing.
 */
function rng(seed) {
  var t = (seed >>> 0) || 1;

  return function () {
    t = (t + 0x6d2b79f5) >>> 0;
    var x = Math.imul(t ^ (t >>> 15), 1 | t);
    x = (x + Math.imul(x ^ (x >>> 7), 61 | x)) ^ x;
    return ((x ^ (x >>> 14)) >>> 0) / 4294967296;
  };
}

/**
 * A number out of a name, which is FNV-1a.
 *
 * Monitors are named and skies are seeded, so this is how a laptop and the
 * screen beside it get two different fields of stars instead of the same one
 * twice. The same monitor gets the same sky back after a reboot, which is the
 * half of it that matters: a wallpaper should be somewhere, not a fresh roll
 * every login.
 */
function hash(name) {
  var text = String(name);
  var h = 2166136261;

  for (var i = 0; i < text.length; i++) {
    h ^= text.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }

  return h >>> 0;
}

/**
 * `count` stars over a disc of radius `reach`, centred on nothing.
 *
 * Evenly over the area, which is what the square root is for. Drawing the
 * radius straight from the stream puts half the stars inside the middle
 * quarter of the disc and the sky comes out as a bullseye with a bare rim.
 * That is the one piece of arithmetic here worth getting right and the reason
 * this file is tested at all.
 *
 * A disc and not the screen's own rectangle, because the field turns: what a
 * screen shows is a bite out of this disc and the bite is only even if the
 * whole disc is. Coordinates come back relative to the centre, so the caller
 * puts the pole where it wants it and the stars follow.
 *
 * The sizes are squeezed towards nothing on purpose. A real sky is mostly dust
 * with a handful of bright ones in it, and an even spread of sizes reads as
 * confetti.
 */
function field(count, seed, reach) {
  var roll = rng(seed);
  var stars = [];

  for (var i = 0; i < count; i++) {
    var radius = reach * Math.sqrt(roll());
    var angle = 2 * Math.PI * roll();

    stars.push({
      x: radius * Math.cos(angle),
      y: radius * Math.sin(angle),
      size: 0.7 + 1.9 * Math.pow(roll(), 2.4),
      dim: 0.3 + 0.7 * roll(),
      // A twelfth of them breathe. Every star doing it is a fairy light
      // string, and it is also two hundred moving parts rather than fifteen.
      twinkle: roll() < 0.12,
      beat: 2400 + Math.floor(4600 * roll()),
      // Where in its own breath a star starts. Without it they all begin at the
      // same brightness and the sky pulses as one thing on first sight.
      phase: 2 * Math.PI * roll(),
    });
  }

  return stars;
}

/**
 * How far a pole has to reach to cover a screen from where it is standing.
 *
 * The pole is off the corner of the screen rather than in the middle of it, so
 * the far corner is what decides the radius. Anything shorter and the turn
 * brings the empty outside of the disc across the desktop.
 */
function reach(width, height, poleX, poleY) {
  var far = 0;

  for (var i = 0; i < 4; i++) {
    var dx = (i % 2 ? width : 0) - poleX;
    var dy = (i < 2 ? 0 : height) - poleY;
    far = Math.max(far, Math.sqrt(dx * dx + dy * dy));
  }

  return far;
}

if (typeof module !== "undefined") {
  module.exports = { field: field, hash: hash, reach: reach, rng: rng };
}
