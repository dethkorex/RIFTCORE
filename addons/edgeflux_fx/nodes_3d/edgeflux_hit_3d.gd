@tool
@icon("res://addons/edgeflux_fx/icons/hit.svg")
class_name EdgefluxHit3D
extends EdgefluxEffect3D
## Hit impact: flash, expanding ring, sparks thrown off the surface and a light pulse.
## hit(position, normal) plays it at a point (one node can serve many hits);
## play() uses the node's own position with its +Y axis as the surface normal.

enum Style { SPARK, CRITICAL, BLUNT, MAGIC }

@export var style: Style = _default(&"style", Style.SPARK)
## Overall size, in metres before node scale.
@export_range(0.05, 10.0, 0.01, "or_greater") var size: float = _default(&"size", 1.0)
## Seconds the flash and ring last.
@export_range(0.05, 2.0, 0.01) var duration: float = _default(&"duration", 0.35)
@export_range(0, 64) var spark_count: int = _default(&"spark_count", 26)
## Spark speed multiplier.
@export_range(0.0, 4.0, 0.01) var spark_speed: float = _default(&"spark_speed", 1.0)
## Sparks fall with gravity (metal) or float (magic).
@export_range(-20.0, 30.0, 0.1) var spark_gravity: float = _default(&"spark_gravity", 9.0)

var _star: MeshInstance3D
var _glow: MeshInstance3D
var _ring: MeshInstance3D
var _ring2: MeshInstance3D
var _light: OmniLight3D
var _pos: Vector3 = Vector3.ZERO
var _normal: Vector3 = Vector3.UP


func _class_defaults() -> Dictionary:
	return {&"light_energy": 3.0, &"light_range": 3.0}


func _build() -> void:
	_glow = make_flare(0)
	_star = make_flare(1)
	_ring = make_flare(2, false)
	_ring2 = make_flare(2)
	_light = make_light()
	make_streak_pool(3, 64)


## Plays the hit at a world position. `normal` points away from the struck surface.
func hit(at: Vector3, normal: Vector3 = Vector3.ZERO) -> void:
	_pos = at
	_normal = normal.normalized() if normal.length_squared() > 1e-6 else Vector3.ZERO
	_start()


func _on_play() -> void:
	pass


func play() -> void:
	_pos = global_position if is_inside_tree() else Vector3.ZERO
	_normal = Vector3.ZERO
	_start()


func _start() -> void:
	super.play()
	if not _star:
		return
	var n: Vector3 = _normal if _normal != Vector3.ZERO else global_basis.y.normalized()
	var s: float = world_scale()
	for mi: MeshInstance3D in [_star, _glow, _ring, _ring2]:
		mi.global_position = _pos
	_light.global_position = _pos + n * 0.3 * s * size
	var up: Vector3 = Vector3.UP if absf(n.y) < 0.95 else Vector3.RIGHT
	_ring.global_basis = Basis.looking_at(-n, up).scaled(Vector3.ONE * s)
	_star.rotation.z = rng.randf() * TAU
	mat_of(_star).set_shader_parameter("rotation", rng.randf() * TAU)
	mat_of(_star).set_shader_parameter("seed", rng.randf() * 100.0)
	var cnt: float = clampf(float(spark_count) / 64.0, 0.0, 1.0)
	var spd: float = spark_speed * size
	match style:
		Style.SPARK:
			emit_streaks({"mode": 0, "origin": _pos, "origin_b": _pos, "emit_dir": n, "spread": 1.25,
				"speed_min": 3.0 * spd, "speed_max": 9.0 * spd, "life_min": 0.2, "life_max": 0.55,
				"gravity": spark_gravity, "drag": 2.5, "streak": 0.045, "width": 0.022 * size,
				"delay_spread": 0.0, "count_fraction": cnt, "intensity": intensity, "taper": 0.7}, 6.0 * s * size)
		Style.CRITICAL:
			emit_streaks({"mode": 0, "origin": _pos, "origin_b": _pos, "emit_dir": n, "spread": 1.5,
				"speed_min": 4.0 * spd, "speed_max": 12.0 * spd, "life_min": 0.3, "life_max": 0.75,
				"gravity": spark_gravity, "drag": 2.2, "streak": 0.05, "width": 0.03 * size,
				"delay_spread": 0.0, "count_fraction": cnt, "intensity": intensity * 1.2, "taper": 0.7}, 8.0 * s * size)
			emit_streaks({"mode": 0, "origin": _pos, "origin_b": _pos, "emit_dir": n, "spread": 3.14,
				"speed_min": 1.0 * spd, "speed_max": 3.0 * spd, "life_min": 0.4, "life_max": 0.9,
				"gravity": 1.0, "drag": 3.0, "streak": 0.03, "width": 0.04 * size,
				"delay_spread": 0.05, "count_fraction": cnt * 0.6, "intensity": intensity, "taper": 0.3}, 4.0 * s * size)
		Style.BLUNT:
			emit_streaks({"mode": 0, "origin": _pos, "origin_b": _pos, "emit_dir": n, "spread": 1.4,
				"speed_min": 1.5 * spd, "speed_max": 4.5 * spd, "life_min": 0.25, "life_max": 0.5,
				"gravity": spark_gravity, "drag": 4.0, "streak": 0.06, "width": 0.05 * size,
				"delay_spread": 0.0, "count_fraction": cnt * 0.6, "intensity": intensity * 0.8, "taper": 0.4}, 4.0 * s * size)
		Style.MAGIC:
			emit_streaks({"mode": 0, "origin": _pos, "origin_b": _pos, "emit_dir": n, "spread": 3.14,
				"speed_min": 1.0 * spd, "speed_max": 4.0 * spd, "life_min": 0.4, "life_max": 0.9,
				"gravity": -1.5, "drag": 3.5, "streak": 0.02, "width": 0.035 * size,
				"delay_spread": 0.08, "count_fraction": cnt, "intensity": intensity, "taper": 0.1, "hot_time": 0.15}, 4.0 * s * size)


func _is_done() -> bool:
	return age > duration * 2.2 and not streaks_busy()


func _tick(_dt: float) -> void:
	if not _star:
		return
	var t: float = age / duration
	var big: float = 1.0
	var rays: float = 6.0
	var star_on: float = 1.0
	var glow_k: float = 0.5
	var ring_w: float = 0.07
	var ring2_on: float = 0.0
	match style:
		Style.CRITICAL:
			big = 1.6
			rays = 8.0
			ring2_on = 1.0
			glow_k = 0.8
		Style.BLUNT:
			rays = 5.0
			star_on = 0.45
			glow_k = 0.9
			ring_w = 0.16
		Style.MAGIC:
			rays = 4.0
			star_on = 0.6
			glow_k = 1.0
			ring2_on = 0.7
			ring_w = 0.05
	var flash: float = envelope(t, 0.04, 0.55, 0.45)
	var sm: ShaderMaterial = mat_of(_star)
	sm.set_shader_parameter("intensity", flash * star_on * intensity * 1.6)
	sm.set_shader_parameter("size", size * big * (0.45 + 0.5 * clampf(t * 3.0, 0.0, 1.0)))
	sm.set_shader_parameter("rays", rays)
	sm.set_shader_parameter("ray_length", 1.0 - t * 0.6)
	_star.visible = flash > 0.0
	var gm: ShaderMaterial = mat_of(_glow)
	var gl: float = envelope(t, 0.02, 1.0, 0.85)
	gm.set_shader_parameter("intensity", gl * glow_k * intensity)
	gm.set_shader_parameter("size", size * big * (0.6 + 0.4 * t))
	gm.set_shader_parameter("core_size", 0.18)
	_glow.visible = gl > 0.0
	var k: float = 1.0 - pow(1.0 - clampf(t / 1.2, 0.0, 1.0), 3.0)
	var rr: float = envelope(t, 0.03, 1.2, 0.9)
	var rm: ShaderMaterial = mat_of(_ring)
	rm.set_shader_parameter("intensity", rr * intensity)
	rm.set_shader_parameter("size", size * big * (0.25 + 1.0 * k))
	rm.set_shader_parameter("ring_radius", 0.72)
	rm.set_shader_parameter("ring_width", ring_w * (1.0 - k * 0.6))
	_ring.visible = rr > 0.0
	var r2: float = envelope(t - 0.1, 0.03, 1.1, 0.8) * ring2_on
	var r2m: ShaderMaterial = mat_of(_ring2)
	r2m.set_shader_parameter("intensity", r2 * intensity * 0.8)
	r2m.set_shader_parameter("size", size * big * (0.3 + 0.9 * k))
	r2m.set_shader_parameter("ring_radius", 0.75)
	r2m.set_shader_parameter("ring_width", 0.04)
	_ring2.visible = r2 > 0.0
	drive_light(_light, envelope(t, 0.02, 1.0, 0.8))
