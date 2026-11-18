# Alpha 6.3.20 co-op validation

The tests use actual GD-Sync rooms and native Windows and Linux Godot clients.
Linux runs in the dedicated RIFTCORE-QA WSL distribution on the same computer.
No local Docker service or system network configuration is changed.

## Changes

- Squad checkpoints: the host accepts a checkpoint touched by any living party member, sends a reliable notification to every guest, and preserves that checkpoint through recovery. Repeated packets and recovery do not repeat the banner.
- Every player can hold Field Interact for four seconds beside a fallen teammate. A visible bar fills for the rescuer and fallen player. Release, damage, separation or suspended controls interrupt the hold. Field Reboot ranks reduce the duration to 3.2, 2.6 and 2 seconds.
- Fallen bodies use the operator's current model and skin. Fall deaths return the body to its last supported platform, with the checkpoint/spawn as fallback. Moving supports carry the body. Being carried together does not interrupt revival.
- Revival restores full HP at the body without adding lives. Alive operators with zero spare lives participate in boss doors, act changes, rewards and extraction.
- Resting-position reconciliation fixes a reproduced four-player drift after rapid reversals under delayed acknowledgements. Compact remote snapshots retain board, level and debuff presentation.
- Room protocol advances to v17 so older clients cannot join missions with different revival and snapshot behavior. Accounts and saves are retained.
- Frozen boss textures use full-resolution BC7 GPU compression. Export excludes five duplicate texture sheets belonging to the already-excluded editor player meshes; the active player and all nine suit texture dependencies were inspected before exclusion. Source sheets remain available for authoring. The release builder rejects packages exceeding the 512 MiB limit in existing launchers.

## Automated checks

- `tests/coop_revival.gd`: 23 checks covering fall placement, moving support, free revival, all talent ranks, progress, interruption, full HP/zero lives and checkpoint sender/notification rules.
- `tests/coop_position.gd`: 10 checks, including a regression where an old input sample lies on the opposite side of the authoritative resting position.
- `tests/frozen_sector.gd`: 14 checks, including complete rocket-course traversal and compact teammate board snapshots.
- `tests/frozen_combat.gd`: 166 rig, animation, entrance, projectile and replication checks.
- `tests/sector_progression.gd`: 49 Foundry/Jungle traversal, mechanics and scaling checks.
- `tests/coop_stress.gd` with `tests/coop_test_link.gd`: two- and four-player relay scenarios. Application packets receive 0 ms, 70 ms plus 0–65 ms jitter/10% unreliable loss, or 130 ms plus 0–80 ms jitter/20% unreliable loss, on both senders. Reliable packets retain ordering. The actual guest and host connections are also interrupted and rejoined.
- Four-player scenario: 64 party messages, independent movement, all three guests rejoining, host rejoining, one scout notifying all four players, interrupted/completed revives in both directions, zero-life survival through both acts, board visibility, extraction and whole-party wipe with lobby retained.
- Campaign scenario: Linux host and Windows guest exercise all ten sectors' boss introductions, act transitions and extraction. The driver positions players at boss doors and applies test damage; this is a progression/network check, not a manual traversal or combat-balance playthrough.

Local logs and the inspected native-renderer revive screenshot are under the workspace's `work/coop-stress/` directory. Release CI additionally runs revival/position/course regressions and packaged mission smoke checks before publishing Windows and Linux installers.

## Reproduction

From a Windows checkout with configured editor relay keys:

```powershell
python distribution/verify_coop_stress.py --windows C:/path/to/Godot.exe --linux C:/path/to/Godot_linux.x86_64 --platforms windows,linux,windows,linux --output C:/path/to/test-output
```

Swap the platform order to test a Linux host. Add `--suite campaign` for all ten sectors. Each process uses an isolated user-data folder; existing player saves are not used. Physical controllers, voice-device/audio quality and two separate household connections still require hardware testing.
