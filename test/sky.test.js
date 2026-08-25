// The arithmetic behind the sky, checked without a compositor in the room.
//
// Node reaches Sky.js through the guarded `module.exports` at the bottom of it,
// which QML's engine steps over. Run with `./run-tests`.

const assert = require("node:assert/strict");
const Sky = require("../sky/Sky.js");

const checks = [];

function test(name, body) {
  checks.push([name, body]);
}

test("the same seed is the same stream", () => {
  const a = Sky.rng(42);
  const b = Sky.rng(42);

  for (let i = 0; i < 50; i++) {
    assert.equal(a(), b(), "two streams off one seed diverged");
  }
});

test("different seeds are different streams", () => {
  const a = Sky.rng(42);
  const b = Sky.rng(43);

  assert.notEqual(a(), b());
});

test("the stream stays inside the unit interval", () => {
  const roll = Sky.rng(7);

  for (let i = 0; i < 20000; i++) {
    const value = roll();
    assert.ok(value >= 0 && value < 1, `left the unit interval at ${value}`);
  }
});

test("a seed of zero still turns over", () => {
  // A zeroed state is a fixed point for this generator, and a monitor whose
  // name happens to hash to zero would otherwise get one number forever.
  const roll = Sky.rng(0);
  const first = roll();

  assert.notEqual(first, roll());
});

test("a name is the same number every time", () => {
  assert.equal(Sky.hash("eDP-1"), Sky.hash("eDP-1"));
  assert.notEqual(Sky.hash("eDP-1"), Sky.hash("HDMI-A-1"));
});

test("a name hashes to something a seed can be", () => {
  for (const name of ["eDP-1", "HDMI-A-1", "", "DP-3", "sky"]) {
    const seed = Sky.hash(name);

    assert.ok(Number.isInteger(seed), `${name} did not hash to an integer`);
    assert.ok(seed >= 0 && seed <= 0xffffffff, `${name} hashed outside 32 bits`);
  }
});

test("a field is the size it was asked for and no star leaves the disc", () => {
  const reach = 900;
  const stars = Sky.field(400, 11, reach);

  assert.equal(stars.length, 400);

  for (const star of stars) {
    const out = Math.sqrt(star.x * star.x + star.y * star.y);

    assert.ok(out <= reach + 1e-9, `a star got ${out} from the pole`);
    assert.ok(star.size > 0, "a star has no size");
    assert.ok(star.dim > 0 && star.dim <= 1, `dim left the range at ${star.dim}`);
    assert.ok(star.beat >= 2400, "a twinkle faster than the range allows");
    assert.equal(typeof star.twinkle, "boolean");
    assert.ok(star.phase >= 0 && star.phase < 2 * Math.PI, `phase left the circle at ${star.phase}`);
  }
});

test("the same field comes back for the same seed", () => {
  const a = Sky.field(120, 5, 500);
  const b = Sky.field(120, 5, 500);

  assert.deepEqual(a, b);
});

test("stars are spread over the area and not along the radius", () => {
  // Half a disc's area lies inside reach/sqrt(2). Sampling the radius straight
  // out of the stream instead of through a square root would put about 71% of
  // them inside that circle and draw a bullseye, so this is the check that
  // catches the one mistake this file exists to avoid.
  const reach = 1000;
  const half = reach / Math.SQRT2;
  const stars = Sky.field(20000, 3, reach);
  const inside = stars.filter((star) => Math.hypot(star.x, star.y) <= half).length;
  const share = inside / stars.length;

  assert.ok(Math.abs(share - 0.5) < 0.02, `${share} of the stars fell in the inner half`);
});

test("a field of nothing is empty rather than broken", () => {
  assert.deepEqual(Sky.field(0, 1, 100), []);
});

test("reach covers the farthest corner from the pole", () => {
  // A pole off the bottom left, which is where these actually sit. Compared
  // against the same sqrt the implementation uses rather than against
  // Math.hypot, which is more careful and disagrees in the last bit.
  const far = Sky.reach(2560, 1440, -640, 1944);
  const corner = Math.sqrt(3200 * 3200 + 1944 * 1944);

  assert.ok(far >= corner, "the far corner is outside the disc");

  for (const [x, y] of [[0, 0], [2560, 0], [0, 1440], [2560, 1440]]) {
    const out = Math.sqrt((x + 640) * (x + 640) + (y - 1944) * (y - 1944));

    assert.ok(far >= out, `the corner at ${x},${y} is outside the disc`);
  }
});

test("reach is measured from the pole and not from the middle", () => {
  // A pole dead centre of a square is equidistant from all four corners, which
  // is the one case where a wrong implementation and a right one agree, so this
  // pins the asymmetric case beside it.
  assert.ok(Math.abs(Sky.reach(100, 100, 0, 0) - Math.sqrt(20000)) < 1e-9);
  assert.ok(Math.abs(Sky.reach(100, 100, 50, 50) - Math.sqrt(5000)) < 1e-9);
});

test("a colour is read out of every shape a theme writes one in", () => {
  assert.equal(Sky.readColor('"#8ab4ff"'), "#8ab4ff");
  assert.equal(Sky.readColor("#ABC"), "#aabbcc");
  assert.equal(Sky.readColor('"rgb(1e1e1e)"'), "#1e1e1e");
  assert.equal(Sky.readColor('"rgba(26a269ee)"'), "#26a269");
  // A gradient is two colours and a angle; its first stop stands for it.
  assert.equal(Sky.readColor('"rgba(f23888ee) rgba(67dd82aa) 35deg"'), "#f23888");
});

test("a value that is not a colour is not a colour", () => {
  // The trap this exists for: `mode = "dark"` coming back as black and joining
  // the palette as a cloud nobody can see.
  for (const value of ['"dark"', '"light"', "", "   ", '"Yaru-blue-dark"']) {
    assert.equal(Sky.readColor(value), null, `${value} was read as a colour`);
  }
});

test("a palette is read off a flat file and stops at a section", () => {
  const values = Sky.parsePalette([
    "# a comment",
    'mode = "dark"',
    'accent = "#8ab4ff"',
    'red = "#f2718f"',
    "",
    "[bar]",
    'text = "#ffffff"',
  ].join("\n"));

  assert.equal(values.accent, "#8ab4ff");
  assert.equal(values.red, "#f2718f");
  assert.equal(values.mode, undefined, "a mode is not a colour");
  assert.equal(values.text, undefined, "a key under a section is that section's");
});

test("no file at all parses to nothing rather than throwing", () => {
  assert.deepEqual(Sky.parsePalette(""), {});
  assert.deepEqual(Sky.parsePalette(null), {});
});

test("a colour survives the trip through HSL", () => {
  for (const hex of ["#8ab4ff", "#f23888", "#000000", "#ffffff", "#7daea3", "#282828"]) {
    const hsl = Sky.toHsl(hex);

    assert.equal(Sky.fromHsl(hsl.h, hsl.s, hsl.l), hex, `${hex} did not come back`);
  }
});

test("lifting a colour keeps its hue and only moves how bright it is", () => {
  // The whole promise of following a theme: the hue is the theme's identity and
  // is never touched, so a red theme cannot come back green however dark it was.
  // A degree of slack, because the trip out to eight-bit hex and back moves a
  // hue by up to about a third of one. A hue that actually changed moves by
  // tens of degrees, so this still catches the failure it is here for.
  const slack = 1 / 360;

  for (const hex of ["#2b5e8f", "#b9968f", "#7daea3", "#f23888", "#294857"]) {
    const before = Sky.toHsl(hex);
    const after = Sky.toHsl(Sky.lift(hex, 0.45, 0.46, 0.66));

    assert.ok(Sky.apart(before.h, after.h) < slack, `${hex} changed hue`);
    // The same eight-bit slack on the way back out, one channel step of it.
    const step = 1 / 255;

    assert.ok(after.s >= 0.45 - step, `${hex} stayed too washed out at ${after.s}`);
    assert.ok(after.l >= 0.46 - step && after.l <= 0.66 + step, `${hex} left the band at ${after.l}`);
  }
});

test("a grey stays grey when lifted", () => {
  // Saturating a grey invents a hue the theme never chose, which is how a
  // black-and-white desktop ends up with a green nebula on it.
  assert.equal(Sky.toHsl(Sky.lift("#9b9b9b", 0.45, 0.46, 0.66)).s, 0);
  assert.equal(Sky.toHsl(Sky.sink("#9b9b9b", 0.42, 0.17)).s, 0);
});

test("sinking a colour holds it where it was told", () => {
  const hsl = Sky.toHsl(Sky.sink("#f23888", 0.42, 0.17));

  assert.ok(Math.abs(hsl.s - 0.42) < 0.02, `saturation came out at ${hsl.s}`);
  assert.ok(Math.abs(hsl.l - 0.17) < 0.02, `lightness came out at ${hsl.l}`);
});

const shell = { accent: "#8ab4ff", background: "#0a0e1a", foreground: "#c9d2ec" };

test("a full palette yields several hues that are not each other", () => {
  const full = Sky.palette(Sky.parsePalette([
    'accent = "#8ab4ff"',
    'blue = "#8ab4ff"',
    'magenta = "#bb8cf5"',
    'cyan = "#63dcd4"',
    'green = "#6dd6ab"',
    'red = "#f2718f"',
  ].join("\n")), shell);

  assert.ok(full.hues.length >= 3, `only ${full.hues.length} hues survived`);

  for (let i = 0; i < full.hues.length; i++) {
    for (let j = i + 1; j < full.hues.length; j++) {
      const gap = Sky.apart(Sky.toHsl(full.hues[i]).h, Sky.toHsl(full.hues[j]).h);

      assert.ok(gap >= 0.06, `two hues sat ${gap} apart, which is one cloud twice`);
    }
  }
});

test("a theme with no colours at all still builds a sky", () => {
  // Not hypothetical: one of the themes on this machine is an empty directory.
  const bare = Sky.palette({}, shell);

  assert.ok(bare.hues.length >= 3);
  assert.ok(bare.dark && bare.ground && bare.ink);

  for (const hex of bare.hues) {
    assert.match(hex, /^#[0-9a-f]{6}$/, `${hex} is not a colour`);
  }
});

test("a colourless theme is filled out in lightness, not in invented hues", () => {
  const grey = Sky.palette({}, { accent: "#9b9b9b", background: "#000000", foreground: "#9b9b9b" });

  for (const hex of grey.hues) {
    assert.ok(Sky.toHsl(hex).s < 0.05, `${hex} is a colour a black-and-white theme never asked for`);
  }

  const lightnesses = grey.hues.map((hex) => Sky.toHsl(hex).l);

  assert.equal(new Set(lightnesses).size, lightnesses.length, "the greys are all the same grey");
});

test("the day is the same all day and different tomorrow", () => {
  const morning = Sky.daySeed(new Date(2026, 7, 23, 6, 12));
  const midnight = Sky.daySeed(new Date(2026, 7, 23, 23, 59));
  const after = Sky.daySeed(new Date(2026, 7, 24, 0, 1));

  assert.equal(morning, midnight, "the sky changed during the day");
  assert.notEqual(midnight, after, "the sky did not change overnight");
});

test("a month of days are mostly different skies", () => {
  const seen = new Set();

  for (let day = 1; day <= 28; day++) seen.add(Sky.daySeed(new Date(2026, 7, day)));

  assert.equal(seen.size, 28, "two days in one month drew the same seed");
});

const hues = Sky.palette(Sky.parsePalette('accent = "#8ab4ff"\nmagenta = "#bb8cf5"\ncyan = "#63dcd4"\nred = "#f2718f"'), shell).hues;

test("a plan carries everything the scene reads off it", () => {
  // The regression this exists for: `worlds` and `nebulae` were built and then
  // left out of the returned object, so the sky rendered as stars and nothing
  // else and the failure looked like a QML problem for an hour.
  const today = Sky.plan(1234, hues, 1.6);

  for (const key of ["belt", "feature", "galaxy", "nebulae", "stars", "turn", "worlds"]) {
    assert.ok(today[key] !== undefined, `a plan with no ${key} in it`);
  }

  assert.ok(Array.isArray(today.worlds) && today.worlds.length >= 1, "a sky with no planets");
  assert.ok(Array.isArray(today.nebulae) && today.nebulae.length >= 2, "a sky with no gas");
  assert.ok(["belt", "galaxy", "none"].includes(today.feature), `an unknown feature ${today.feature}`);
});

test("the same day and screen give the same sky back", () => {
  assert.deepEqual(Sky.plan(99, hues, 1.6), Sky.plan(99, hues, 1.6));
});

test("two screens on one day are not the same picture twice", () => {
  const left = Sky.plan(Sky.hash("eDP-1") ^ 5150, hues, 1.6);
  const right = Sky.plan(Sky.hash("HDMI-A-1") ^ 5150, hues, 1.6);

  assert.notDeepEqual(left, right);
});

test("worlds stay on the screen and off each other", () => {
  const wide = 1.6;

  for (let seed = 0; seed < 400; seed++) {
    const today = Sky.plan(seed, hues, wide);

    for (const world of today.worlds) {
      assert.ok(world.x > 0.1 && world.x < 0.95, `a world sat at x ${world.x}`);
      assert.ok(world.y > 0.1 && world.y < 0.95, `a world sat at y ${world.y}`);
      assert.ok(world.span > 0.05 && world.span < 0.2, `a world was ${world.span} of the screen`);
      assert.match(world.body, /^#[0-9a-f]{6}$/);
    }

    for (let i = 0; i < today.worlds.length; i++) {
      for (let j = i + 1; j < today.worlds.length; j++) {
        const a = today.worlds[i];
        const b = today.worlds[j];
        const dx = (a.x - b.x) * wide;
        const dy = a.y - b.y;

        assert.ok(
          Math.sqrt(dx * dx + dy * dy) >= (a.span + b.span) * 2.2,
          `two worlds overlapped on seed ${seed}`
        );
      }
    }
  }
});

test("every world carries the seed its detail is drawn from", () => {
  // Moons and weather are rolled in `sky.frag` off this number rather than
  // planned here, so what this file still owes them is a seed that is a whole
  // number in range, the same one back for the same night, and not the same one
  // for two worlds on one night, which would be one planet's moons twice.
  for (let seed = 0; seed < 200; seed++) {
    const seen = new Set();

    for (const world of Sky.plan(seed, hues, 1.6).worlds) {
      assert.ok(Number.isInteger(world.seed), `a world's seed was ${world.seed}`);
      assert.ok(world.seed >= 0 && world.seed < 65536);
      assert.ok(!seen.has(world.seed), `two worlds shared a seed on ${seed}`);
      seen.add(world.seed);
    }
  }
});

test("a night is sometimes bare and sometimes has something in it", () => {
  // Half of them bare, and the other half split between the two. A feature so
  // rare that a fortnight goes by without one is not restraint, it is a feature
  // nobody knows the sky has.
  const seen = { galaxy: 0, belt: 0, none: 0 };

  for (let seed = 0; seed < 600; seed++) seen[Sky.plan(seed, hues, 1.6).feature] += 1;

  assert.ok(seen.galaxy > 80, `only ${seen.galaxy} galaxies in 600 nights`);
  assert.ok(seen.belt > 80, `only ${seen.belt} belts in 600 nights`);
  assert.ok(seen.none > 200, `only ${seen.none} plain nights in 600`);
});

test("a day picks its own corner of the palette", () => {
  // Otherwise the first hue is the loudest cloud every single day and a theme
  // with seven colours in it still only ever has one sky.
  const turns = new Set();

  for (let seed = 0; seed < 200; seed++) turns.add(Sky.plan(seed, hues, 1.6).turn);

  assert.ok(turns.size > 1, "every day started at the same colour");
});

let failed = 0;

// Straight to the stream rather than through console. A console call in a
// committed file is a debug leftover to most pre-commit hooks, and this is a
// test runner's output rather than something somebody forgot to take out.
function say(line) {
  process.stdout.write(line + "\n");
}

for (const [name, body] of checks) {
  try {
    body();
    say(`ok   ${name}`);
  } catch (error) {
    failed++;
    say(`FAIL ${name}`);
    say(`     ${error.message}`);
  }
}

say(`\n${checks.length - failed}/${checks.length} passed`);
process.exit(failed ? 1 : 0);
