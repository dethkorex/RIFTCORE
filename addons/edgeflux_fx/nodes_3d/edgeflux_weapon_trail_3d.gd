@tool
@icon("res://addons/edgeflux_fx/icons/trail.svg")
class_name EdgefluxWeaponTrail3D
extends EdgefluxEffect3D
## Sword / weapon trail. Add it as a child of the weapon (or of a bone attachment) and set
## base_offset and tip_offset along the blade. The ribbon is sampled every frame in world space
## and smoothed with Catmull-Rom curves, so fast swings stay round at any frame rate.
## Works the same on Forward+, Mobile and Compatibility (no GPU particle trails).

const TRAIL_SHADER: Shader = preload("res://addons/edgeflux_fx/shaders/edgeflux_trail.gdshader")
const TRAIL_SOLID_SHADER: Shader = preload("res://addons/edgeflux_fx/shaders/edgeflux_trail_solid.gdshader")

enum Style { GLOW, ENERGY, SOFT, ARCANE, SOLID }

## Shortest time between stored samples. Frames in between move the newest sample, so the
## trail cost does not grow with the frame rate.
const SAMPLE_INTERVAL: float = 1.0 / 90.0

## GLOW: white edge over a coloured body. ENERGY: streaks racing along. SOFT: feathered.
## ARCANE: drifting glow with twinkles. SOLID: flat colours and an outline (cel-shaded games).
@export var style: Style = _default(&"style", Style.GLOW):
	set(v):
		style = v
		_apply_style()
## Blade start, in this node's local space.
@export var base_offset: Vector3 = _default(&"base_offset", Vector3(0.0, 0.25, 0.0))
## Blade tip, in this node's local space.
@export var tip_offset: Vector3 = _default(&"tip_offset", Vector3(0.0, 1.2, 0.0))
## Optional nodes that override the offsets (e.g. markers on an animated weapon).
@export var base_node: Node3D
@export var tip_node: Node3D
## Draw new trail while true. See also auto_emit_speed.
@export var emitting: bool = true
## When above 0, the trail only draws while the tip moves faster than this (m/s before scale),
## so it appears during swings and stays hidden while the weapon is idle.
@export_range(0.0, 30.0, 0.01) var auto_emit_speed: float = _default(&"auto_emit_speed", 0.0)
## Seconds a point of the trail stays visible.
@export_range(0.03, 2.0, 0.005) var lifetime: float = _default(&"lifetime", 0.26)
## Older parts shrink toward the tip, which gives the crescent shape.
@export_range(0.0, 1.0, 0.01) var taper: float = _default(&"taper", 0.8)
## Part of the blade covered by the trail, from the tip down.
@export_range(0.05, 1.0, 0.01) var coverage: float = _default(&"coverage", 0.8)
@export_range(0.0, 0.5, 0.005) var edge_width: float = _default(&"edge_width", 0.1)
@export_range(0.2, 6.0, 0.01) var fade_power: float = _default(&"fade_power", 1.5)
## Extra points inserted between samples on fast swings (higher = rounder).
@export_range(1, 16) var max_subdivisions: int = 8

@export_group("Sparks")
## Throw small sparks from the tip while swinging fast.
@export var sparks: bool = _default(&"sparks", false)
@export_range(1.0, 120.0, 0.1) var spark_rate: float = _default(&"spark_rate", 30.0)

@export_group("Editor")
## Swing a ghost blade in the editor so the trail is visible while you tune it.
@export var preview_swing: bool = true

var _mi: MeshInstance3D
var _imesh: ImmediateMesh
var _light: OmniLight3D
var _clock: float = 0.0
var _bases: PackedVector3Array = PackedVector3Array()
var _tips: PackedVector3Array = PackedVector3Array()
var _times: PackedFloat32Array = PackedFloat32Array()
var _last_tip: Vector3 = Vector3.ZERO
var _has_last: bool = false
var _speed: float = 0.0
var _hold: float = 0.0
var _burst_left: float = 0.0
var _spark_acc: float = 0.0
var _light_level: float = 0.0


func _class_defaults() -> Dictionary:
	return {&"light_energy": 1.2, &"light_range": 3.0, &"loop_interval": 0.0}


func _build() -> void:
	_imesh = ImmediateMesh.new()
	_mi = make_mesh(_imesh, TRAIL_SHADER, true)
	_light = make_light()
	make_streak_pool(6, 8)
	_apply_style()


func _apply_style() -> void:
	if not _mi:
		return
	var m: ShaderMaterial = mat_of(_mi)
	m.shader = TRAIL_SOLID_SHADER if style == Style.SOLID else TRAIL_SHADER
	var s: int = 0
	match style:
		Style.ENERGY:
			s = 1
		Style.SOFT:
			s = 2
		Style.ARCANE:
			s = 3
	m.set_shader_parameter("style", s)


func _auto_replay() -> bool:
	return false


func _is_done() -> bool:
	return false


func _on_play() -> void:
	emitting = true


func _on_stop() -> void:
	emitting = false


## Starts drawing trail.
func start() -> void:
	emitting = true


## Draws trail for `seconds`, then stops by itself (one attack swing).
func burst(seconds: float) -> void:
	_burst_left = maxf(seconds, 0.0)


## Removes the current trail at once.
func clear() -> void:
	_bases.clear()
	_tips.clear()
	_times.clear()
	_has_last = false


func get_tip_position() -> Vector3:
	return _blade_points()[1]


func _blade_points() -> PackedVector3Array:
	var xf: Transform3D = global_transform
	if Engine.is_editor_hint() and preview_swing:
		var cyc: float = fmod(_clock, 1.6)
		var a: float = 0.0
		if cyc < 0.45:
			var k: float = cyc / 0.45
			a = lerpf(-1.4, 1.5, k * k * (3.0 - 2.0 * k))
		else:
			a = lerpf(1.5, -1.4, clampf((cyc - 0.45) / 1.15, 0.0, 1.0))
		xf = xf * Transform3D(Basis(Vector3.RIGHT, a), Vector3.ZERO)
	var b: Vector3 = base_node.global_position if base_node else xf * base_offset
	var t: Vector3 = tip_node.global_position if tip_node else xf * tip_offset
	return PackedVector3Array([b, t])


func _tick(dt: float) -> void:
	if not _mi:
		return
	_clock += dt
	var pts: PackedVector3Array = _blade_points()
	var b: Vector3 = pts[0]
	var t: Vector3 = pts[1]
	var s: float = world_scale()
	if _has_last and dt > 0.0:
		_speed = lerpf(_speed, _last_tip.distance_to(t) / dt, 0.5)
	_last_tip = t
	_has_last = true
	var on: bool = emitting
	if _burst_left > 0.0:
		_burst_left -= dt
		on = true
	if auto_emit_speed > 0.0:
		if _speed > auto_emit_speed * s:
			_hold = 0.06
		else:
			_hold -= dt
		on = on and _hold > 0.0
	if Engine.is_editor_hint() and preview_swing:
		on = fmod(_clock, 1.6) < 0.5
	if on:
		var n: int = _times.size()
		if n > 1 and (_clock - _times[n - 2] < SAMPLE_INTERVAL or _tips[n - 1].distance_squared_to(t) < 0.000004 * s * s):
			_bases[n - 1] = b
			_tips[n - 1] = t
			_times[n - 1] = _clock
		else:
			_bases.append(b)
			_tips.append(t)
			_times.append(_clock)
	var cut: int = 0
	while cut < _times.size() - 1 and _clock - _times[cut + 1] > lifetime:
		cut += 1
	if cut > 0:
		_bases = _bases.slice(cut)
		_tips = _tips.slice(cut)
		_times = _times.slice(cut)
	if _times.size() == 1 and _clock - _times[0] > lifetime:
		clear()
	_rebuild()
	_update_material()
	if sparks and on and _speed > 4.0 * s:
		_spark_acc += dt * spark_rate
		while _spark_acc >= 1.0:
			_spark_acc -= 1.0
			var dir: Vector3 = (t - b).normalized()
			emit_streaks({"mode": 0, "origin": t, "origin_b": t.lerp(b, 0.3), "emit_dir": dir, "spread": 1.2,
				"speed_min": 1.0, "speed_max": 3.5, "life_min": 0.15, "life_max": 0.4, "gravity": 6.0,
				"drag": 3.0, "streak": 0.05, "width": 0.012, "delay_spread": 0.0, "intensity": intensity}, 2.0 * s)
	var target: float = clampf((_speed / s - 3.0) / 10.0, 0.0, 1.0) if on else 0.0
	_light_level = lerpf(_light_level, target, clampf(dt * 12.0, 0.0, 1.0))
	_light.global_position = t.lerp(b, 0.3)
	drive_light(_light, _light_level)


func _update_material() -> void:
	var m: ShaderMaterial = mat_of(_mi)
	m.set_shader_parameter("time", _clock)
	m.set_shader_parameter("taper", taper)
	m.set_shader_parameter("coverage", coverage)
	m.set_shader_parameter("edge_width", edge_width)
	m.set_shader_parameter("fade_power", fade_power)
	m.set_shader_parameter("intensity", intensity)


func _catmull(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2: float = t * t
	var t3: float = t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


func _rebuild() -> void:
	_imesh.clear_surfaces()
	var n: int = _times.size()
	if n < 2:
		_mi.visible = false
		return
	_mi.visible = true
	var bs: PackedVector3Array = PackedVector3Array()
	var ts: PackedVector3Array = PackedVector3Array()
	var ages: PackedFloat32Array = PackedFloat32Array()
	for i in n - 1:
		var i0: int = maxi(i - 1, 0)
		var i3: int = mini(i + 2, n - 1)
		var d0: Vector3 = (_tips[i] - _bases[i]).normalized()
		var d1: Vector3 = (_tips[i + 1] - _bases[i + 1]).normalized()
		var ang: float = d0.angle_to(d1)
		var sub: int = clampi(int(ceilf(ang / deg_to_rad(5.0))), 1, max_subdivisions)
		for k in sub:
			var f: float = float(k) / float(sub)
			bs.append(_catmull(_bases[i0], _bases[i], _bases[i + 1], _bases[i3], f))
			ts.append(_catmull(_tips[i0], _tips[i], _tips[i + 1], _tips[i3], f))
			ages.append(clampf((_clock - lerpf(_times[i], _times[i + 1], f)) / lifetime, 0.0, 1.0))
	bs.append(_bases[n - 1])
	ts.append(_tips[n - 1])
	ages.append(clampf((_clock - _times[n - 1]) / lifetime, 0.0, 1.0))
	var lo: Vector3 = ts[0]
	var hi: Vector3 = ts[0]
	_imesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in bs.size() - 1:
		var a0: float = ages[i]
		var a1: float = ages[i + 1]
		_vtx(bs[i], Vector2(a0, 0.0))
		_vtx(ts[i], Vector2(a0, 1.0))
		_vtx(bs[i + 1], Vector2(a1, 0.0))
		_vtx(ts[i], Vector2(a0, 1.0))
		_vtx(ts[i + 1], Vector2(a1, 1.0))
		_vtx(bs[i + 1], Vector2(a1, 0.0))
		lo = lo.min(bs[i]).min(ts[i])
		hi = hi.max(bs[i]).max(ts[i])
	_imesh.surface_end()
	lo = lo.min(bs[bs.size() - 1]).min(ts[ts.size() - 1])
	hi = hi.max(bs[bs.size() - 1]).max(ts[ts.size() - 1])
	_mi.custom_aabb = AABB(lo, hi - lo).grow(0.1)


func _vtx(p: Vector3, uv: Vector2) -> void:
	_imesh.surface_set_uv(uv)
	_imesh.surface_add_vertex(p)
