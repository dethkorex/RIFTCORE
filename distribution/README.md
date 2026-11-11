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
