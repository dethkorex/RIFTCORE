#!/bin/sh
set -eu
steam_shortcut=0
case "${1-}" in
  --version) printf '%s\n' 'RIFTCORE Installer 0.2'; exit 0 ;;
  --help|-h) printf '%s\n' 'Usage: RIFTCORE-Linux-x64-Setup.run [--steam-shortcut|--version]' 'Installs into XDG_DATA_HOME/riftcore. --steam-shortcut opens the Steam add-game dialog.'; exit 0 ;;
  --steam-shortcut) steam_shortcut=1 ;;
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
icons="${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor/scalable/apps"
mkdir -p "$icons"
cp "$temp/riftcore-icon.svg" "$icons/riftcore.svg"
chmod 755 "$base/RIFTCORE"
for version in "$temp"/versions/v*; do
  target="$base/versions/${version##*/}"
  if [ ! -e "$target" ]; then mv "$version" "$target"; fi
  chmod 755 "$target/RIFTCORE"
done
applications="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
mkdir -p "$applications"
desktop_exec="$(printf '%s' "$base/RIFTCORE" | sed 's/[\\`"$]/\\&/g; s/%/%%/g')"
printf '[Desktop Entry]\nType=Application\nName=RIFTCORE\nComment=RIFTCORE play and updates\nIcon=riftcore\nExec="%s"\nTerminal=false\nCategories=Game;\n' "$desktop_exec" > "$applications/riftcore.desktop"
printf 'RIFTCORE Installer 0.2 finished. Open the updater from your app menu or run: %s\n' "$base/RIFTCORE"
if [ "$steam_shortcut" -eq 1 ]; then
  printf 'In the Steam dialog, select: %s\n' "$base/RIFTCORE"
  if ! command -v xdg-open >/dev/null 2>&1 || ! xdg-open 'steam://AddNonSteamGame'; then
    printf '%s\n' 'Open Steam manually and select Games > Add a Non-Steam Game to My Library.'
  fi
fi
exit 0
__RIFTCORE_PAYLOAD__
