#!/usr/bin/env bash
# Headless smoke test: run every demo for a fixed number of frames under
# SDL's dummy drivers. A demo passes when it exits 0.
#
# Usage: scripts/smoke-examples.sh [frames]   (default: 60)
#
# Extend the `demos` list as milestones add examples.
set -u
cd "$(dirname "$0")/.."
frames="${1:-60}"

demos=(
  renderer-01-clear
  renderer-02-primitives
  renderer-03-lines
  renderer-04-points
  renderer-05-rectangles
  renderer-06-textures
  renderer-07-streaming-textures
  renderer-08-rotating-textures
  renderer-09-scaling-textures
  renderer-10-geometry
  renderer-11-color-mods
  renderer-14-viewport
  renderer-15-cliprect
  renderer-17-read-pixels
  renderer-18-debug-text
  renderer-19-affine-textures
  renderer-20-blending
  misc-01-power
  misc-02-clipboard
  misc-03-locale
  audio-01-simple-playback
  audio-02-simple-playback-callback
  audio-03-load-wav
  audio-04-multiple-streams
  audio-05-planar-data
  input-01-joystick-polling
  input-02-joystick-events
  input-03-gamepad-polling
  input-04-gamepad-events
  input-05-gamepad-rumble
  demo-01-snake
)

fail=0
for d in "${demos[@]}"; do
  if SDL_VIDEO_DRIVER=dummy SDL_AUDIO_DRIVER=dummy SDL_LEAN_MAX_FRAMES="$frames" \
      lake exe "$d" >/dev/null 2>&1; then
    echo "ok   $d"
  else
    echo "FAIL $d (exit $?)"
    fail=1
  fi
done
exit $fail
