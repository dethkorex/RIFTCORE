#!/bin/sh
set -eu
case "${1-}" in
  --help|-h) printf '%s\n' 'RIFTCORE installer: run as your normal user. Installs into XDG_DATA_HOME/riftcore.'; exit 0 ;;
  '') ;;
  *) printf 'Unknown option: %s\n' "$1" >&2; exit 2 ;;
esac
if [ "$(uname -m)" != x86_64 ]; then
  printf '%s\n' 'This installer is for 64-bit x86 Linux.' >&2
  exit 1
fi
base="${XDG_DATA_HOME:-$HOME/.local/share}/riftcore"
temp="$(mktemp -d)"
trap 'rm -rf -- "$temp"' EXIT HUP INT TERM
payload="$(awk '/^__RIFTCORE_PAYLOAD__$/ { print NR + 1; exit }' "$0")"
tail -n "+$payload" "$0" | tar -xzf - -C "$temp"
mkdir -p "$base/versions"
cp "$temp/RIFTCORE" "$base/RIFTCORE"
cp "$temp/updates.cfg" "$base/updates.cfg"
chmod 755 "$base/RIFTCORE"
for version in "$temp"/versions/v*; do
  target="$base/versions/${version##*/}"
  if [ ! -e "$target" ]; then mv "$version" "$target"; fi
  chmod 755 "$target/RIFTCORE"
done
applications="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
mkdir -p "$applications"
desktop_exec="$(printf '%s' "$base/RIFTCORE" | sed 's/[\\`"$]/\\&/g; s/%/%%/g')"
printf '[Desktop Entry]\nType=Application\nName=RIFTCORE\nExec="%s"\nTerminal=false\nCategories=Game;\n' "$desktop_exec" > "$applications/riftcore.desktop"
printf 'RIFTCORE installed. Start it from your app menu or run: %s\n' "$base/RIFTCORE"
exit 0
__RIFTCORE_PAYLOAD__
