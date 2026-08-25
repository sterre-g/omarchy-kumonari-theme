#version 440

// The sky, drawn on the card.
//
// Every star, cloud, world and moon in here is arithmetic on the pixel being
// drawn. There is no scene to walk, no item per moving part, and no binding to
// re-evaluate. What the processor does per frame is add one number to one
// uniform.
//
// ## Why it stopped being a scene of objects
//
// The QML version put a `Rectangle` on the desktop for every star and drove all
// of them from one timer, which was already the cheap way round: an animation
// per moving part cost about 10% of a core, and rationing the frames to five a
// second brought it under 1%.
//
// What five frames a second buys is a sky that steps. Measured on this desk,
// the fast half of the old scene moved several pixels between frames and
// hopped, while the slow half moved a tenth of one and looked painted on. No
// single rate is right for both, because the speeds up there are eighty times
// apart.
//
// So the frames stopped being the thing to ration. Measured against the scene
// this replaces, at the same rate: 12.0% of a core in the shell against 3.6%,
// with the compositor unchanged. Nearly all of what was saved was Qt walking a
// scene graph, and none of that work has to happen on a processor.
//
// ## What is still rationed
//
// Frames, but by speed rather than by clock. Nothing here moves faster than
// about eight pixels a second, which is under one pixel between frames at the
// rate `Field.qml` idles at, and motion under a pixel is motion nobody can see
// stepping. The exception is a meteor, which crosses in about a second and gets
// the card's own rate for as long as it is falling. See the clock in
// `Field.qml`.
//
// Coordinates are pixels from the top left, which is the frame `Sky.js` plans
// in, so a position out of the plan is passed straight through.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

// Qt builds this block by reflection and fills `qt_Matrix` and `qt_Opacity`
// itself; every name after those two is a property on the `ShaderEffect`.
//
// All of it is vec4 on purpose. std140 pads a lone float out to sixteen bytes
// anyway, so packing four to a line costs nothing and spares the next person
// working out why a stray float moved everything under it.
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;

    // xy: the surface in px. z: seconds. w: how far through the night, 0 to 1.
    vec4 frame;
    // rgb: what stars are drawn in. a: how much sky there is tonight.
    vec4 ink;

    // Three clouds. rgb is the hue, a is how much of it there is; an `a` of
    // zero is a cloud the day did not roll, which costs its arithmetic and
    // paints nothing. That is cheaper than a branch and far cheaper than a
    // second shader.
    vec4 gas0;
    vec4 gas1;
    vec4 gas2;
    // Where each sits. xy: middle, as a share of the surface. z: reach in px.
    // w: how much of its height it keeps.
    vec4 at0;
    vec4 at1;
    vec4 at2;

    // Three worlds. xy: middle in px. z: the body across, in px. w: the seed
    // its moons and its weather are rolled from. A `z` of zero is no world.
    vec4 world0;
    vec4 world1;
    vec4 world2;
    // rgb: the colour its own star lights it in. a: how flat the rings are
    // seen, and zero for a world without them.
    vec4 lit0;
    vec4 lit1;
    vec4 lit2;
    // rgb: the body itself. a: how long its weather takes to cross, in seconds.
    vec4 body0;
    vec4 body1;
    vec4 body2;

    // One thing a night that is not a world, and most nights none.
    // far:  xy middle px, z reach px, w lean in radians. z of zero is none.
    // belt: xy middle px, z reach px, w how flat it is seen.
    vec4 far;
    vec4 farHue;
    vec4 belt;
    vec4 beltHue;

    // A meteor, while one is falling. xy: where it started, in px. z: the angle
    // it falls at. w: the second it started, and a negative one is none.
    vec4 meteor;
};

const float TAU = 6.28318530718;

// One number out of two, and the reason the field is stable.
//
// A star is not stored anywhere: it is whatever this returns for the cell the
// pixel falls in. The same cell gives the same star on every frame, on every
// monitor and after a reboot, without a list of them ever existing.
float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

/** A hue turned round the circle, which is how the night changes colour. */
vec3 turnHue(vec3 c, float turn) {
    // Rodrigues about the grey axis, which is a hue rotation without the trip
    // through HSL and back and without the branch that trip needs.
    const vec3 k = vec3(0.57735);
    float a = turn * TAU;
    return c * cos(a) + cross(k, c) * sin(a) + k * dot(k, c) * (1.0 - cos(a));
}

/** A soft edged disc, feathered by about a pixel so nothing here has a stair on it. */
float disc(vec2 p, float r) {
    return smoothstep(r, r - 1.5, length(p));
}

// One depth of sky, turning about a pole off the corner of the screen.
//
// The plane is cut into cells and each cell holds at most one star, so a pixel
// only asks about the cell it is standing in. That is the whole trick: a field
// of any size costs the same handful of hashes as a field of one, which is why
// there is no longer a reason to count the stars.
//
// The pole is off the corner for the reason it was in the QML: near it a star
// crawls and out at the rim it drifts, which is parallax without a second
// mechanism for it.
vec3 depth(vec2 px, vec2 pole, float cell, float spin, float gain, float scale, vec3 tint, float t) {
    float a = t * spin;
    float s = sin(a);
    float c = cos(a);
    vec2 q = px - pole;
    q = vec2(q.x * c - q.y * s, q.x * s + q.y * c);

    vec2 grid = q / cell;
    vec2 id = floor(grid);
    vec2 f = fract(grid);

    // Most cells hold nothing, and that is what stops the field reading as a
    // lattice. One star per cell at the density this wants would put them on a
    // grid regular enough to see; leaving two cells in three empty and making
    // the cells smaller to compensate gives back the clumps and the gaps that
    // a field scattered over a disc had for free.
    if (hash21(id) < 0.68) return vec3(0.0);

    float roll = hash21(id + 5.7);

    // Held off the cell edges, so a star is never cut in half by the seam
    // between two cells and never lands touching its neighbour.
    vec2 seat = vec2(hash21(id + 11.3), hash21(id + 27.7)) * 0.6 + 0.2;

    // The same two curves the field in `Sky.js` used, so swapping the renderer
    // did not quietly restyle the sky. Sizes squeezed hard towards nothing,
    // because a real sky is mostly dust with a handful of bright ones in it and
    // an even spread of sizes reads as confetti; brightness spread evenly, so
    // the small ones are not all faint as well as small.
    float rad = (0.7 + 1.9 * pow(roll, 2.4)) * scale * 0.5;
    float dim = 0.3 + 0.7 * roll;
    float d = length(f - seat) * cell;

    // About a twelfth of them breathe, which is the share the QML settled on.
    // Every star doing it is a string of fairy lights.
    float beat = 1.0;
    if (roll > 0.88) {
        beat = 0.66 + 0.34 * sin(t * (0.55 + roll * 0.5) + roll * 40.0);
    }

    return tint * (smoothstep(rad, 0.0, d) * dim * gain * beat);
}

// A cloud of gas that breathes and drifts.
//
// The falloff is an exponent rather than a straight run to the edge, for the
// reason the QML's six gradient stops existed: alpha that gives out in a
// straight line leaves a ring the eye finds immediately and cannot then unsee.
//
// The two periods are deliberately not multiples of each other. Where they are,
// the pair lines up every so often and the cloud pulses on a beat, which is the
// one thing gas never does.
vec3 cloud(vec2 px, vec4 col, vec4 at, vec2 res, float t, float turn) {
    if (col.a <= 0.0) return vec3(0.0);

    float breath = 0.5 - 0.5 * cos(t * 0.019 + at.x * TAU);
    float drift = sin(t * 0.0071 + at.y * TAU) * at.z * 0.09;

    vec2 d = px - (at.xy * res + vec2(drift, drift * 0.35));
    d.y /= max(0.05, at.w);

    float reach = at.z * (1.0 + 0.22 * breath);
    float out_ = clamp(1.0 - length(d) / reach, 0.0, 1.0);

    return turnHue(col.rgb, turn) * (col.a * pow(out_, 2.6) * (0.55 + 0.45 * breath));
}

/**
 * Another galaxy, far enough off to be one smudge of light.
 *
 * Three squashed lights of different flatness stacked, which is all a spiral is
 * at this distance and cheaper than any texture of one would be.
 */
vec3 galaxy(vec2 px, vec4 at, vec4 col, float t) {
    if (at.z <= 0.0) return vec3(0.0);

    float a = at.w + t * 0.00035;
    float s = sin(a);
    float c = cos(a);
    vec2 p = px - at.xy;
    p = vec2(p.x * c - p.y * s, p.x * s + p.y * c);

    vec3 out_ = vec3(0.0);

    vec2 q = vec2(p.x, p.y / 0.20);
    out_ += col.rgb * (0.13 * pow(clamp(1.0 - length(q) / at.z, 0.0, 1.0), 2.2));

    q = vec2(p.x, p.y / 0.44);
    out_ += col.rgb * (0.10 * pow(clamp(1.0 - length(q) / (at.z * 0.62), 0.0, 1.0), 2.8));

    q = vec2(p.x, p.y / 0.80);
    out_ += min(col.rgb * 1.4, 1.0) * (0.30 * pow(clamp(1.0 - length(q) / (at.z * 0.20), 0.0, 1.0), 2.6));

    return out_;
}

/**
 * A belt of rubble, seen at enough of an angle to be an ellipse.
 *
 * Rock positions move; the orbit they move on does not. Turning the whole
 * ellipse instead was the first way and it is plainly wrong the moment you see
 * it, since a flat ellipse rotated a quarter turn stands on its end like a coin
 * on a table.
 *
 * Found rather than drawn: the pixel works out which angle round the ring it is
 * nearest, and asks whether that slot holds a rock. Sixty rocks and six hundred
 * cost the same.
 */
vec3 rubble(vec2 px, vec4 at, vec4 col, float t) {
    if (at.z <= 0.0) return vec3(0.0);

    vec2 p = px - at.xy;
    // Into a frame where the ellipse is a circle, so "which angle is this" is
    // one atan rather than a search.
    vec2 q = vec2(p.x, p.y / max(0.05, at.w));
    float r = length(q);

    if (r < at.z * 0.6 || r > at.z * 1.25) return vec3(0.0);

    const float SLOTS = 220.0;
    float turn = t / (600.0 + col.a * 400.0);
    float slot = q.x == 0.0 && q.y == 0.0 ? 0.0 : atan(q.y, q.x) / TAU;
    float here = (slot - turn) * SLOTS;

    vec3 out_ = vec3(0.0);

    // The slot this pixel is in and its two neighbours, since a rock sitting
    // near a slot edge reaches into the one next door.
    for (int i = -1; i <= 1; i++) {
        float id = floor(here) + float(i);
        float roll = hash21(vec2(id, 3.7));

        // Two slots in three are empty. Evenly spaced rocks on a clean ellipse
        // is a dotted line, and a dotted line is a diagram.
        if (roll < 0.34) continue;

        float ang = (id / SLOTS + turn) * TAU;
        // Squared towards the outside, so the belt is denser at its rim than at
        // its inner edge, which is how a shepherded ring actually sits.
        float away = at.z * (0.82 + 0.18 * pow(hash21(vec2(id, 8.1)), 0.6));
        vec2 seat = vec2(cos(ang) * away, sin(ang) * away);

        float size = 1.0 + 1.8 * hash21(vec2(id, 14.9));
        float dim = 0.25 + 0.6 * hash21(vec2(id, 21.3));

        out_ += col.rgb * (disc(q - seat, size) * dim);
    }

    return out_;
}

/**
 * A world, and everything that belongs to it.
 *
 * Built back to front, the way it has to be when there is one pixel and no
 * depth buffer: the haze, then the half of the ring that passes behind, then
 * the body with its weather on it, then the half that passes in front, then the
 * moons that are on the near side. Below the middle of an orbit is the near
 * side, since y points down.
 *
 * Weather and moons are rolled here from the seed the plan handed over, rather
 * than being sent one uniform each. Three worlds with three moons apiece is
 * fifty-odd numbers to push across for something the eye reads as "it has
 * moons", and the seed is the same roll either way.
 *
 * Returns the light it adds in `rgb`, and in `a` how much of the sky behind it
 * the body covers, which is the one thing up here that is not see-through.
 */
float world(vec2 px, vec4 at, vec4 lit, vec4 body, float t,
            out vec3 behind, out vec3 solid, out vec3 front) {
    behind = vec3(0.0);
    solid = vec3(0.0);
    front = vec3(0.0);
    if (at.z <= 0.0) return 0.0;

    float span = at.z;
    float R = span * 0.5;
    float seed = at.w;
    vec2 p = px - at.xy;

    // The haze it sits in, which is behind it. That word is the whole of this
    // paragraph: added to the body instead of sitting under it, a haze at a
    // tenth of the lit colour lifts the disc by about a third and every world
    // comes out a shade of its own star rather than a dark thing lit by one.
    // The QML said the same in one line, `z: -3`, and it was the first thing
    // lost in the port.
    float haze = clamp(1.0 - length(p) / (span * 1.5), 0.0, 1.0);
    behind += lit.rgb * (0.10 * pow(haze, 2.4));

    // The rings, as one ellipse cut in half by the body's own horizon. Flat
    // ends on purpose: a round cap hangs half a stroke past where the halves
    // meet and reads as a tab.
    float ringA = 0.0;
    if (lit.a > 0.0) {
        vec2 q = vec2(p.x, p.y / max(0.05, lit.a));
        float r = length(q);
        float ring = span * 0.98;
        float wide = max(1.0, span * 0.05) * 0.5 / max(0.05, lit.a);
        ringA = smoothstep(wide, wide - 1.5, abs(r - ring));
    }

    // The far half first, and it is the half above the middle.
    if (ringA > 0.0 && p.y <= 0.0) behind += lit.rgb * (ringA * 0.22);

    // The body. Lit from above rather than from anywhere in particular: a
    // sphere needs a light side and a dark one and nothing more than that to
    // stop reading as a circle.
    float on = disc(p, R);
    if (on > 0.0) {
        float up = clamp(p.y / span + 0.5, 0.0, 1.0);
        vec3 skin = mix(min(body.rgb * 1.5, vec3(1.0)), body.rgb, smoothstep(0.0, 0.55, up));
        skin = mix(skin, body.rgb * 0.53, smoothstep(0.55, 1.0, up));

        // The weather, as bands fixed in latitude on a world with no surface to
        // turn, so they cross it instead. Faded out at the poles, where a band
        // is short enough that a hard end to it reads as a scratch on the disc.
        //
        // Most worlds have none. Rolled per band rather than per world, which
        // was the first way, every world ends up with two or three and banded
        // stops being a thing a world can be: the plan gives fewer than half of
        // them weather and the rest a plain face, so the ones that have it are
        // worth looking at.
        if (hash21(vec2(seed, 31.0)) < 0.45) {
            for (int i = 0; i < 5; i++) {
                if (hash21(vec2(seed + 5.0, float(i))) < 0.4) continue;

                float lane = fract(hash21(vec2(seed + 9.0, float(i))) + t / max(1.0, body.a) * 0.5) * 2.0 - 1.0;
                float thick = (0.05 + 0.09 * hash21(vec2(seed + 12.0, float(i)))) * R;
                // Feathered over a third of its own thickness rather than over
                // a pixel. A band is weather and weather has no edge; at one
                // pixel it reads as a wire laid across the disc, which on a
                // world eighty pixels wide is all anybody sees.
                float band = smoothstep(thick, thick * 0.6, abs(p.y - lane * R));
                float fade = max(0.0, 1.0 - lane * lane);
                float pale = hash21(vec2(seed + 15.0, float(i))) < 0.5 ? 1.7 : 0.55;

                skin = mix(skin, clamp(body.rgb * pale, 0.0, 1.0), band * fade * 0.45);
            }
        }

        solid = skin;
    }

    // And the near half of the ring, over the body.
    if (ringA > 0.0 && p.y > 0.0) front += lit.rgb * (ringA * 0.30);

    // The moons, up to three, each on its own orbit and its own tilt. Slow on
    // purpose: the widest of these was the fastest thing in the old sky by a
    // long way and the first thing anybody saw hopping.
    float many = floor(hash21(vec2(seed, 9.1)) * 3.0);
    for (int i = 0; i < 3; i++) {
        if (float(i) >= many) continue;

        float ha = hash21(vec2(seed + 20.0, float(i)));
        float hb = hash21(vec2(seed + 40.0, float(i)));

        float away = (1.35 + 0.5 * float(i) + 0.4 * ha) * span;
        float ang = t / (520.0 + 700.0 * ha) * TAU + hb * TAU;
        vec2 seat = vec2(cos(ang) * away, sin(ang) * away * (0.1 + 0.3 * ha));

        // Behind the body when it is on the far side, which is above the middle.
        if (sin(ang) <= 0.0 && length(p) < R) continue;

        float size = (0.08 + 0.05 * hb) * span;
        vec3 hue = hb < 0.5 ? min(lit.rgb * 1.1, vec3(1.0)) : lit.rgb * 0.8;
        front += hue * (disc(p - seat, size * 0.5) * 0.8);
    }

    return on;
}

/**
 * A meteor, while one is falling.
 *
 * Bright at the leading end and nothing at the other, which is the whole of
 * what makes a moving line read as something with a tail behind it. It is the
 * only thing up here that is fast, and the clock in `Field.qml` gives it the
 * card's own rate for the second it takes.
 */
vec3 fall(vec2 px, vec4 m, vec3 tint, float t, vec2 res) {
    if (m.w < 0.0) return vec3(0.0);

    float dash = 1.1;
    float gone = (t - m.w) / dash;
    if (gone < 0.0 || gone > 1.0) return vec3(0.0);

    // In fast and out slow, so it arrives before it is noticed and leaves while
    // it is being looked at.
    float span = res.x * 0.34;
    vec2 way = vec2(cos(m.z), sin(m.z));
    vec2 head = m.xy + way * (span * gone * gone);

    // Distance to the tail behind the head, which is a segment and not a line.
    vec2 d = px - head;
    float along = clamp(-dot(d, way), 0.0, 140.0);
    float off = length(d + way * along);

    float bright = (1.0 - along / 140.0) * smoothstep(2.6, 0.0, off);
    float alive = min(gone / 0.22, (1.0 - gone) / 0.78);

    return tint * (bright * clamp(alive, 0.0, 1.0));
}

void main() {
    vec2 res = frame.xy;
    vec2 px = qt_TexCoord0 * res;
    float t = frame.z;

    // How far round the colour has come tonight. A sky that is one colour from
    // dusk to morning is a picture; this is a sixth of a turn either side of
    // where the theme put it, which is a different evening without ever being a
    // colour the theme did not choose.
    float turn = (frame.w - 0.5) * 0.12;

    vec3 lit = vec3(0.0);

    lit += cloud(px, gas0, at0, res, t, turn);
    lit += cloud(px, gas1, at1, res, t, turn);
    lit += cloud(px, gas2, at2, res, t, turn);

    lit += galaxy(px, far, farHue, t);

    // Three depths, each about its own pole, so they pull apart as they turn
    // instead of moving as one sheet with three sizes of dot in it. The spins
    // are set so the outermost star moves about four pixels a second, which is
    // under half a pixel between frames at the rate this idles at.
    lit += depth(px, vec2(-0.25, 1.35) * res,  88.0, 0.00080, 0.55 * ink.a, 0.85, ink.rgb, t);
    lit += depth(px, vec2(-0.30, 1.40) * res, 117.0, 0.00110, 0.80 * ink.a, 1.15, ink.rgb, t);
    lit += depth(px, vec2(-0.35, 1.45) * res, 181.0, 0.00140, 1.00 * ink.a, 1.60, ink.rgb, t);

    lit += rubble(px, belt, beltHue, t);

    // The worlds, which are the only things here that are not see-through, so
    // each one covers what has been drawn so far rather than adding to it.
    vec3 back, skin, fore;
    float on;
    float cover = 0.0;

    on = world(px, world0, lit0, body0, t, back, skin, fore);
    lit = mix(lit + back, skin, on) + fore;
    cover = max(cover, on);

    on = world(px, world1, lit1, body1, t, back, skin, fore);
    lit = mix(lit + back, skin, on) + fore;
    cover = max(cover, on);

    on = world(px, world2, lit2, body2, t, back, skin, fore);
    lit = mix(lit + back, skin, on) + fore;
    cover = max(cover, on);

    lit += fall(px, meteor, ink.rgb, t, res);

    // Premultiplied, and the alpha is the light itself. Everything here is
    // something glowing over a wallpaper, so where there is no light there is
    // nothing to draw and the picture underneath shows through untouched. A
    // world is the exception and says so through `cover`.
    lit = clamp(lit, 0.0, 1.0);
    float a = max(cover, max(max(lit.r, lit.g), lit.b));
    fragColor = vec4(lit, a) * qt_Opacity;
}
