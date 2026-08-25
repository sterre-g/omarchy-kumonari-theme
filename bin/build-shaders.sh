#!/bin/bash
# Compile the sky's shader for Qt's own pipeline.
#
# Qt 6 does not take GLSL at runtime. A `ShaderEffect` is handed a `.qsb`, a
# bundle holding the same shader compiled for every backend the RHI might come
# up on, and `qsb` is what makes one. So the source is `sky/sky.frag`, the
# bundle is `sky/sky.frag.qsb`, and the bundle is committed, because nothing on
# the desktop this installs onto is going to have Qt's shader tools on it.
#
# Run this after changing the `.frag`, and commit both halves.
#
# ## The targets are the point of this file
#
# `--glsl 120,150` looks like enough and is not. Quickshell comes up on OpenGL
# ES here, so it asks the bundle for an ES shader, finds only desktop ones, and
# says so once per frame in the journal:
#
#   WARN: No GLSL shader code found (versions tried: QList(320, 310, 300, 100))
#
# The sky then draws nothing whatever, in silence as far as the desktop is
# concerned. `100es` is what answers that, and leaving it out is a whole evening
# spent looking for a bug in a shader that was never being run.

set -euo pipefail

cd "$(dirname "$0")/.."

QSB="${QSB_BIN:-}"
if [[ -z $QSB ]]; then
  for candidate in qsb /usr/lib/qt6/bin/qsb /usr/lib/qt6/libexec/qsb; do
    if command -v "$candidate" >/dev/null 2>&1; then QSB="$candidate"; break; fi
  done
fi

[[ -n $QSB ]] || {
  echo "no qsb on PATH; it ships with Qt's shader tools (qt6-shadertools)" >&2
  exit 1
}

for source in sky/*.frag; do
  "$QSB" --glsl "100es,300es,120,150" --hlsl 50 --msl 12 -O -o "$source.qsb" "$source"
  echo "$source -> $source.qsb"
done

# The one thing worth checking, since the failure it guards is silent.
#
# Held in a variable rather than piped into `grep -q`, which is a trap this
# script fell into on its first run: `grep -q` leaves as soon as it matches,
# `qsb` gets SIGPIPE writing the rest, and `pipefail` reports the success as a
# failure. A check that fails when it passes is worse than no check.
dump=$("$QSB" --dump sky/sky.frag.qsb)

case "$dump" in
  *"GLSL 100 es"*) ;;
  *)
    echo "the bundle has no GLSL ES shader in it; the desktop will draw nothing" >&2
    exit 1
    ;;
esac
