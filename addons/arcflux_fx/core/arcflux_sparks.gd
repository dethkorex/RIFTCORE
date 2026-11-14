class_name ArcfluxSparks
extends RefCounted
## Small CPU spark simulation drawn as velocity-stretched ribbons.
## Works identically on every renderer (no GPU particles or trails involved).
## Positions are simulated in world space; the mesh instance is top-level.

var mesh_instance: MeshInstance3D
var gravity: float = 9.8
var drag: float = 2.0
## Seconds of velocity used for the streak length.
var streak: float = 0.03
## Shortest drawn streak, so slow particles still show as dots.
var min_length: float = 0.0
var width: float = 0.035
var floor_enabled: bool = true
var floor_y: float = 0.0
var bounce: float = 0.35
## Pull toward attract_point (units/s^2). Used for charge-up effects.
var attract: float = 0.0
var attract_point: Vector3 = Vector3.ZERO

var _pos: PackedVector3Array = PackedVector3Array()
var _vel: PackedVector3Array = PackedVector3Array()
var _life: PackedFloat32Array = PackedFloat32Array()
var _max_life: PackedFloat32Array = PackedFloat32Array()
var _builder: ArcfluxRibbon = ArcfluxRibbon.new()


func _init(mi: MeshInstance3D) -> void:
	mesh_instance = mi
	mesh_instance.top_level = true


func count() -> int:
	return _pos.size()


func clear() -> void:
	_pos.clear()
	_vel.clear()
	_life.clear()
	_max_life.clear()
	_builder.clear()
	_builder.commit(mesh_instance.mesh as ArrayMesh)


## Emits sparks in a cone around dir (spread in radians, PI = hemisphere, TAU = sphere).
func emit(n: int, origin: Vector3, dir: Vector3, spread: float, speed_min: float, speed_max: float, life_min: float, life_max: float, rng: RandomNumberGenerator) -> void:
	var d: Vector3 = dir.normalized() if dir.length_squared() > 1e-8 else Vector3.UP
	var helper: Vector3 = Vector3.UP if absf(d.y) < 0.95 else Vector3.RIGHT
	var u: Vector3 = d.cross(helper).normalized()
	var v: Vector3 = d.cross(u)
	for _i in n:
		var cos_max: float = cos(minf(spread, PI))
		var ct: float = lerpf(1.0, cos_max, rng.randf())
		if spread > PI:
			ct = rng.randf_range(-1.0, 1.0)
		var st: float = sqrt(maxf(0.0, 1.0 - ct * ct))
		var ph: float = rng.randf() * TAU
		var vd: Vector3 = d * ct + (u * cos(ph) + v * sin(ph)) * st
		_pos.append(origin)
		_vel.append(vd * rng.randf_range(speed_min, speed_max))
		var l: float = rng.randf_range(life_min, life_max)
		_life.append(l)
		_max_life.append(l)


## Adds a single spark with an explicit velocity.
func add(pos: Vector3, vel: Vector3, life: float) -> void:
	_pos.append(pos)
	_vel.append(vel)
	_life.append(life)
	_max_life.append(life)


## Advances the simulation and rebuilds the mesh. Returns true while sparks remain.
func update(delta: float, width_scale: float = 1.0) -> bool:
	mesh_instance.global_transform = Transform3D.IDENTITY
	var i: int = 0
	var damp: float = exp(-drag * delta)
	while i < _pos.size():
		_life[i] -= delta
		if _life[i] <= 0.0:
			_remove(i)
			continue
		var v: Vector3 = _vel[i] * damp + Vector3.DOWN * gravity * delta
		if attract != 0.0:
			v += (attract_point - _pos[i]).normalized() * attract * delta
		var p: Vector3 = _pos[i] + v * delta
		if floor_enabled and p.y < floor_y and v.y < 0.0:
			p.y = floor_y + (floor_y - p.y) * bounce
			v.y = -v.y * bounce
			v.x *= 0.7
			v.z *= 0.7
		_pos[i] = p
		_vel[i] = v
		i += 1
	_builder.clear()
	var widths: PackedFloat32Array = PackedFloat32Array([0.25, 1.0])
	var empty: PackedFloat32Array = PackedFloat32Array()
	for k in _pos.size():
		var f: float = _life[k] / _max_life[k]
		var tail: Vector3 = _pos[k] - _vel[k] * streak
		if min_length > 0.0 and tail.distance_squared_to(_pos[k]) < min_length * min_length:
			var dv: Vector3 = _vel[k].normalized() if _vel[k].length_squared() > 1e-8 else Vector3.UP
			tail = _pos[k] - dv * min_length
		if tail.is_equal_approx(_pos[k]):
			tail = _pos[k] + Vector3(0.0, 0.001, 0.0)
		_builder.add_polyline(PackedVector3Array([tail, _pos[k]]), widths, empty, width * width_scale, 3, f * f)
	_builder.commit(mesh_instance.mesh as ArrayMesh)
	mesh_instance.extra_cull_margin = width * width_scale
	return not _pos.is_empty()


func _remove(i: int) -> void:
	var last: int = _pos.size() - 1
	_pos[i] = _pos[last]
	_vel[i] = _vel[last]
	_life[i] = _life[last]
	_max_life[i] = _max_life[last]
	_pos.resize(last)
	_vel.resize(last)
	_life.resize(last)
	_max_life.resize(last)
