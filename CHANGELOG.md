# RIFTCORE 0.5 — Fractured Connections (development preview)

## Game changes

- The cursor is visible on the title screen, inside the station, and when paused.
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

Live room connections and Steam invitations require service configuration. Shared campaign gameplay is still in development. The full v0.5 overhaul has further campaign, visual, and competitive-mode work tracked in RIFTCORE_DEVELOPMENT.md.

## Installer and launcher 0.2

- On Linux, add the native executable named RIFTCORE to Steam and leave Proton disabled. The launcher now defaults to Wayland with X11 fallback.
- Launcher 0.1 receives an in-place upgrade to 0.2 through its existing Update and Play button. The upgraded launcher then checks the preview channel.

- Added an Arch Linux and Omarchy tarball with native Wayland startup, an optional app-menu installer, and updates through the launcher.

- New RIFTCORE icon and wordmark on the launcher, game executable, and installer.
- The Linux installer adds a desktop entry for the updater. Windows and Linux keep using the same launcher to download and verify updates.
- Optionally open Steam's Add a Non-Steam Game dialog during setup and select the installed launcher.
- See the newest game's patch notes in the launcher before installing an update.
