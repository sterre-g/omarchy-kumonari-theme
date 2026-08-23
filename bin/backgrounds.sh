#!/bin/bash
# The still pictures, made here rather than found somewhere.
#
# Every wallpaper in this theme comes out of this script, which is why there is
# no question about where they came from or what may be done with them. Run it
# and `backgrounds/` is rebuilt out of nothing but ImageMagick, node and a seed.
#
#   bin/backgrounds.sh
#
# They are deliberately quiet. The animated sky is drawn on the layer above
# these, so a wallpaper with much going on in it is a wallpaper competing with
# the thing it is meant to be behind.
#
# Sized for 16:10 at 3840 wide, which crops without letterboxing onto both 16:9
# and 16:10 and is the pair of shapes nearly every desk is one of.

set -euo pipefail

cd "$(dirname "$0")/.."

WIDTH=3840
HEIGHT=2400
OUT="backgrounds"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$OUT"

# A cloud of gas as a transparent layer: plasma for the shape, levelled hard so
# only the bright wisps of it survive, then poured into one flat colour.
#
# Levelling is what separates gas from fog. Plasma left alone covers the frame
# in an even mid grey, and an even mid grey at any opacity is a veil over the
# picture rather than anything in it.
#
# The blur comes after the resize and not before it. `plasma:fractal` is built
# by recursive subdivision and leaves faint seams on the axes it divided along;
# blurred small and then enlarged, the blur is enlarged with them and the seams
# survive as straight edges across a picture that has no straight edges in it.
# Blurring at full size is the same cost either way and there is nothing left.
gas() {
  local seed=$1 hue=$2 strength=$3 softness=$4 out=$5

  magick -size 480x300 -seed "$seed" plasma:fractal \
    -resize "${WIDTH}x${HEIGHT}!" \
    -blur "0x$softness" \
    -colorspace Gray \
    -auto-level \
    -level 38%,100% \
    -evaluate multiply "$strength" \
    "$WORK/mask-$seed.png"

  magick -size "${WIDTH}x${HEIGHT}" "xc:$hue" \
    "$WORK/mask-$seed.png" \
    -alpha off -compose CopyOpacity -composite \
    "$out"
}

# The still stars, out of the same generator the moving ones come from.
#
# Drawn as single points rather than made out of random noise, and this is not a
# stylistic preference: `+noise Random` fills every pixel in the frame with its
# own value, PNG has nothing left to predict, and the same picture comes out at
# 29MB instead of a few hundred KB. A list of points is also the only way to say
# how many stars there are and mean it.
#
# `Sky.js` scatters over a disc, so the count asked for is larger than the count
# that lands: the disc has to circumscribe the frame and the corners of it fall
# outside. Roughly four in seven survive at this shape.
stars() {
  local seed=$1 count=$2 out=$3

  node -e '
    const Sky = require("./sky/Sky.js");
    const [seed, count, width, height] = process.argv.slice(1).map(Number);
    const drawn = [];

    for (const star of Sky.field(count, Sky.hash(seed), Math.sqrt(width * width + height * height) / 2)) {
      const x = Math.round(star.x + width / 2);
      const y = Math.round(star.y + height / 2);

      if (x < 0 || y < 0 || x >= width || y >= height) continue;

      drawn.push(`fill rgba(255,255,255,${(0.22 + 0.78 * star.dim).toFixed(2)}) point ${x},${y}`);
    }

    process.stdout.write(drawn.join("\n"));
  ' "$seed" "$count" "$WIDTH" "$HEIGHT" >"$out"
}

deep_field() {
  local out="$OUT/1-deep-field.png"

  gas 20260823 "#6d4fb8" 0.45 30 "$WORK/gas-a.png"
  gas 731 "#2f7f9c" 0.28 38 "$WORK/gas-b.png"
  stars 4113 2600 "$WORK/stars-a.mvg"

  magick -size "${WIDTH}x${HEIGHT}" gradient:"#111a36"-"#04060c" \
    "$WORK/gas-a.png" -compose Over -composite \
    "$WORK/gas-b.png" -compose Over -composite \
    -draw "@$WORK/stars-a.mvg" \
    -define png:color-type=2 \
    "$out"

  echo "$out"
}

nebula_drift() {
  local out="$OUT/2-nebula-drift.png"

  gas 5150 "#8d4fd6" 0.55 24 "$WORK/gas-c.png"
  gas 9061 "#3aa79b" 0.36 32 "$WORK/gas-d.png"
  gas 2277 "#b8557f" 0.26 44 "$WORK/gas-e.png"
  stars 8802 1900 "$WORK/stars-b.mvg"

  magick -size "${WIDTH}x${HEIGHT}" gradient:"#0d1430"-"#05070f" \
    "$WORK/gas-c.png" -compose Over -composite \
    "$WORK/gas-d.png" -compose Over -composite \
    "$WORK/gas-e.png" -compose Over -composite \
    -draw "@$WORK/stars-b.mvg" \
    -define png:color-type=2 \
    "$out"

  echo "$out"
}

# Two more, warm and green, because the palette this theme ships is not the
# only thing the sky is ever drawn over and a wallpaper set that is all one
# colour makes `omarchy theme bg next` a formality.
ember_reach() {
  local out="$OUT/3-ember-reach.png"

  gas 3312 "#d0603f" 0.42 26 "$WORK/gas-f.png"
  gas 7740 "#e0a24c" 0.3 34 "$WORK/gas-g.png"
  gas 1188 "#8d3f6a" 0.26 40 "$WORK/gas-h.png"
  stars 6421 2200 "$WORK/stars-c.mvg"

  magick -size "${WIDTH}x${HEIGHT}" gradient:"#241026"-"#08050a" \
    "$WORK/gas-f.png" -compose Over -composite \
    "$WORK/gas-g.png" -compose Over -composite \
    "$WORK/gas-h.png" -compose Over -composite \
    -draw "@$WORK/stars-c.mvg" \
    -define png:color-type=2 \
    "$out"

  echo "$out"
}

verdant_deep() {
  local out="$OUT/4-verdant-deep.png"

  gas 4809 "#3fae86" 0.44 28 "$WORK/gas-i.png"
  gas 2650 "#5fa8c4" 0.3 36 "$WORK/gas-j.png"
  stars 9137 2400 "$WORK/stars-d.mvg"

  magick -size "${WIDTH}x${HEIGHT}" gradient:"#0a2226"-"#04090b" \
    "$WORK/gas-i.png" -compose Over -composite \
    "$WORK/gas-j.png" -compose Over -composite \
    -draw "@$WORK/stars-d.mvg" \
    -define png:color-type=2 \
    "$out"

  echo "$out"
}

deep_field
nebula_drift
ember_reach
verdant_deep
