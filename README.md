# RIFTCORE: Rogue Protocol

A 3D side-scrolling roguelike platformer inspired by Mega Man X. This playtest includes Sector 01: Neon Factory and the Forge Titan encounter.

## Play

Open [GitHub Releases](https://github.com/dethkorex/RIFTCORE/releases/latest). Choose `RIFTCORE-Windows-x64-Setup.exe` for Windows or `RIFTCORE-Linux-x64-Setup.run` for Linux. These include the game runtime; players do not need Godot. On Linux, run `chmod +x RIFTCORE-Linux-x64-Setup.run` and then `./RIFTCORE-Linux-x64-Setup.run`.

The installed launcher checks GitHub Releases. When an update is available, select **Update and play**. **Play installed** works offline. Updates verify the package SHA-256 and install next to the prior version, leaving saves and settings in their normal Godot user data directory. The ZIP downloads are standalone portable games without the launcher.

| Action | Keyboard | Controller |
| --- | --- | --- |
| Move | A / D or arrows | Left stick |
| Jump / wall kick | Space | A |
| Dash / air dash | Shift | B |
| Buster / hold to charge | J | X |
| Sword / three-tap combo | K | Y |
| Climb | W / S or up/down | Left stick or D-pad up/down |
| Crouch | S / down | Down |
| Swap weapon | Q | LB |
| Pause | Escape | Start |

Resolution, fullscreen, Master/Music/SFX levels, and keyboard/controller bindings are saved in Settings. Three lives per stage, optional extra lives, checkpoint saves, and a persistent credit bank support repeat runs. Collect dropped XP orbs to level up. Defense rises with each level. Beating Forge Titan permanently unlocks Magma Breaker; fresh deployments still begin at level 1.

## Develop

Open `project.godot` in Godot **4.7.2**. Edit `scenes/levels/neon_factory_test.tscn` for the level. Use the `Actors/RiftcoreMecha` node to move the player start.

Push a stable tag such as `v0.1.1` to build and publish both installers through GitHub Actions. The update manifest and both game ZIPs are published together. See [distribution instructions](distribution/README.md), [art production notes](ART_NOTES.md), and [audio credits](assets/audio/CREDITS.md).
