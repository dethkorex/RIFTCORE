# RIFTCORE: Rogue Protocol

A 3D side-scrolling roguelike platformer inspired by Mega Man X. This playtest includes Sector 01: Neon Factory and Sector 02: Machine Jungle, with Forge Titan and Verdant Colossus boss encounters.

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
| Swap weapon | Q | RB |
| Pause | Escape | Start |

Resolution, fullscreen, Master/Music/SFX levels, and keyboard/controller bindings are saved in Settings. Dash and air dash are free. Collect XP orbs for +8 max HP, +6 max energy, +6% base attack and +2 percentage points of defense per player level (25% defense cap). Enemy HP and damage rise by 30% and 20% of their base stats per sector. Lose all three lives and the run's XP and boss weapons reset; banked credits and purchased workshop upgrades carry over.

Forge Titan grants Magma Breaker for the current run. The Command Deck carries earned weapons and XP into Machine Jungle and grants three fresh lives. Jungle enemies take 1.5× fire damage. Burn vines to reach the canopy caches, climb vines, ride moving hoists, and dodge thorns and spore clouds. Verdant Colossus grants Thorn Swarm for the run. Swapping to Magma Breaker or Thorn Swarm equips the corresponding red or green armor on the same RX-07 rig.

## Develop

Open `project.godot` in Godot **4.7.2**. Edit `scenes/levels/neon_factory_test.tscn` for the level. Use the `Actors/RiftcoreMecha` node to move the player start.

Machine Jungle is authored in `scenes/levels/machine_jungle.tscn`. Its reusable enemies, terrain, traps, and vine barriers are under `assets/machine_jungle`. Deployment and extraction pads are under `assets/neon_factory`; their visual details do not change platform collisions. The player faces the ladder's local -Z while climbing.

Push a stable tag such as `v0.1.1` to build and publish both installers through GitHub Actions. The update manifest and both game ZIPs are published together. See [distribution instructions](distribution/README.md), [art production notes](ART_NOTES.md), and [audio credits](assets/audio/CREDITS.md).
