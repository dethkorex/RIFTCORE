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

## Online room preview

Players create or join a private, two-player room using a shared code. The game uses GD Sync's hosted relay for this flow. A Steam library shortcut only starts the launcher. A configured GD Sync project, host-authoritative gameplay sync, and a verified Steam integration are still needed for the co-op release. Solo play starts independently of the relay.

For a local relay test, the GD Sync project owner can supply the provider keys using `GDSYNC_PUBLIC_KEY` and `GDSYNC_PRIVATE_KEY`, or place them in the ignored `addons/GD-Sync/keys.cfg` on development machines. Export presets exclude that local config. Public release provisioning still needs to be verified.

The build reads the current release notes from CHANGELOG.md. GitHub uses them for the release description and the launcher displays them from update.json. Manually dispatched builds upload preview artifacts without changing the public update channel.
