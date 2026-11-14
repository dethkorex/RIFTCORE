@tool
@icon("res://addons/edgeflux_fx/icons/palette.svg")
class_name EdgefluxPalette
extends Resource
## Colour set shared by every EDGEFLUX effect. Ready-made palettes live in
## addons/edgeflux_fx/palettes/. Edit a copy to make your own.

## White-hot edge of blades, flashes and spark heads.
@export var core_color: Color = Color(0.92, 0.96, 1.0):
	set(v):
		core_color = v
		emit_changed()
## Main body colour.
@export var glow_color: Color = Color(0.3, 0.6, 1.0):
	set(v):
		glow_color = v
		emit_changed()
## Colour of the fading tail and outer rim.
@export var tail_color: Color = Color(0.12, 0.2, 0.75):
	set(v):
		tail_color = v
		emit_changed()
## Spark colour once the white-hot start has cooled.
@export var spark_color: Color = Color(0.55, 0.8, 1.0):
	set(v):
		spark_color = v
		emit_changed()
## Dark outline used by the SOLID style and the 2D pixel mode.
@export var outline_color: Color = Color(0.04, 0.06, 0.16):
	set(v):
		outline_color = v
		emit_changed()
## Colour of the light that effects cast on the scene.
@export var light_color: Color = Color(0.55, 0.75, 1.0):
	set(v):
		light_color = v
		emit_changed()
## Brightness of the core. Values above 1 bloom when glow is enabled.
@export_range(0.0, 8.0, 0.01) var core_energy: float = 2.0:
	set(v):
		core_energy = v
		emit_changed()
## Brightness of the body and tail.
@export_range(0.0, 8.0, 0.01) var glow_energy: float = 1.4:
	set(v):
		glow_energy = v
		emit_changed()


## Pushes the colours into a shader material that uses the shared uniform names.
func apply_to(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("core_color", core_color)
	mat.set_shader_parameter("glow_color", glow_color)
	mat.set_shader_parameter("tail_color", tail_color)
	mat.set_shader_parameter("spark_color", spark_color)
	mat.set_shader_parameter("outline_color", outline_color)
	mat.set_shader_parameter("core_energy", core_energy)
	mat.set_shader_parameter("glow_energy", glow_energy)
