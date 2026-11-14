@tool
@icon("res://addons/blastlux_fx/icons/palette.svg")
class_name BlastluxPalette
extends Resource
## Colours of one blast family. Written as you see them (sRGB); the shaders turn them linear.

## The white-hot centre of the fireball and the flash.
@export var core: Color = Color(1.0, 0.93, 0.7, 1.0)
## The body of the fireball.
@export var hot: Color = Color(1.0, 0.5, 0.1, 1.0)
## The cooling edge of the fireball, embers and sparks.
@export var cool: Color = Color(0.75, 0.14, 0.02, 1.0)
## Smoke the fireball turns into.
@export var smoke: Color = Color(0.17, 0.15, 0.14, 0.85)
## Dust the blast lifts off the ground (the skirt and the ground ring).
@export var dust: Color = Color(0.42, 0.36, 0.28, 0.8)
## Light the blast throws on its surroundings (the OmniLight3D and the heat on scorched meshes).
@export var light: Color = Color(1.0, 0.62, 0.25, 1.0)
## Soot left on meshes and the ground.
@export var scorch: Color = Color(0.06, 0.05, 0.045, 1.0)
## Multiplier for the glowing parts.
@export_range(0.0, 8.0, 0.01) var emission: float = 2.4


func apply_to(mat: ShaderMaterial) -> void:
	if mat == null:
		return
	mat.set_shader_parameter("col_core", core)
	mat.set_shader_parameter("col_hot", hot)
	mat.set_shader_parameter("col_cool", cool)
	mat.set_shader_parameter("col_smoke", smoke)
	mat.set_shader_parameter("col_dust", dust)
	mat.set_shader_parameter("emission", emission)
