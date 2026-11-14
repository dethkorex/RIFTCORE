@tool
@icon("res://addons/arcflux_fx/icons/palette.svg")
class_name ArcfluxPalette
extends Resource
## Colour set shared by every ARCFLUX effect.
## Colours are picked in sRGB; the energy values push them into HDR so glow can pick them up.

@export var core_color: Color = Color(0.86, 0.93, 1.0):
	set(value):
		core_color = value
		emit_changed()
@export var glow_color: Color = Color(0.24, 0.52, 1.0):
	set(value):
		glow_color = value
		emit_changed()
@export_range(0.0, 32.0, 0.01) var core_energy: float = 5.0:
	set(value):
		core_energy = value
		emit_changed()
@export_range(0.0, 32.0, 0.01) var glow_energy: float = 2.2:
	set(value):
		glow_energy = value
		emit_changed()
## Colour of the OmniLight3D pulses. Usually a slightly desaturated glow colour.
@export var light_color: Color = Color(0.55, 0.72, 1.0):
	set(value):
		light_color = value
		emit_changed()
## Tint used for sparks and embers.
@export var spark_color: Color = Color(0.7, 0.85, 1.0):
	set(value):
		spark_color = value
		emit_changed()


static func make_default() -> ArcfluxPalette:
	return ArcfluxPalette.new()
