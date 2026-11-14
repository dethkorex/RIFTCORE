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
sh "$temp/install.sh"
if [ "$steam_shortcut" -eq 1 ]; then
  printf 'In the Steam dialog, select: %s\n' "$base/start-riftcore"
  if ! command -v xdg-open >/dev/null 2>&1 || ! xdg-open 'steam://AddNonSteamGame'; then
    printf '%s\n' 'Open Steam manually and select Games > Add a Non-Steam Game to My Library.'
  fi
fi
exit 0
__RIFTCORE_PAYLOAD__
