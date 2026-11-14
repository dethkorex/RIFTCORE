#!/bin/sh
set -eu
here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
base="${XDG_DATA_HOME:-$HOME/.local/share}/riftcore"
if [ "$(uname -m)" != x86_64 ]; then
  printf '%s\n' 'RIFTCORE requires x86_64 Linux.' >&2
  exit 1
fi
mkdir -p "$base/versions"
for file in RIFTCORE start-riftcore updates.cfg PATCH_NOTES.md; do
  install -m 644 "$here/$file" "$base/$file"
done
chmod 755 "$base/RIFTCORE" "$base/start-riftcore"
for source in "$here"/versions/*; do
  [ -d "$source" ] || continue
  version=${source##*/}
  if [ ! -f "$base/versions/$version/RIFTCORE" ] || [ ! -f "$base/versions/$version/RIFTCORE.pck" ]; then
    cp -R "$source" "$base/versions/"
  fi
  chmod 755 "$base/versions/$version/RIFTCORE"
done
icons="${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor/scalable/apps"
applications="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
mkdir -p "$icons" "$applications"
install -m 644 "$here/riftcore-icon.svg" "$icons/riftcore.svg"
desktop_exec=$(printf '%s' "$base/start-riftcore" | sed 's/[\`"$]/\\&/g; s/%/%%/g')
printf '[Desktop Entry]\nType=Application\nName=RIFTCORE\nComment=RIFTCORE play and updates\nIcon=riftcore\nExec="%s"\nTerminal=false\nCategories=Game;\n' "$desktop_exec" > "$applications/riftcore.desktop"
printf 'RIFTCORE installed. Open it from your app launcher or run: %s\n' "$base/start-riftcore"
