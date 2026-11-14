# Release pipeline

The runtime game and native update launcher are two Godot projects. A tagged GitHub Actions build packages the Windows x64 game as an NSIS setup EXE and the Linux x64 game as a self-extracting setup RUN. Installers require no Godot editor.

To release a stable version, commit the intended source and run `git tag v0.1.1` then `git push origin v0.1.1`. Use increasing numeric tags. Actions builds the two games, the two launchers, installers, and a checksum manifest, then uploads all of them to a public GitHub release. Do not edit ZIPs or update.json independently after publishing.

To build locally, obtain Godot 4.7.2, Python 3.11+, NSIS, and the Godot engine license and copyright files. Then run:

```sh
python distribution/fetch_templates.py /path/to/templates
python distribution/build_release.py --engine /path/to/godot --templates /path/to/templates \
  --licenses /path/to/licenses --nsis /path/to/makensis --work /path/to/staging \
  --out /path/to/artifacts --tag v0.1.1 --repo dethkorex/RIFTCORE
```

Use a work directory outside the game project. The launcher accepts a validated GitHub repo name, downloads only matching release ZIPs, verifies size and SHA-256, and installs an allowlisted set of files to a versioned directory. If the release host is unreachable, the existing game remains playable.

## Installer 0.2 and Steam shortcuts

The installed launcher is the entry point for local play and GitHub updates on Windows and Linux. Its path stays the same when the game updates. To add it to Steam, use Games → Add a Non-Steam Game to My Library and select the installed RIFTCORE launcher. On Windows, the final installer page can open Steam's add-game dialog. On Linux, pass `--steam-shortcut` to the installer to open the same dialog. Both options leave confirmation to the player in Steam.

The PNG frames inside the Windows ICO come from the transparent RIFTCORE SVG. Game and launcher exports embed that ICO, and the installer uses it for the setup executable and Start menu shortcut.

Launcher 0.1 accepts only numeric tags and an exact four-file archive. Its Update and Play button receives the one-time `v0.4.100` migration, replaces the launcher at the original path, and installs the latest preview. Existing game versions are retained for offline play. The normal preview ZIP still includes the Steam runtime.

## Online room preview

Players create or join a private, two-player room using a shared code. The game uses GD Sync's hosted relay for this flow. Open the Social pad in Operations Station. A Steam library shortcut starts the launcher. Live rooms need a configured GD Sync project. Steam presence and invites also require a RIFTCORE Steam App ID. Shared campaign gameplay is under development. Solo play starts independently of the relay.

For a local relay test, the GD Sync project owner can supply the provider keys using `GDSYNC_PUBLIC_KEY` and `GDSYNC_PRIVATE_KEY`, or place them in the ignored `addons/GD-Sync/keys.cfg` on development machines. Export presets exclude that local config. The exported Windows and Arch Linux checks cover Social navigation, room code validation, and the unconfigured relay state. A live cross-platform relay test requires the same GD Sync project on both clients.

### Live room check

Enable GD Sync in the editor and enter a dedicated playtest key pair under Project → Tools → GD-Sync. The editor keeps the pair in the ignored config. In a distributed playtest build, use Social → Configure Playtest to save the pair on that machine. The export also accepts both environment variables from its caller. Use the same playtest pair on both machines. The release workflow and editor export do not embed the credentials.

1. Run the exported Windows game with `--headless -- --verify-relay host`. Add `--log-file PATH` before `--` to write the room code to a file.
2. On Linux, run `./RIFTCORE --headless -- --verify-relay join ROOM_CODE` with the code printed by Windows.
3. Both clients must print `RELAY CHECK PASS` after exchanging platform names through the live room. Run again with Linux hosting and Windows joining.

The build reads the current release notes from CHANGELOG.md. GitHub uses them for the release description and the launcher displays them from update.json. Manually dispatched builds upload preview artifacts without changing the public update channel.
