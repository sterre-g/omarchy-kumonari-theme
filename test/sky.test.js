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
