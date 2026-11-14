# MUZZLUX - notes for an AI agent or a scripted tool

This file and `presets.json` next to it describe the pack in a form a coding agent can read
without opening a single scene. `presets.json` has the same content as data.

- Pack: **Free Bullet Impact VFX for Godot 4** (code name MUZZLUX), version 1.0, seller gennai.
- Godot 4.4 minimum. Verified on 4.4.1 and 4.7.2, each on Forward+, Mobile and
  Compatibility, with zero errors and zero warnings. Web export works.
- Everything is drawn by **static index meshes moved in the vertex shader**. There are no
  textures, no imported meshes, no `GPUParticles*`, no `Decal`, no compute shaders, no
  `SubViewport`, no audio.
- Addon folder: `res://addons/muzzlux_fx/`. Nothing outside it is needed at runtime.

## This is the free Lite build

Lite ships the impact side only: `MuzzluxImpact3D` and `Muzzlux.impact()` for three
surfaces. What it does not have:

- No muzzle flash and no tracer. Lite is the hit side only.
- Shots leave nothing behind: no bullet holes, no shell casings, no gun smoke.
- 3 surfaces of 9, and no automatic surface detection - you pass the string yourself.
- One set of colours. max_concurrent is capped at 4, so sustained fire drops hits.
- No energy weapons, no flashbang, no smoke grenade, no blood option, no 2D.

Upgrading is a folder copy: drop the full pack's `addons/muzzlux_fx` over this one. Every
export in Lite exists in the full pack with the same default, so nothing resets.
Full version: https://gennai.itch.io/gun-shooting-vfx-godot-4

## The call

```gdscript
# one impact node per surface, reused
var impact: MuzzluxImpact3D = $Impacts/Concrete
impact.burst(hit.position, hit.normal, &"concrete")

# or fire and forget
Muzzlux.impact_parent = self
Muzzlux.impact(hit.position, hit.normal, &"metal")
```

Lite has no surface table, so **pass the surface id yourself**. The three ids are
`&"concrete"`, `&"metal"` and `&"wood"`; anything else draws the concrete hit.

## Surfaces

| `surface` | Debris | Sparks | Cloud |
|---|---|---|---|
| `concrete` | grey chips, ballistic | none | a grey-white cone of powder that hangs |
| `metal` | tiny flakes | many, white-hot, short-lived, curving | a thin grey puff |
| `wood` | long splinters that spin | none | a tan puff |

## Globals

- `Muzzlux.quality` - LOW / MEDIUM / HIGH, element counts 35% / 65% / 100%
- `Muzzlux.wind` - Vector3, m/s. The cloud a hit throws off drifts with it.
- `Muzzlux.impact_parent` - where Muzzlux.impact() parents a fire-and-forget hit
- `Muzzlux.impact_scene` - use one scene for every surface instead of a preset per surface

## Node

### MuzzluxImpact3D
the material-specific impact for concrete, metal and wood

- Methods: `burst(position, normal, surface, strength, delay)`, `get_hit_count()`, `get_last_surface()`, `get_last_position()`, `get_live_count()`, `get_surface_ids()`, `duration_of(surface)`
- Signals: `hit_added(slot)`
## Presets (3)

| Preset | Node | What it is | Start it with |
|---|---|---|---|
| `impact_concrete` | MuzzluxImpact3D | Grey chips, a hanging cone of powder, a faint dust ring. | `Muzzlux.impact(p, n, &"concrete")` |
| `impact_metal` | MuzzluxImpact3D | Many white-hot curving sparks, metal flakes, a thin grey puff. | `Muzzlux.impact(p, n, &"metal")` |
| `impact_wood` | MuzzluxImpact3D | Long splinters that spin end over end, a tan puff. | `Muzzlux.impact(p, n, &"wood")` |

## Gotchas

- Lite has no surface table, so pass the surface id yourself: &"concrete", &"metal" or &"wood". An id Lite does not know draws the concrete hit.
- max_concurrent is capped at 4 in Lite. The full pack ships 16 and allows 32.
- Upgrading is a folder copy: drop the full pack's addons/muzzlux_fx over this one. Every export here exists there with the same default.
- The pack ships no audio of any kind.
