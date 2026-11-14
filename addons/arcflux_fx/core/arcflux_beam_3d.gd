@tool
@icon("res://addons/arcflux_fx/icons/beam.svg")
class_name ArcfluxBeam3D
extends ArcfluxEffect3D
## Base for continuous beams. Fires along local -Z (or toward target), stops at the first
## physics hit and draws a muzzle glow, the body and an impact with sparks and light.

## Aim at this node instead of local -Z. The beam length follows the distance.
@export var target: Node3D
@export_range(0.1, 500.0, 0.1, "or_greater") var max_length: float = 20.0
## Stop the beam at the first collision.
@export var collide: bool = true
@export_flags_3d_physics var collision_mask: int = 1
## Fade in/out time used by set_active().
@export_range(0.0, 2.0, 0.01) var ramp_time: float = _default(&"ramp_time", 0.12)

@export_group("Body")
@export_range(0.005, 5.0, 0.001, "or_greater") var width: float = _default(&"width", 0.22)
@export_range(0.02, 1.0, 0.01) var core_ratio: float = _default(&"core_ratio", 0.28)
@export_range(0.0, 20.0, 0.1) var halo_width: float = _default(&"halo_width", 4.0)
## Strength of the coloured glow inside the body. Lower keeps thick beams saturated.
@export_range(0.0, 4.0, 0.01) var body_glow: float = _default(&"body_glow", 1.0)
## Strength of the wide outer glow strip.
@export_range(0.0, 4.0, 0.01) var outer_glow: float = _default(&"outer_glow", 0.25)
## Speed of the noise flowing along the beam (units per second).
@export_range(-100.0, 100.0, 0.1) var flow_speed: float = _default(&"flow_speed", 14.0)
@export_range(0.0, 1.0, 0.01) var edge_noise: float = _default(&"edge_noise", 0.3)
@export_range(0.0, 1.0, 0.01) var body_noise: float = _default(&"body_noise", 0.35)
## Width wobble travelling along the body (0 = straight edges).
@export_range(0.0, 1.0, 0.01) var turbulence: float = _default(&"turbulence", 0.0)
## Width pulse amount and speed.
@export_range(0.0, 1.0, 0.01) var pulse: float = _default(&"pulse", 0.08)
@export_range(0.0, 60.0, 0.1) var pulse_speed: float = _default(&"pulse_speed", 22.0)

@export_group("Muzzle")
@export_range(0.0, 10.0, 0.01) var muzzle_flare_size: float = _default(&"muzzle_flare_size", 1.0)

@export_group("Impact")
@export_range(0.0, 10.0, 0.01) var impact_flare_size: float = _default(&"impact_flare_size", 1.4)
@export_range(0.0, 400.0, 0.1) var impact_sparks_per_second: float = _default(&"impact_sparks_per_second", 40.0)
## Draw the impact even when the beam hits nothing (at max_length).
@export var impact_in_air: bool = false

var _body: MeshInstance3D
var _body_mat: ShaderMaterial
var _muzzle: MeshInstance3D
var _impact: MeshInstance3D
var _light: OmniLight3D
var _sparks: ArcfluxSparks
var _builder: ArcfluxRibbon = ArcfluxRibbon.new()
var _active: bool = false
var _level: float = 0.0
var _flow: float = 0.0
var _time: float = 0.0
var _spark_acc: float = 0.0
var _hit: bool = false
var _hit_point: Vector3 = Vector3.ZERO
var _hit_normal: Vector3 = Vector3.UP
var _length: float = 0.0
var _dir: Vector3 = Vector3.FORWARD
var _seed_offset: float = 0.0


func _build() -> void:
	_body = make_ribbon(BEAM_SHADER)
	_body_mat = _body.material_override as ShaderMaterial
	_seed_offset = rng.randf() * 100.0
	_muzzle = make_flare(muzzle_flare_size)
	_impact = make_flare(impact_flare_size)
	_light = make_light()
	_sparks = ArcfluxSparks.new(make_ribbon(RIBBON_SHADER, true))
	(_sparks.mesh_instance.material_override as ShaderMaterial).set_shader_parameter("core_ratio", 0.35)
	(_sparks.mesh_instance.material_override as ShaderMaterial).set_shader_parameter("crackle", 0.0)


## Smooth pseudo-random wave in about -1..1, built from three incommensurate sines.
static func wave(x: float) -> float:
	return (sin(x) + 0.6 * sin(x * 2.13 + 1.7) + 0.35 * sin(x * 4.37 + 0.4)) / 1.95


func play() -> void:
	set_active(true)


func stop() -> void:
	set_active(false)


## Turns the beam on or off with a ramp of ramp_time seconds.
func set_active(on: bool) -> void:
	_active = on
	set_process(true)
	set_physics_process(true)


func is_active() -> bool:
	return _active


## Global position where the beam currently ends.
func get_end_point() -> Vector3:
	return to_global(_dir * _length)


## True when the beam is stopped by a collider this frame.
func is_hitting() -> bool:
	return _hit


func _physics_process(_delta: float) -> void:
	_update_ray()


func _update_ray() -> void:
	if not is_inside_tree():
		return
	var s: float = world_scale()
	var max_len: float = max_length * s
	var origin: Vector3 = global_position
	var gdir: Vector3 = -global_basis.z.normalized()
	if target and target.is_inside_tree():
		var to_t: Vector3 = target.global_position - origin
		if to_t.length() > 0.001:
			gdir = to_t.normalized()
			max_len = minf(max_len, to_t.length())
	var end: Vector3 = origin + gdir * max_len
	_hit = false
	if collide and max_len > 0.0:
		var world: World3D = get_world_3d()
		if world:
			var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, end, collision_mask)
			var parent_body: CollisionObject3D = get_parent() as CollisionObject3D
			if parent_body:
				q.exclude = [parent_body.get_rid()]
			var res: Dictionary = world.direct_space_state.intersect_ray(q)
			if not res.is_empty():
				end = res["position"]
				_hit = true
				_hit_normal = res["normal"]
	if target and target.is_inside_tree() and not _hit:
		_hit = true
		_hit_normal = -gdir
	_hit_point = end
	var local_end: Vector3 = to_local(end)
	_length = local_end.length()
	_dir = local_end / _length if _length > 1e-5 else Vector3.FORWARD


## Width multiplier for the current frame. Subclasses shape the beam over time here.
func _width_factor() -> float:
	return _level * (1.0 + pulse * sin(_time * pulse_speed))


## Brightness multiplier for the current frame.
func _brightness() -> float:
	return _level


## Muzzle glow multiplier for the current frame.
func _muzzle_factor() -> float:
	return _brightness()


## Impact glow multiplier for the current frame.
func _impact_factor() -> float:
	return _brightness()


func _rebuild_body(w: float) -> void:
	_builder.clear()
	if w > 0.0005 and _length > 0.001:
		# Dense tessellation keeps the end tapers short and the glow uniform along the beam.
		var segs: int = clampi(int(_length / clampf(w * 0.75, 0.08, 1.0)), 8, 320)
		var pts: PackedVector3Array = ArcfluxPath.straight(Vector3.ZERO, _dir * _length, segs)
		var widths: PackedFloat32Array = PackedFloat32Array()
		if turbulence > 0.0:
			widths.resize(segs + 1)
			for i in segs + 1:
				var d: float = _length * float(i) / float(segs)
				widths[i] = 1.0 + turbulence * wave(d * 1.6 - _flow * 0.09 + _seed_offset)
		_builder.add_polyline(pts, widths, PackedFloat32Array(), w, 0, 1.0)
		if halo_width > 0.0:
			_builder.add_polyline(pts, widths, PackedFloat32Array(), w * halo_width, 0, 1.0, 1.0, PackedFloat32Array(), minf(w * halo_width * 0.5, _length * 0.3))
		_add_extra_geometry(_builder, w)
	_builder.commit(_body.mesh as ArrayMesh)
	_body.extra_cull_margin = _builder.max_width


## Virtual: add helix strands or other layers to the body mesh.
func _add_extra_geometry(_b: ArcfluxRibbon, _w: float) -> void:
	pass


func _tick(delta: float) -> void:
	if Engine.is_editor_hint():
		_update_ray()
	_time += delta
	var target_level: float = 1.0 if _active else 0.0
	_level = move_toward(_level, target_level, delta / maxf(ramp_time, 0.001))
	_flow += delta * flow_speed
	var s: float = world_scale()
	var wf: float = _width_factor()
	var bright: float = _brightness()
	_rebuild_body(width * wf)
	_body_mat.set_shader_parameter("intensity", bright * intensity)
	_body_mat.set_shader_parameter("flow", _flow)
	_body_mat.set_shader_parameter("beam_length", _length)
	_body_mat.set_shader_parameter("core_ratio", core_ratio)
	_body_mat.set_shader_parameter("edge_noise", edge_noise)
	_body_mat.set_shader_parameter("body_noise", body_noise)
	_body_mat.set_shader_parameter("body_glow_gain", body_glow)
	_body_mat.set_shader_parameter("halo_gain", outer_glow)
	_body_mat.set_shader_parameter("start_fade", width * 0.5)
	_body_mat.set_shader_parameter("end_fade", width * (0.3 if _hit else 3.0))
	var flick: float = 0.85 + 0.15 * sin(_time * 53.0) * sin(_time * 31.0)
	var muzzle: float = _muzzle_factor()
	var mm: ShaderMaterial = _muzzle.material_override as ShaderMaterial
	mm.set_shader_parameter("intensity", muzzle * intensity * flick)
	mm.set_shader_parameter("size", muzzle_flare_size * (0.4 + 0.6 * clampf(maxf(wf, muzzle), 0.0, 1.5)))
	var show_impact: bool = (_hit or impact_in_air) and wf > 0.001
	var impact: float = _impact_factor() if show_impact else 0.0
	_impact.position = _dir * _length
	var im: ShaderMaterial = _impact.material_override as ShaderMaterial
	im.set_shader_parameter("intensity", impact * intensity * flick)
	im.set_shader_parameter("size", impact_flare_size * (0.5 + 0.5 * wf) * (0.9 + 0.2 * rng.randf()))
	_light.position = _dir * maxf(_length - 0.3, 0.0) if show_impact else Vector3.ZERO
	drive_light(_light, maxf(impact, muzzle * 0.6) * flick)
	if impact > 0.05 and impact_sparks_per_second > 0.0:
		_spark_acc += delta * impact_sparks_per_second * impact
		_sparks.gravity = 9.8 * s
		_sparks.floor_enabled = _hit and _hit_normal.y > 0.7
		_sparks.floor_y = _hit_point.y
		var n: Vector3 = _hit_normal if _hit else -(global_basis * _dir).normalized()
		var count: int = int(_spark_acc)
		if count > 0:
			_spark_acc -= float(count)
			_sparks.emit(count, _hit_point + n * 0.02 * s, n, 1.2, 2.0 * s, 6.0 * s, 0.15, 0.45, rng)
	if _sparks.count() > 0:
		_sparks.update(delta, s)
	_after_tick(delta)
	if _level <= 0.0 and not _active and _sparks.count() == 0 and _is_idle():
		_builder.clear()
		_builder.commit(_body.mesh as ArrayMesh)
		set_process(false)
		set_physics_process(false)
		_finish()


## Virtual: extra per-frame work for subclasses.
func _after_tick(_delta: float) -> void:
	pass


## Virtual: subclasses with their own timelines report when they are done.
func _is_idle() -> bool:
	return true
