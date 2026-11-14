# Operations Station assets

Each scene is ready to instance by itself. Select its root to change the accent, sign, or terminal layout. The procedural mesh rebuilds in the editor and at runtime.

- Trader, Forge, Storage, and Loadout have distinct counters, screens, and props.
- Save, Settings, Challenges, and NOVA Archive use the console layout.
- Deploy Pad, Window Frame, Deck Section, and Operations Banner build the room around the bays.
- The orbital panorama was created with the built-in image generation tool as a background-only view of a starfield, orbital torus, shuttles, and a blue-violet planetary limb.

These scenes supply visuals. The hub script manages pad interactions and the avatar path. In the live hub, each station's pad and matching bay share an X position from the station list in scripts/home_hub.gd.
