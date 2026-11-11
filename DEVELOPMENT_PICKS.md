# RIFTCORE development picks

RIFTCORE is currently running on Godot 4.7.2. These are recommendations; none are required by the project.

1. [Cyclops Level Builder](https://github.com/blackears/cyclopsLevelBuilder): Block out future sections directly in Godot, verify jump distances and clearance, then replace the blocks with the existing factory kit. Version 1.5.0 lists Godot 4.7 and later.
2. [GdUnit4](https://github.com/godot-gdunit-labs/gdUnit4): Turn the gameplay checks into editor-run regressions for checkpoints, life banking, controller input, and boss state changes.
3. [LimboAI](https://github.com/limbonaut/limboai): Use behavior trees and state machines once the second biome needs shared enemy behaviors or multiple bosses. Check the release against the Godot version before installing the native extension.
4. [ProtonScatter](https://store.godotengine.org/asset/hungryproton/protonscatter/): Place groups of background props with variation. Place platforms and combat landmarks by hand.

## Announcer voice

Start by auditioning [Adrian from Fish Audio's official voice library](https://fish.audio/DISCOVERY/) with the direction “tight arcade announcer, confident, punchy, one clean take.” Try a shorter, sharper “Start!” and a slightly brighter “Level up!” as separate clips. The game already plays local clips when present under `assets/audio/`: name them `voice_start` and `voice_level_up` with an OGG, WAV, or MP3 extension. No Fish Audio API call is made while playing.
