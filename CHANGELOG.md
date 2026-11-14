# RIFTCORE Alpha 6.0 — Fractured Connections

## Alpha 6.0

- Added 50 Core Enhancements across five sockets and 50 Shop products, including existing crafting materials, recovery supplies and temporary buffs.
- Renamed Blueprints to Crafting. Recovered blueprints go to Storage → Inventory after extraction. Learn them there to unlock recipes. Previously learned recipes carry forward.
- Assign four square quick slots from Inventory. Use the D-pad or keyboard 1–4 in a mission. Quick stacks hold five and inventory stacks hold 100.
- Made midair ladder grabs more forgiving. The menu cursor hides on controller input and returns on mouse movement or click.
- Unified the game and launcher under the Barlow Condensed font family.
- Moved Social next to Deploy. Start or join a group from Deploy or Social. Add recent teammates in Friends and compare seasonal best sector times on the Leaderboard. Friends’ times sync when you group together.
- Storage now handles equipping, swapping, and stowing gear. The separate Loadout station has been removed. Storage shows live DMG, DEF, ENG, HP, and SPD, and keeps access to boss abilities and saved gear presets.

- Launcher 0.2 now supports verified self-updates. Game updates keep one previous build and remove older, unmodified game packages to free disk space. Saves are unaffected.
- Added **Update Game** to Settings. Check releases and read patch notes in the game. From the title screen, install and restart without opening the launcher.
- Reorganized Settings into Display & Audio, Controls, and Update Game. The binding list scrolls independently.
- Fixed update installs that hit incomplete version folders. Updates verify the download and report the specific extraction, permission, or activation error when installation fails.
- Restored the personal HUD in co-op and moved mission and partner information to the right.
- Reduced guest movement delay with immediate local movement and faster input updates. The host still decides combat, damage and rewards. Both players need Alpha 6.0 to join the same room.
- Offline missions pause when the controller being used disconnects. Resume manually after reconnecting or switching input.
- Empty save slots start immediately, and Load Game only appears when there is a save to load.
- Added the game version in small text at the bottom right and removed the overlapping hub prompt frame.

## 5.9.1


- Choose a player name when creating a save. Names appear over operators in online sessions and in the partner direction indicator.
- Guests enter the room leader’s Operations Station through a loading screen. Each player’s camera follows their own operator.

- Social shows Steam IDs with Copy ID and Save actions, accepts numeric friend codes and profile links, and distinguishes your Steam connection from each friend’s presence.

- Play all ten campaign sectors with a friend. The leader chooses a sector, the party clears both acts and their bosses, and both players return to the same hub after extraction. Every co-op miniboss and boss door waits for both players. A player who falls outside a boss fight respawns independently. In the arena, a downed player waits until the boss falls or the team wipes.
- Explore Operations Station together after joining a room. Only the room leader can deploy or return the group. Inventories, equipment, and station menus remain personal.
- Co-op enemies have 2.5× health and damage. Both players receive the full shared reward, including 1.5× XP, bolts, and any blueprint discoveries. Use the System pad to save earned rewards.

- Online rooms use the RIFTCORE relay configuration included in the game. Social no longer asks players to enter keys.

- Tilt the left stick lightly to walk. Push it farther to run in the station and during missions.

- Moving or clicking the mouse shows an angular cyan pointer in menus. Click the player name, Steam contact, or room code to place the caret and type or paste.
- Quick Invite opens a room automatically for Steam friends playing RIFTCORE. Removed the redundant trader display from the station.
- Two live Windows clients can create a GD Sync room, join, and exchange data when configured.

- Mouse hover and keyboard focus work independently. Settings opens with keyboard focus on its first control, remapping has a clickable cancel button, and the hub interaction prompt supports mouse clicks.
- More blueprint and gear tiles fit on screen, with distinct part icons and tighter menu spacing.

- Social is now a hub pad. Find Steam Friends, save contacts, and create or join co-op preview rooms from there. Steam presence and invitations require a configured RIFTCORE Steam App ID and live services.
- Discover 12 blueprints per sector. Rarer blueprints drop less often, and Workshop lists recipes after you recover and extract them.
- Review mission stats and banked rewards after defeating the final boss of a sector and extracting.
- Bind gameplay actions to mouse buttons. Gameplay inputs are cleared when resuming from Pause.
- Storage, Loadout, and Workshop use compact gear tiles. LB and RB switch tabs within their stations, and Save and Settings share the System pad.

- The hub has a continuous floor, ceiling, and rear bulkhead. Deploy stays on its own pad. Workshop combines blueprints and Core Enhancements.
- The Loadout pad opens a redesigned screen with a live RX-07 display, actual equipped stats, gear, boss abilities, and presets.

- Fabrication puts RX-07 on the left and blueprints on the right, with clean item rows and readable rarity tags.
- Menu buttons turn purple while highlighted and return to blue when you move on. The separate outline is gone. Analog-stick menu navigation responds sooner and repeats while held.

- Aim and fire in either direction while climbing. Hold Up or Down to grab a ladder mid-dash. Step off at the top, or press Down + B on a one-way deck to drop through.
- Explore a rebuilt Operations Station with separate trader, forge, storage, and loadout bays, a central Deploy pad, and an orbital panorama.
- Menus and HUD use angular RIFTCORE UI frames, Barlow typography, and revised status displays.
- Gain a permanent Player Level alongside the Operator Level earned during a run. A defeated deployment loses its run progression and equipped gear. Stored gear and permanent progression survive.
- Collect pink salvage drops and extract to bank them. Spend recovered materials at Fabrication and use Core Shards at the enhancement station.
- Read sector briefings and recovered guardian memories in the NOVA Archive. The final extraction scene has two possible endings.
- The Co-op Setup Guide is available from Social and Pause. Builds without relay configuration show a status in Social and disable Create Room and Join Room.

Live room connections and Steam invitations require service configuration. Room codes work independently of Steam. The full v0.5 overhaul has further campaign, visual, and competitive-mode work tracked in RIFTCORE_DEVELOPMENT.md.

## Installer and launcher 0.2

- On Linux, add the native executable named RIFTCORE to Steam and leave Proton disabled. The launcher now defaults to Wayland with X11 fallback.
- Launcher 0.1 receives an in-place upgrade to 0.2 through its existing Update and Play button. The upgraded launcher then checks the preview channel.

- Added an Arch Linux and Omarchy tarball with native Wayland startup, an optional app-menu installer, and updates through the launcher.

- New RIFTCORE icon and wordmark on the launcher, game executable, and installer.
- The Linux installer adds a desktop entry for the updater. Windows and Linux keep using the same launcher to download and verify updates.
- Optionally open Steam's Add a Non-Steam Game dialog during setup and select the installed launcher.
- See the newest game's patch notes in the launcher before installing an update.
