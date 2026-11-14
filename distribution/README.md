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

The launcher and the game share the same release feed and installer. To ship a launcher update, increment LAUNCHER_BUILD in launcher.gd. The release manifest records a separate SHA-256 for each launcher. Update and Play installs a newer launcher first, hands off at the original shortcut path, then checks for the game update. Game installs retain one older complete build for recovery and remove older folders containing only known package files. In Alpha 6.0 or newer, start the game executable directly and use Settings → Update Game. Installation and restart are available from title Settings. An old launcher that cannot install a download can be refreshed by running the current installer into the existing installation. Its path stays the same when the game updates. To add it to Steam, use Games → Add a Non-Steam Game to My Library and select the installed RIFTCORE launcher. On Windows, the final installer page can open Steam's add-game dialog. On Linux, pass `--steam-shortcut` to the installer to open the same dialog. Both options leave confirmation to the player in Steam.

The PNG frames inside the Windows ICO come from the transparent RIFTCORE SVG. Game and launcher exports embed that ICO, and the installer uses it for the setup executable and Start menu shortcut.

Launcher 0.1 accepts only numeric tags and an exact four-file archive. Its Update and Play button receives the one-time `v0.4.100` migration, replaces the launcher at the original path, and installs the latest preview. Existing game versions are retained for offline play. The normal preview ZIP still includes the Steam runtime.

## Online room preview

Players create or join a private, two-player room using a shared code. The game uses GD Sync's hosted relay for this flow. Open the Social pad in Operations Station. A Steam library shortcut starts the launcher. Live rooms need a configured GD Sync project. Steam presence and invites also require a RIFTCORE Steam App ID. Once two players join, the host can select a campaign sector. The party can walk around Operations Station before deploying. Both players bring their own gear and each mission awards each player an identical share of XP, bolts and blueprint unlocks. Gear and inventory are local to each save. Use the System pad to save rewards without advancing the campaign. Solo play starts independently of the relay.

The release workflow supplies the game’s GD Sync project keys from GitHub Actions secrets, and Godot’s GD Sync export plugin includes them in both game packages. Players can open Social and create or join a room immediately. Editor testing uses Project → Tools → GD-Sync or the `GDSYNC_PUBLIC_KEY` and `GDSYNC_PRIVATE_KEY` environment variables. The editor config is ignored by Git. Use a dedicated game key pair for distribution because exported resources can be read by players.

### Live room check

1. Run the exported Windows game with `--headless -- --verify-relay host`. Add `--log-file PATH` before `--` to write the room code to a file.
2. On Linux, run `./RIFTCORE --headless -- --verify-relay join ROOM_CODE` with the code printed by Windows.
3. Both clients must print `RELAY CHECK PASS` after exchanging platform names through the live room. Run again with Linux hosting and Windows joining.

The build reads the current release notes from CHANGELOG.md. GitHub uses them for the release description and the launcher displays them from update.json. Manually dispatched builds upload preview artifacts without changing the public update channel.
