# RIFTCORE Alpha 6.3.57

## Stability and cleanup

- Quitting from the menu or the game window now stops music, sound effects, and party voice and lets the audio mixer release them before the game exits.
- Signed-in play still runs cloud save and relay sign-out cleanup before the final exit.
- Removed unused Workshop, Social, Steam contact, and arena helpers.
- Updated sector regression checks to match the current boss HP, attack damage, and difficulty scaling. Release tests now check for audio resources left alive at shutdown.

## Boss encounters

- Minibosses and main bosses materialize on illuminated deployment pads with a faster entrance and a clear name reveal.
- Forge Titan’s ground slam drops a lit amber core from the new arena roof. Bait the drill into the core to shatter it and expose Titan’s armor.
- Both Ember Foundry arenas now have a rising-lava attack with a warning and accessible upper platforms. Kiln Warden’s purge valves still provide its opening.

## Buster controls

- Movement uses horizontal shots. Aim straight up with Up, or straight down with Down while falling. Crouch and ladder shots stay horizontal in solo and co-op.
