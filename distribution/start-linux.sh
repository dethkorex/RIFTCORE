#!/bin/sh
set -eu
here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
if [ "${1-}" = "--headless" ]; then
  exec "$here/RIFTCORE" "$@"
fi
if [ "${1-}" = "--x11" ]; then
  shift
  exec "$here/RIFTCORE" --display-driver x11 "$@"
fi
if [ -n "${WAYLAND_DISPLAY:-}" ] && [ -z "${RIFTCORE_FORCE_X11:-}" ]; then
  exec "$here/RIFTCORE" --display-driver wayland "$@"
fi
exec "$here/RIFTCORE" "$@"
