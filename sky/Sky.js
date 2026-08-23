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

/**
 * One colour out of whatever a theme wrote on the right of the equals sign.
 *
 * Omarchy's own themes are not consistent about this. Most write `"#8ab4ff"`,
 * some write `"rgb(1e1e1e)"` or `"rgba(26a269ee)"`, and a few keys hold a whole
 * gradient: `"rgba(f23888ee) rgba(67dd82aa) 35deg"`. The first colour in the
 * value is the one taken, since a key holding two is describing a ramp and its
 * first stop is as good a representative as any.
 *
 * Anything else comes back null rather than black. A theme saying `mode =
 * "dark"` is not offering a colour, and a black one silently joining the
 * palette is a dead cloud nobody can see and nobody can explain.
 */
function readColor(value) {
  var text = String(value == null ? "" : value).trim().replace(/^["']|["']$/g, "");
  var hit = text.match(/#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})\b/) ||
    text.match(/\brgba?\(\s*([0-9a-fA-F]{6})(?:[0-9a-fA-F]{2})?\s*\)/);

  if (!hit) return null;

  var digits = hit[1];
  if (digits.length === 3) {
    digits = digits[0] + digits[0] + digits[1] + digits[1] + digits[2] + digits[2];
  }

  return "#" + digits.toLowerCase();
}

/**
 * A theme's `colors.toml`, as a map of the keys that name a colour.
 *
 * Every one of these files is flat, so this is a line parser rather than a TOML
 * one, and a `[section]` header ends the reading rather than being walked into:
 * a key under a section is that section's, and taking it as top level would put
 * some panel's border colour in the sky.
 */
function parsePalette(text) {
  var values = {};
  var lines = String(text || "").split("\n");

  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].trim();

    if (!line || line[0] === "#") continue;
    if (line[0] === "[") break;

    var at = line.indexOf("=");
    if (at < 0) continue;

    var color = readColor(line.slice(at + 1));
    if (color) values[line.slice(0, at).trim()] = color;
  }

  return values;
}

/** A hex colour as hue, saturation and lightness, each 0 to 1. */
function toHsl(hex) {
  var n = parseInt(String(hex).replace("#", ""), 16);
  var r = ((n >> 16) & 255) / 255;
  var g = ((n >> 8) & 255) / 255;
  var b = (n & 255) / 255;
  var hi = Math.max(r, g, b);
  var lo = Math.min(r, g, b);
  var l = (hi + lo) / 2;
  var d = hi - lo;

  if (!d) return { h: 0, s: 0, l: l };

  var s = l > 0.5 ? d / (2 - hi - lo) : d / (hi + lo);
  var h;

  if (hi === r) h = ((g - b) / d + (g < b ? 6 : 0)) / 6;
  else if (hi === g) h = ((b - r) / d + 2) / 6;
  else h = ((r - g) / d + 4) / 6;

  return { h: h, s: s, l: l };
}

/** And back again. */
function fromHsl(h, s, l) {
  h = ((h % 1) + 1) % 1;
  s = Math.min(1, Math.max(0, s));
  l = Math.min(1, Math.max(0, l));

  var c = (1 - Math.abs(2 * l - 1)) * s;
  var x = c * (1 - Math.abs(((h * 6) % 2) - 1));
  var m = l - c / 2;
  var at = Math.floor(h * 6) % 6;
  var rgb = [
    [c, x, 0], [x, c, 0], [0, c, x], [0, x, c], [x, 0, c], [c, 0, x],
  ][at];

  var out = "#";
  for (var i = 0; i < 3; i++) {
    var byte = Math.round((rgb[i] + m) * 255);
    out += (byte < 16 ? "0" : "") + byte.toString(16);
  }

  return out;
}

/**
 * A theme's colour, made bright enough to be gas.
 *
 * The hue is the theme's and is never touched, because the hue is the whole of
 * what makes a palette recognisable. What moves is saturation and lightness,
 * into a band a cloud can actually be seen in.
 *
 * Without this the sky is only as visible as the theme is bold. Japan Night's
 * palette sits around 15% saturation and Vantablack's is nearly black, and both
 * of them drawn honestly at 12% opacity over a dark wallpaper are nothing at
 * all. Lifting them keeps the theme's character and gives the gas something to
 * be made of.
 *
 * A grey stays grey. A colour with no hue to preserve has nothing this can do
 * for it, and saturating one invents a hue the theme never chose.
 */
/** The same hue, held down to a chosen saturation and lightness. */
function sink(hex, sat, l) {
  var hsl = toHsl(hex);

  return fromHsl(hsl.h, hsl.s < 0.05 ? 0 : sat, l);
}

function lift(hex, floor, low, high) {
  var hsl = toHsl(hex);

  if (hsl.s < 0.05) return fromHsl(hsl.h, 0, Math.min(high, Math.max(low, hsl.l)));

  return fromHsl(hsl.h, Math.max(floor, Math.min(0.85, hsl.s)), Math.min(high, Math.max(low, hsl.l)));
}

/** How far apart two hues are on the circle, 0 to 0.5. */
function apart(a, b) {
  var d = Math.abs(a - b) % 1;
  return d > 0.5 ? 1 - d : d;
}

/**
 * The colours this sky is allowed to be, out of the theme the desktop wears.
 *
 * The point of reading the theme at all: the sky is not blue because somebody
 * typed blue, it is blue because Kumonari's `colors.toml` says so, and a theme
 * whose palette is red and gold gets a red and gold sky without a line changing
 * here.
 *
 * `values` is a parsed `colors.toml`, which may be missing or nearly empty: a
 * theme is only obliged to have colours at all, and one of mine is an empty
 * directory. So `fallback` carries what the shell knows regardless, its accent
 * and foreground, and that alone is enough to build a sky out of.
 *
 * Near-duplicates are dropped. Plenty of themes set `blue` and `accent` to the
 * same value, and two clouds of one colour is one cloud that looks like a
 * mistake. If too few survive, the rest are spun off the ones that did, which
 * is a theme getting analogous colours it never named rather than a sky with
 * one cloud in it.
 *
 * A theme with no colour in it keeps having none. Vantablack and an empty
 * directory both arrive here as grey, and grey spun round the hue circle would
 * hand a black-and-white desktop a green nebula it never asked for, so a
 * colourless palette is filled out in lightness instead and stays a grey sky.
 */
function palette(values, fallback) {
  var named = ["magenta", "cyan", "blue", "green", "red", "orange", "yellow", "accent"];
  var seen = values || {};
  var back = fallback || {};
  var hues = [];

  function offer(hex) {
    if (!hex) return;

    var lifted = lift(hex, 0.45, 0.46, 0.66);
    var hue = toHsl(lifted).h;

    for (var i = 0; i < hues.length; i++) {
      if (apart(toHsl(hues[i]).h, hue) < 0.06) return;
    }

    hues.push(lifted);
  }

  for (var i = 0; i < named.length; i++) offer(seen[named[i]]);

  offer(back.accent);

  // The foreground last and only when the sky would otherwise be bare. It is
  // near enough to white in most themes to come out as a grey cloud, which is
  // a fair last resort and a poor third colour.
  if (hues.length < 2) offer(back.foreground);

  var base = hues.length ? toHsl(hues[0]) : { h: 0.6, s: 0.5 };

  for (var turn = 1; hues.length < 3; turn++) {
    hues.push(base.s < 0.05
      // Nothing to rotate, so the palette opens up in lightness and the sky
      // stays as colourless as the theme that asked for it.
      ? fromHsl(base.h, 0, 0.4 + 0.12 * turn)
      // A hue every fifth of the circle, far enough apart to read as separate
      // gas and near enough to stay one palette.
      : fromHsl(base.h + turn * 0.2, 0.5, 0.56));
  }

  var ground = readColor(seen.background) || back.background || "#05070f";

  return {
    // The theme's own background, untouched, for anything that needs to know
    // what this sky is being drawn over.
    dark: ground,
    // The body of a planet is that same ground lifted just off itself, so a
    // world reads as lit rather than as a hole cut in the wallpaper.
    ground: lift(ground, 0.3, 0.14, 0.22),
    hues: hues,
    ink: readColor(seen.foreground) || back.foreground || "#c9d2ec",
  };
}

/**
 * Which day it is, as a seed.
 *
 * The local calendar day, because a wallpaper belongs to the day the person
 * looking at it is having. A day is the unit for the same reason it is in
 * codincod's sea: one fixed seed and the sky never changes, so whatever that
 * roll happened to give is all anybody ever sees, and a fresh one per boot
 * leaves nowhere to come back to.
 */
function daySeed(date) {
  var when = date || new Date();

  return hash(when.getFullYear() + "-" + (when.getMonth() + 1) + "-" + when.getDate());
}

/**
 * Everything the sky is today, on one screen.
 *
 * Rolled here rather than in QML so that a day can be tested without waiting
 * for one. The seed carries the date and the monitor both: the day decides what
 * kind of sky it is and the monitor decides where things sit on it, so two
 * screens are one evening rather than the same picture twice.
 */
function plan(seed, hues, aspect) {
  var roll = rng(seed);
  var wide = aspect || 1.6;

  // Where today starts in the palette. Without it the first hue is the loudest
  // cloud every single day, and a theme with seven colours in it would still
  // have one sky.
  var turn = Math.floor(roll() * hues.length);
  function hue(step) {
    return hues[(turn + step) % hues.length];
  }

  var clouds = 2 + Math.floor(roll() * 3);
  var nebulae = [];
  for (var i = 0; i < clouds; i++) {
    nebulae.push({
      hue: hue(i),
      ink: 0.11 + 0.1 * roll(),
      period: 47000 + Math.floor(roll() * 55000),
      reach: 0.28 + 0.26 * roll(),
      squash: 0.38 + 0.4 * roll(),
      sway: 26 + Math.floor(roll() * 34),
      tilt: -30 + roll() * 60,
      wander: 94000 + Math.floor(roll() * 70000),
      x: 0.1 + 0.8 * roll(),
      y: 0.08 + 0.84 * roll(),
    });
  }

  var wanted = 1 + Math.floor(roll() * 3);
  var worlds = [];

  for (var w = 0; w < wanted; w++) {
    var span = 0.07 + 0.11 * roll();
    var at = null;

    // Kept out of the top left, where the bar and the first windows are, and
    // off each other: two worlds touching is a moon of the wrong planet.
    for (var attempt = 0; attempt < 24 && !at; attempt++) {
      var here = { x: 0.22 + 0.64 * roll(), y: 0.24 + 0.58 * roll() };
      var clear = true;

      for (var other = 0; other < worlds.length; other++) {
        var dx = (here.x - worlds[other].x) * wide;
        var dy = here.y - worlds[other].y;
        if (Math.sqrt(dx * dx + dy * dy) < (span + worlds[other].span) * 2.2) clear = false;
      }

      if (clear) at = here;
    }

    if (!at) continue;

    var rings = roll() < 0.55;
    var moons = [];
    var wantedMoons = Math.floor(roll() * 3);

    for (var m = 0; m < wantedMoons; m++) {
      moons.push({
        away: 1.35 + 0.5 * m + 0.4 * roll(),
        lit: roll() < 0.5,
        period: 96000 + Math.floor(roll() * 190000),
        phase: roll(),
        size: 0.08 + 0.05 * roll(),
        tilt: 0.1 + 0.3 * roll(),
      });
    }

    var bands = [];
    var wantedBands = roll() < 0.45 ? 2 + Math.floor(roll() * 4) : 0;

    for (var b = 0; b < wantedBands; b++) {
      bands.push({
        at: -0.72 + 1.44 * roll(),
        light: roll() < 0.5,
        thick: 0.05 + 0.09 * roll(),
      });
    }

    var lit = hue(w + 1)

    worlds.push({
      bands: bands,
      // The body is that same colour taken right down, so a world is lit by its
      // own star rather than every planet in the sky being one shade of the
      // theme's background. Saturation comes down with the lightness: a fully
      // saturated small disc reads as a sticker rather than as something a long
      // way off, and the light rim the gradient adds pushes it further still.
      body: sink(lit, 0.42, 0.17),
      hue: lit,
      moons: moons,
      rings: rings,
      ringTilt: 0.12 + 0.22 * roll(),
      span: span,
      spin: 150000 + Math.floor(roll() * 130000),
      x: at.x,
      y: at.y,
    });
  }

  // One thing a day that is not a planet, and most days none, so that the day
  // it turns up it is worth looking at rather than furniture.
  var luck = roll();
  var feature = luck < 0.22 ? "galaxy" : luck < 0.4 ? "belt" : "none";

  return {
    belt: {
      at: { x: 0.2 + 0.6 * roll(), y: 0.2 + 0.6 * roll() },
      count: 60 + Math.floor(roll() * 70),
      period: 300000 + Math.floor(roll() * 240000),
      reach: 0.3 + 0.2 * roll(),
      tilt: -24 + roll() * 48,
    },
    feature: feature,
    nebulae: nebulae,
    galaxy: {
      at: { x: 0.14 + 0.72 * roll(), y: 0.12 + 0.5 * roll() },
      hue: hue(2),
      lean: -40 + roll() * 80,
      reach: 0.1 + 0.09 * roll(),
    },
    // A little more or less sky each night, which is the weather a place with
    // no weather gets.
    stars: 0.82 + 0.36 * roll(),
    turn: turn,
    worlds: worlds,
  };
}

if (typeof module !== "undefined") {
  module.exports = {
    apart: apart,
    daySeed: daySeed,
    field: field,
    fromHsl: fromHsl,
    hash: hash,
    lift: lift,
    palette: palette,
    parsePalette: parsePalette,
    plan: plan,
    reach: reach,
    readColor: readColor,
    rng: rng,
    sink: sink,
    toHsl: toHsl,
  };
}
