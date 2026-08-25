#!/bin/bash
# Render the next few days of sky to PNGs, without wearing the theme.
#
#   bin/preview.sh                   seven days of this theme's palette
#   bin/preview.sh --theme gruvbox   the same seven in somebody else's
#   bin/preview.sh --days 3 --seed 7 --size 1800x1012
#   bin/preview.sh --over backgrounds/1-deep-field.png
#
# The way to look at a wallpaper that is different every morning without waiting
# a week for the week. It needs the desktop it is run from, since the sky is
# drawn by a shader and Qt's offscreen platform has none, but it does not need
# the theme to be worn and it does not touch what is on screen.

set -euo pipefail

cd "$(dirname "$0")/.."

DAYS=7
OUT="${TMPDIR:-/tmp}/kumonari"
SEED=1
THEME=""
WIDE=1600
TALL=1000
OVER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --days) DAYS="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --seed) SEED="$2"; shift 2 ;;
    --theme) THEME="$2"; shift 2 ;;
    --size) WIDE="${2%%x*}"; TALL="${2##*x}"; shift 2 ;;
    --over) OVER="$(realpath "$2")"; shift 2 ;;
    *) echo "usage: bin/preview.sh [--days N] [--seed N] [--theme NAME] [--size WxH] [--over WALLPAPER] [--out PREFIX]" >&2; exit 2 ;;
  esac
done

PALETTE="$PWD/colors.toml"

if [[ -n $THEME ]]; then
  PALETTE=""
  for dir in "$HOME/.config/omarchy/themes/$THEME" "${OMARCHY_PATH:-/usr/share/omarchy}/themes/$THEME"; do
    if [[ -f $dir/colors.toml ]]; then PALETTE="$dir/colors.toml"; break; fi
  done
  # A theme with no colours of its own is a real case rather than a mistake:
  # one of mine is an empty directory. Carry on and let the fallback answer.
  [[ -n $PALETTE ]] || echo "no colors.toml for '$THEME'; using the fallback palette" >&2
fi

RUNNER=$(command -v qml6 || command -v qml) || {
  echo "no qml runtime on PATH; install qt6-declarative" >&2
  exit 1
}

# Passed as base64 rather than as a path: plain QML cannot read a file, and its
# XMLHttpRequest returns empty for `file:` URLs instead of saying so.
PALETTE64=""
[[ -n $PALETTE && -f $PALETTE ]] && PALETTE64=$(base64 -w 0 "$PALETTE")

# On whatever platform the session is already on, and not `offscreen`, which
# renders a `ShaderEffect` as nothing at all without reporting it. The window
# this opens is real and shows for as long as the render takes.
"$RUNNER" sky/preview.qml -- \
  --days "$DAYS" --out "$OUT" --seed "$SEED" --palette64 "$PALETTE64" \
  --wide "$WIDE" --tall "$TALL" --over "$OVER"

echo "$DAYS day(s) written to ${OUT}-1.png .. ${OUT}-${DAYS}.png"
