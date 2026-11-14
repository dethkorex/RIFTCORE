@tool
@icon("res://addons/blastlux_fx/icons/effect.svg")
class_name BlastluxShockwave3D
extends BlastluxEffect3D
## The wave on its own: a dust ring racing over the ground, a translucent pressure disc that
## stands up through the air, and a heat ripple that bends what is behind it (Forward+ and
## Mobile; Compatibility shows the ring and the disc). Use it under an airburst, a landing, a
## spell, or anything that should push the air without a fireball.
##
##   $Shockwave.wave_at(point, 6.0)

const RING: Shader = preload("res://addons/blastlux_fx/shaders/blastlux_ring.gdshader")
const PUFF: Shader = preload("res://addons/blastlux_fx/shaders/blastlux_puff.gdshader")
const RIPPLE: Shader = preload("res://addons/blastlux_fx/shaders/blastlux_ripple.gdshader")

## How far the wave travels, in metres.
@export_range(0.5, 100.0, 0.1, "or_greater") var radius: float = _default(&"radius", 6.0)
@export_range(1.0, 80.0, 0.1) var wave_speed: float = _default(&"wave_speed", 16.0)
## The dust ring on the ground.
@export var ring: bool = _default(&"ring", true):
	set(value):
		ring = value
		_rebuild_queued = true
## Low dust puffs the ring kicks up.
@export var dust: bool = _default(&"dust", true):
	set(value):
		dust = value
		_rebuild_queued = true
## The pressure disc that stands up through the air.
@export var disc: bool = _default(&"disc", true):
	set(value):
		disc = value
		_rebuild_queued = true
## The heat ripple (screen refraction). Not drawn on Compatibility.
@export var ripple: bool = _default(&"ripple", true):
	set(value):
		ripple = value
		_rebuild_queued = true
@export_range(0.0, 2.0, 0.01) var ripple_strength: float = _default(&"ripple_strength", 1.0)
@export_range(0.05, 3.0, 0.01) var thickness: float = _default(&"thickness", 0.5)
@export var ground_from_raycast: bool = true

var _ring_mat: ShaderMaterial
var _dust_mat: ShaderMaterial
var _disc_mat: ShaderMaterial
var _ripple_mat: ShaderMaterial
var _ground_y: float = 0.0


func _class_defaults() -> Dictionary:
	return {&"light_enabled": false, &"preview_interval": 3.0}


func is_one_shot() -> bool:
	return true


func get_duration() -> float:
	return radius / maxf(wave_speed, 0.1) + 1.2


func _extent() -> Vector3:
	return Vector3(radius + 1.0, radius * 0.6 + 1.0, radius + 1.0)


## Moves to `point` and sends the wave out.
func wave_at(point: Vector3, new_radius: float = -1.0) -> void:
	global_position = point
	_last_pos = point
	_velocity = Vector3.ZERO
	if new_radius > 0.0:
		radius = new_radius
	trigger()


func wave() -> void:
	trigger()


func _on_trigger() -> void:
	var p: Vector3 = global_position
	_ground_y = ground_below(p + Vector3(0.0, 0.3, 0.0), 4.0, p.y) if ground_from_raycast else p.y


func _build() -> void:
	_dust_mat = make_layer(PUFF, BlastluxMeshes.quads(count_for(36)), -1) if dust else null
	_ring_mat = make_layer(RING, BlastluxMeshes.quads(1), 1) if ring else null
	_disc_mat = make_layer(RING, BlastluxMeshes.quads(1), 2) if disc else null
	_ripple_mat = make_layer(RIPPLE, BlastluxMeshes.quads(1), 3) if ripple else null


func _emitter_transform() -> Transform3D:
	var t: Transform3D = global_transform
	if _burst_age >= 0.0:
		t.origin.y = _ground_y
	return t


func _tick(_delta: float) -> void:
	var r: float = radius
	var dur: float = r / maxf(wave_speed, 0.1)
	if _ring_mat:
		var m: ShaderMaterial = _ring_mat
		m.set_shader_parameter("kind", 1)
		m.set_shader_parameter("facing", 0)
		m.set_shader_parameter("delay", 0.0)
		m.set_shader_parameter("radius", r)
		m.set_shader_parameter("wave_speed", wave_speed)
		m.set_shader_parameter("duration", dur + 0.3)
		m.set_shader_parameter("thickness", thickness)
		m.set_shader_parameter("height_offset", 0.05)
		m.set_shader_parameter("intensity", 1.0)
	if _disc_mat:
		var m: ShaderMaterial = _disc_mat
		m.set_shader_parameter("kind", 2)
		m.set_shader_parameter("facing", 1)
		m.set_shader_parameter("delay", 0.0)
		m.set_shader_parameter("radius", r * 0.7)
		m.set_shader_parameter("wave_speed", wave_speed)
		m.set_shader_parameter("duration", dur * 0.7 + 0.2)
		m.set_shader_parameter("thickness", thickness * 0.8)
		m.set_shader_parameter("height_offset", 0.0)
		m.set_shader_parameter("intensity", 0.9)
	if _ripple_mat:
		var m: ShaderMaterial = _ripple_mat
		m.set_shader_parameter("radius", r * 0.75)
		m.set_shader_parameter("wave_speed", wave_speed)
		m.set_shader_parameter("duration", dur * 0.75 + 0.15)
		m.set_shader_parameter("thickness", thickness * 1.4)
		m.set_shader_parameter("strength", ripple_strength)
	if _dust_mat:
		var m: ShaderMaterial = _dust_mat
		m.set_shader_parameter("mode", 0)
		m.set_shader_parameter("kind", 2)
		m.set_shader_parameter("shape", 1)
		m.set_shader_parameter("shape_size", r * 0.25)
		m.set_shader_parameter("spawn_offset", Vector3(0.0, 0.1, 0.0))
		m.set_shader_parameter("spread_mode", 2)
		m.set_shader_parameter("spread", 0.3)
		# Drag stops the dust at about the wave's radius (speed / drag), so a small wave does not
		# blow its dust past the camera (a 3.6 m wave used to carry it 5.5 m).
		m.set_shader_parameter("speed", minf(wave_speed * 0.55, r * 1.6))
		m.set_shader_parameter("speed_var", 0.35)
		m.set_shader_parameter("drag", 1.6)
		m.set_shader_parameter("buoyancy", 0.4)
		m.set_shader_parameter("turbulence", 0.15)
		m.set_shader_parameter("lifetime", dur + 0.8)
		m.set_shader_parameter("lifetime_var", 0.3)
		m.set_shader_parameter("spawn_window", 0.1)
		m.set_shader_parameter("delay", 0.02)
		m.set_shader_parameter("size_start", r * 0.08)
		m.set_shader_parameter("size_end", r * 0.3)
		m.set_shader_parameter("size_curve", 0.6)
		m.set_shader_parameter("heat", 0.0)
		m.set_shader_parameter("cool_rate", 0.0)
		m.set_shader_parameter("opacity", 0.55)
		m.set_shader_parameter("fade_in", 0.05)
		m.set_shader_parameter("fade_out", 0.5)
		m.set_shader_parameter("erosion", 0.5)
		m.set_shader_parameter("noise_scale", 1.4)
		m.set_shader_parameter("ground_y", _ground_y)
