# RIFTCORE: Rogue Protocol

A 3D side-scrolling roguelike platformer inspired by Mega Man X. The campaign has ten sectors. Defeat the sector boss, reach extraction, then deploy to the next sector from the walkable station hub. Each new sector starts with three lives and carries forward the current run's levels and weapons.

## Play

Open [GitHub Releases](https://github.com/dethkorex/RIFTCORE/releases/latest). Choose `RIFTCORE-Windows-x64-Setup.exe` for Windows or `RIFTCORE-Linux-x64-Setup.run` for Linux. These include the game runtime; players do not need Godot. On Linux, run `chmod +x RIFTCORE-Linux-x64-Setup.run` and then `./RIFTCORE-Linux-x64-Setup.run`.

The installed launcher checks GitHub Releases. When an update is available, select **Update and play**. **Play installed** works offline. Updates verify the package SHA-256 and install next to the prior version, leaving user data in its normal Godot directory. The ZIP downloads are standalone portable games without the launcher.

| Action | Keyboard | Controller |
| --- | --- | --- |
| Move | A / D or arrows | Left stick |
| Jump / wall kick | Space | A |
| Dash / air dash (hold for range) | Shift | B |
| Buster / hold to charge | J | X |
| Sword / three-tap combo | K | Y |
| Climb | W / S or up/down | Left stick or D-pad up/down |
| Crouch | S / down | Down |
| Previous / next suit | E / Q | LB / RB |
| Pause | Escape | Start |

Resolution, fullscreen, Master/Music/SFX levels, and keyboard/controller bindings are saved in Settings. Dash and air dash are free. Release Dash to cut the burst short or press the opposite direction to brake and turn. Collect XP orbs for +8 max HP, +6 max energy, +6% base attack and +2 percentage points of defense per player level (25% defense cap). Enemy HP and damage rise by 30% and 20% of their base stats per sector. Lose all three lives and the run's XP and boss weapons reset; banked credits and purchased workshop upgrades carry over.

Forge Titan grants Magma Breaker for the current run. The station carries earned weapons and XP into Machine Jungle and grants three fresh lives. Jungle enemies take 1.5× fire damage. Burn vines to reach the canopy caches, climb vines, ride moving hoists, and dodge thorns and spore clouds. Verdant Colossus grants Thorn Swarm for the run. Each first boss-weapon unlock in a run plays a suit reveal. Magma Breaker and Thorn Swarm use dedicated red and green armor meshes. Later rewards apply their colors to the RX-07 frame.

| Sector | Boss | Weapon | Route mechanic |
| --- | --- | --- | --- |
| 01 Neon Factory | Forge Titan | Magma Breaker | Ladders, lifts, drills and wall kicks |
| 02 Machine Jungle | Verdant Colossus | Thorn Swarm | Climbable vines and fire-opened routes |
| 03 Frozen Reactor | Cryo Warden | Frost Lance | Slippery decks and cryo vents |
| 04 Abyssal Plant | Volt Kraken | Tidal Arc | Buoyant water and electrical grids |
| 05 Buried Archives | Sand Cipher | Data Lance | Phasing ledges and sand geysers |
| 06 Sky Dock | Aerowyrm | Gale Edge | Wind lanes and updrafts |
| 07 BioLab | Omega Chimera | Chimera Burst | Mutation pulses and bounce pads |
| 08 Orbital Array | Eclipse Nova | Singularity Shot | Low gravity and solar beams |
| 09 Scrapyard Expanse | Rust Revenant | Scrap Reaver | Magnetic pull and scrap presses |
| 10 RiftCore Nexus | The Architect | Core Override | Phase and corruption gates |

## Station and manual saves

Walk with A/D, the left stick, or the D-pad. Stand on a pad and press E, Enter, or A to interact. Open Deploy to continue your run or select a previously reached sector after your first clear. Review item prices and rarity at the Item Shop. Use Storage to equip or stow gear. Loadout shows all five equipment slots and lets you record three presets.

Choose **New Game** or **Load Game** at the title screen. The manual-save update starts with three empty slots. Saves from earlier builds are ignored, and display, audio, and control settings carry over.

Use the **Save Game** pad in the station or **Pause > Save Game** during a mission. A mission save resumes at the latest activated checkpoint or the start of the current act. Checkpoints, purchases, and act transitions update the running session. Use Save Game to keep those changes across launches. Pause also offers Save and return to title. Returning to the title without saving keeps your run available for the current session. Starting over in an occupied slot replaces it on the next manual save.

Losing all lives invalidates the saved run and removes lost equipped gear from that slot. The slot's saved bank, purchased workshop upgrades, and stored items carry over. Save again at the station to keep newly banked bolts.

See [gameplay expansion ideas](GAMEPLAY_EXPANSION.md) for optional routes, difficulty modifiers, and puzzles for all ten sectors.

## Develop

Open `project.godot` in Godot **4.7.2**. Edit `scenes/levels/neon_factory_test.tscn` for the level. Use the `Actors/RiftcoreMecha` node to move the player start.

Machine Jungle is authored in `scenes/levels/machine_jungle.tscn`. Its reusable enemies, terrain, traps, and vine barriers are under `assets/machine_jungle`. Deployment and extraction pads are under `assets/neon_factory`; their visual details do not change platform collisions. While climbing a ladder or vine, hold left or right to aim the cannon and press or charge fire as usual. Jump to detach.

Sectors 03–10 also have editable scenes under `scenes/levels`. Their reusable biome kits, original Blender generation scripts, and campaign data live under `assets/campaign`. The generation scripts regenerate sectors 03–10, so keep a copy of hand edits before running them.

Each sector's `assets/campaign/<sector>/terrain` folder has `climb_platform_left.tscn`, `climb_platform_center.tscn`, and `climb_platform_right.tscn`. Drag a scene into the level and move its root node. Use **Deck Width**, **Deck Depth**, and **Climb Height** in the Inspector to resize it. The mesh, the hatch collision shapes, and the ladder or vine rebuild together. Position the top of the deck at the desired floor height and set Climb Height to reach the lower floor.

Push a stable tag such as `v0.3.0` to build and publish both installers through GitHub Actions. The update manifest and both game ZIPs are published together. See [distribution instructions](distribution/README.md), [art production notes](ART_NOTES.md), and [audio credits](assets/audio/CREDITS.md).
