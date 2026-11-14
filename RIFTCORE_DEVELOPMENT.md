# RIFTCORE v0.5 — Fractured Connections

Status: in development. Baseline checkpoint: 970d50a. The playable v0.5.0-preview release is available separately from the stable update channel.

## Phase 1 audit

- Campaign: 20 authored scenes, 10 sector bosses, shared miniboss, sector route generator, checkpoints, extraction and continuation. Rooms currently form a mostly linear route.
- Player: shared RX-07 controller, wall kicks, slide dash, buster and saber, climb-through deck assembly, ladder aiming, weapon rewards and local HUD.
- Progression: XP belongs to a run checkpoint. Three manual slots store inventory, workshop ranks, challenge rewards and an optional deployment. A finalized death invalidates the on-disk deployment.
- Nexus: walkable station with deployment, storage, equipment presets, shop, workshop, challenge log and settings. Shop and workshop currently use bolts.
- Combat: themed enemies and boss variants already exist. Preserve their bodies and use shared drop hooks.
- Distribution: Windows/Linux installers and GitHub updater. The game itself has no multiplayer integration or leaderboards yet.
- Art references: local RIFTCORE UI guide, contact sheet and compact ZIP were located in Downloads.
- Existing suites: sector_progression and campaign_progression. Add coverage for slot migration and new v0.5 rules.

## Milestones

| Phase | Status |
| --- | --- |
| 1 Audit and checkpoint | Baseline recorded |
| 2 Operator/player progression | Separate levels and save migration integrated |
| 3 Fabrication/materials | Enemy, cargo and boss salvage, recipes and storage integrated |
| 4 Core Shards | Six permanent upgrade paths integrated |
| 5 Story | Briefings, archive and endings integrated. Intro scene and additional milestone dialogue pending |
| 6 Steam co-op | Relay room-code preview and setup guide integrated. Steam invites, gameplay sync, and live test pending |
| 7 Expanded levels | Pending |
| 8 Puzzles | Pending |
| 9 Procedural rooms | Pending |
| 10 UI overhaul | Shared typography, angular kit frames, equipment cards, pause, HUD, and Operations Station integrated. Full page-by-page review pending |
| 11 Enemy model polish | Pending |
| 12 Leaderboards and time trials | Pending |
| 13 Verification | Offline campaign and sector regression suites, ladder aim, save migration, permanent progression, relay UI and launcher patch notes checks passed. Live relay and installers still require runtime testing |

## Distribution and onboarding

- Transparent SVG icon and wordmark added. The Windows launcher/game presets embed the derived ICO. The Windows and Linux installer sources use the updated branding and offer an optional shortcut handoff to Steam.
- The title and Pause menu expose a co-op setup guide. Online rooms use the GD Sync relay path. A build without service configuration reports that the preview is unavailable.
- A full Steam and remote gameplay test requires a configured service, host-authoritative synchronization, and two actual Steam accounts.
