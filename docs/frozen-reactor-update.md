# Frozen Reactor update

Release target: Alpha 6.3.20, distributed through the existing Windows/Linux release and updater pipeline. The 6.3.19 build was cancelled before publication to include the requested co-op stress testing and fixes.

- Rime Keeper and Cryo Warden use new textured Tripo meshes matching the approved navy, white and cyan concepts.
- Rebuilt mechanical skeletons and rigid armor weights in Blender. Replaced deforming humanoid poses with constrained idle, walking, shooting, attack and cinematic poses. Chest armor, coolant tanks, cannon and shield stay rigid.
- New glacial ice surface, distinct grippy deck finish, icicle clusters, coolant pumps, rocket board, launch pad and spike gate assets.
- New ice projectile trails, shattering impacts, frost warnings and growing ice formations.
- Act II rocket spillway: 2,040 metres, 20 m/s cap, gradual downhill acceleration, upward thrust, braking, jump pads, gaps and crouch gates. The minimum physical traversal time is 102 seconds; the scripted successful run took 109.3 seconds.
- Board has a curved hull, twin engines, edge lighting, fins, grip pads and exhaust rings. Rider hovers 0.50 m above the running surface; board follows the slope. Spike clearance is 2.15 m, leaving 0.60 m above the crouched capsule, with contact detection and a warning before each gate.
- Finishing the spillway activates Relay A and returns that rider to the midway checkpoint. Relay B and the existing two-relay boss door remain in use.
- Each co-op operator controls their own board. Boarding, return, camera bounds, velocity and boss animation intent synchronize with the host. Rejoining/restoring a board snapshot expands the guest camera bounds.
- NOVA's Act II advice and the tutorial manual explain the course.

## Validation

- `tests/frozen_sector.gd`: complete route, minimum duration, hover clearance, speed cap, crouch and thrust controls, standing spike contact, Relay A, return, restored guest camera bounds and remote velocity.
- `tests/frozen_combat.gd`: both imported models, all four motion clips, feet near the floor throughout every clip, full entrances, complete HP-bar fill, ice attacks and replicated animation intent.
- `tests/coop_position.gd`: existing movement reconciliation and camera recovery checks.
- `tests/sector_progression.gd`: existing Foundry/Jungle traversal, boss mechanics and difficulty regression checks.
- Live relay smoke test with two Windows clients: independent inputs, board sync and camera range, both Frozen Reactor acts, rewards and extraction. This is an automated two-client test; it is not a manual full campaign or a Windows/Linux hardware test.
- Native renderer screenshots inspected for both boss rigs, board hover, slope angle and crouch gate.

## Tripo accounting

Approved estimate and actual total: **210 credits**. Balance checked after generation: **530**, with **0 frozen**.

| Asset | Step | Task ID | Credits |
|---|---|---|---:|
| Rime Keeper | Textured model, v3.1-20260211, detailed PBR, 25k face target | ba60ea01-ddd8-485e-a218-279edad9c29e | 40 |
| Rime Keeper | Rig check | b47de23f-432e-4b1c-adc5-90dfa298f479 | 0 |
| Rime Keeper | Rig | aa8a0f6b-ae6e-4432-aca6-f80eb5978de5 | 25 |
| Rime Keeper | Four motion clips | 41344c11-bfa0-43e1-a88f-0980720a3007 | 40 |
| Cryo Warden | Textured model, v3.1-20260211, detailed PBR, 25k face target | d26ab9df-0589-4914-8ff9-e0ea3382e5e8 | 40 |
| Cryo Warden | Rig check | 05b77df9-0946-4747-b2df-f7ceb28f9720 | 0 |
| Cryo Warden | Rig | a623cfe1-2497-49e9-816f-4c431d667cb5 | 25 |
| Cryo Warden | Four motion clips | 734ea25b-2dab-4fed-b08e-81fb7198e4e5 | 40 |
| **Total** | | | **210** |

The auto-rigged humanoid clips folded mechanical armor. Final game rigs and poses were repaired locally with `distribution/prepare_frozen_rigs.py` and `scripts/frozen_boss_rig.gd`, without additional Tripo spend. Original generated rigs and clips remain in the workspace's `work/frozen-overhaul/tripo` directory.

## Asset locations

Runtime models: `assets/campaign/frozen_reactor/enemies/rime_keeper_tripo.glb` and `cryo_warden_tripo.glb`.

Runtime kit: `assets/campaign/frozen_reactor/kit/`. Concept and rigging reference PNGs: `assets/campaign/frozen_reactor/concepts/`; excluded from game exports.

Built-in image generation was used for the concepts, T-pose references and glacial albedo; Blender was used for mechanical rig repair and the board is native Godot geometry. No new audio pack was installed.
