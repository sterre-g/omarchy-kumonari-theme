#!/bin/bash
# Install the sky.
#
# The theme needs none of this. `omarchy theme install` on this repo is the
# whole of the theme, colours and wallpapers and all, and it is a complete
# theme without a single moving part. What this adds is the part that moves.
#
#   ./install.sh            put the sky in
#   ./install.sh --remove   take it out again
#
# Nothing here switches off `omarchy.background`, and that is the whole design
# rather than an oversight. The sky is drawn on the layer above the wallpaper
# instead of in place of it, so Omarchy goes on painting pictures and running
# its own transitions for this theme and for every other one on the machine.
# Removing this leaves a desktop that cannot tell it was ever installed.
#
# The sky also asks, every time, which theme is being worn, and draws nothing at
# all unless the answer is this one. Between the two of them, a theme you switch
# away from is a theme you have switched away from.

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ID="kumonari.sky"
TARGET="$HOME/.config/omarchy/plugins/$ID"

command -v omarchy-shell >/dev/null || {
  echo "omarchy-shell is not on PATH; is this an Omarchy system?" >&2
  exit 1
}

# Restart the shell, and not because it is tidy.
#
# Copying the files does nothing on its own. The shell notices and says so in
# its log, but a plugin of kind `service` is built once when the shell starts
# and that notice does not rebuild it: the running desktop keeps whatever QML it
# was started with, and every install between two restarts is invisible.
restart_shell() {
  omarchy restart shell >/dev/null 2>&1 || {
    echo "Installed, but the shell would not restart. Run: omarchy restart shell" >&2
    return 0
  }
}

install_sky() {
  mkdir -p "$TARGET"
  # Deleted as well as copied, so that a file dropped from the repo does not go
  # on being loaded out of an install somebody has had since before it went.
  rsync -a --delete "$HERE/sky/" "$TARGET/" 2>/dev/null || {
    rm -rf "$TARGET"
    mkdir -p "$TARGET"
    cp -a "$HERE/sky/." "$TARGET/"
  }

  omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true

  for _ in $(seq 40); do
    if omarchy plugin list --json 2>/dev/null |
      jq -e --arg id "$ID" 'any(.[]; .id == $id)' >/dev/null; then
      omarchy plugin enable "$ID" >/dev/null
      restart_shell
      echo "Installed $ID. Wear the kumonari theme and look up."
      return 0
    fi
    sleep 0.05
  done

  echo "Copied to $TARGET, but the shell did not discover it." >&2
  echo "Try: omarchy restart shell" >&2
  return 1
}

remove_sky() {
  if omarchy plugin list --json 2>/dev/null |
    jq -e --arg id "$ID" 'any(.[]; .id == $id and .enabled)' >/dev/null; then
    omarchy plugin disable "$ID" >/dev/null
  fi

  rm -rf "$TARGET"
  restart_shell
  echo "Removed $ID. The wallpaper is on its own again."
}

case "${1:-}" in
  "" | --install)
    install_sky
    ;;
  --remove | --uninstall)
    remove_sky
    ;;
  *)
    echo "usage: ./install.sh [--remove]" >&2
    exit 2
    ;;
esac
