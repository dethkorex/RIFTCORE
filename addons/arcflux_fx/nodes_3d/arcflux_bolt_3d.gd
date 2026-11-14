@tool
@icon("res://addons/arcflux_fx/icons/bolt.svg")
class_name ArcfluxBolt3D
extends ArcfluxEffect3D
## One-shot branching lightning bolt. Every strike grows a new channel, flashes with a few
## return strokes and leaves a coloured afterglow.
##
## [codeblock]
## $Bolt.strike(hand.global_position, enemy.global_position)
## [/codeblock]

## Default end point in local space, used by play() when no target is set.
@export var end_point: Vector3 = _default(&"end_point", Vector3(0.0, -6.0, 0.0))
## Optional node to strike at when play() is called.
@export var target: Node3D
## Strike once, then stay idle. When false the bolt repeats every [member interval] seconds.
@export var one_shot: bool = true
@export_range(0.05, 10.0, 0.01, "or_greater") var interval: float = _default(&"interval", 1.2)
@export_range(0.0, 1.0, 0.01) var interval_jitter: float = 0.4
## Free the node after a one-shot strike has faded (runtime only).
@export var free_on_finish: bool = false

@export_group("Shape")
@export_range(0.005, 2.0, 0.001, "or_greater") var width: float = _default(&"width", 0.3)
@export_range(0.0, 1.0, 0.01) var chaos: float = _default(&"chaos", 0.24)
@export_range(0.02, 2.0, 0.01, "or_greater") var segment_length: float = _default(&"segment_length", 0.14)
@export_range(0.0, 16.0, 0.1) var branches: float = _default(&"branches", 4.0)
@export_range(0.05, 1.0, 0.01) var branch_length: float = _default(&"branch_length", 0.42)
@export_range(0.0, 90.0, 0.5, "degrees") var branch_angle: float = 34.0
@export_range(0, 3) var branch_depth: int = 2
@export_range(0.0, 1.0, 0.01) var end_width: float = 0.55
## Sideways bow of the main channel relative to its length (bows toward local +Y).
@export_range(-1.0, 1.0, 0.01) var bow: float = 0.0
## Width of the soft outer glow layer relative to width. 0 disables it.
@export_range(0.0, 20.0, 0.1) var halo_width: float = _default(&"halo_width", 6.0)

@export_group("Timing")
## Time for the leader to reach the end point.
@export_range(0.0, 0.5, 0.001) var leader_time: float = _default(&"leader_time", 0.045)
## Advance the leader in discrete jumps like a real stepped leader.
@export var stepped_leader: bool = _default(&"stepped_leader", false)
## Number of extra return strokes after the first flash.
@export_range(0, 8) var restrikes: int = _default(&"restrikes", 2)
## Window in which the return strokes happen.
@export_range(0.02, 2.0, 0.01) var flicker_time: float = _default(&"flicker_time", 0.28)
## Time the channel keeps glowing after the last stroke.
@export_range(0.0, 3.0, 0.01) var afterglow: float = _default(&"afterglow", 0.45)
## How fast side branches fade compared to the main channel.
@export_range(0.0, 40.0, 0.1) var branch_decay: float = 7.0

@export_group("Extras")
@export var impact_flare: bool = true
@export_range(0.0, 8.0, 0.01) var impact_flare_size: float = _default(&"impact_flare_size", 2.2)
@export var source_flare: bool = true
@export_range(0, 128) var impact_sparks: int = _default(&"impact_sparks", 18)
## Where the light sits along the channel (0 = source, 1 = end).
@export_range(0.0, 1.0, 0.01) var light_position: float = _default(&"light_position", 0.85)

@export_tool_button("Strike", "Play") var strike_button: Callable = _preview_strike

var _ribbon: MeshInstance3D
var _mat: ShaderMaterial
var _flare_end: MeshInstance3D
var _flare_start: MeshInstance3D
var _light: OmniLight3D
var _sparks: ArcfluxSparks
var _shape: ArcfluxPath.Shape = ArcfluxPath.Shape.new()
var _builder: ArcfluxRibbon = ArcfluxRibbon.new()
var _strands: Array[ArcfluxPath.Strand] = []
var _from: Vector3
var _to: Vector3
var _age: float = -1.0
var _stroke_times: PackedFloat32Array = PackedFloat32Array()
var _stroke_amps: PackedFloat32Array = PackedFloat32Array()
var _next_stroke: int = 0
var _repeat_timer: float = 0.0
var _wait: float = 1.0
var _looping: bool = false
var _phase: float = 0.0


func _class_defaults() -> Dictionary:
	return {
		&"light_energy": 6.0,
		&"light_range": 9.0,
	}


func _build() -> void:
	_ribbon = make_ribbon()
	_mat = _ribbon.material_override as ShaderMaterial
	_flare_end = make_flare(impact_flare_size)
	_flare_start = make_flare(impact_flare_size * 0.45)
	_light = make_light()
	_sparks = ArcfluxSparks.new(make_ribbon(RIBBON_SHADER, true))
	var sm: ShaderMaterial = _sparks.mesh_instance.material_override as ShaderMaterial
	sm.set_shader_parameter("core_ratio", 0.35)
	sm.set_shader_parameter("crackle", 0.0)
	_mat.set_shader_parameter("intensity", 0.0)


## Fires a new strike between two global positions.
func strike(from: Vector3, to: Vector3) -> void:
	if not is_inside_tree():
		return
	_from = to_local(from)
	_to = to_local(to)
	_repeat_timer = 0.0
	_wait = maxf(interval, 0.05) * (1.0 + rng.randf_range(-interval_jitter, interval_jitter))
	_begin()


## Strikes toward the target, or toward end_point when no target is set.
func play() -> void:
	_looping = not one_shot or Engine.is_editor_hint()
	_repeat_timer = 0.0
	_fire_default()
	set_process(true)


func stop() -> void:
	_looping = false


func _start_preview() -> void:
	play()


func _preview_strike() -> void:
	play()


func is_active() -> bool:
	return _age >= 0.0


func total_time() -> float:
	return leader_time + flicker_time + afterglow


## Virtual: the strike used by play() and by repeating bolts.
func _fire_default() -> void:
	strike(global_position, _default_end())


func _default_end() -> Vector3:
	if target and target.is_inside_tree():
		return target.global_position
	return to_global(end_point)


func _begin() -> void:
	_shape.segment_length = segment_length
	_shape.chaos = chaos
	_shape.branches = branches
	_shape.branch_length = branch_length
	_shape.branch_angle = deg_to_rad(branch_angle)
	_shape.branch_depth = branch_depth
	_shape.end_width = end_width
	_shape.bow = bow
	_shape.bow_direction = Vector3.UP
	_strands = ArcfluxPath.build(_from, _to, _shape, rng)
	_rebuild_mesh()
	_age = 0.0
	_phase = rng.randf() * 100.0
	_stroke_times = PackedFloat32Array([leader_time])
	_stroke_amps = PackedFloat32Array([1.0])
	for i in restrikes:
		var t: float = leader_time + flicker_time * (float(i + 1) / float(restrikes + 1)) * rng.randf_range(0.7, 1.15)
		_stroke_times.append(t)
		_stroke_amps.append(rng.randf_range(0.45, 0.85) * pow(0.85, float(i)))
	_next_stroke = 1
	var s: float = world_scale()
	var dir: Vector3 = (_from - _to).normalized()
	_flare_end.position = _to
	_flare_start.position = _from
	_light.position = _from.lerp(_to, light_position)
	_on_strike_begin()
	if impact_sparks > 0:
		_sparks.floor_y = to_global(_to).y - 0.02 * s
		_sparks.gravity = 9.8 * s
		_sparks.emit(impact_sparks, to_global(_to), global_basis * dir, 1.3, 2.5 * s, 7.0 * s, 0.25, 0.7, rng)
	set_process(true)


## Virtual: called when a new strike starts, after the channel is built.
func _on_strike_begin() -> void:
	pass


## Virtual: called every frame while the strike is active, with the flash envelope.
func _on_strike_tick(_env: float, _delta: float) -> void:
	pass


func _rebuild_mesh() -> void:
	_builder.clear()
	for st in _strands:
		_builder.add_strand(st, width)
		if halo_width > 0.0 and st.level <= 1:
			_add_halo(st)
	_builder.commit(_ribbon.mesh as ArrayMesh)
	_ribbon.extra_cull_margin = _builder.max_width


func _add_halo(st: ArcfluxPath.Strand) -> void:
	var soft: PackedVector3Array = ArcfluxPath.smoothed(st.points, 4, 2)
	var m: int = soft.size()
	var hw: PackedFloat32Array = PackedFloat32Array()
	var hr: PackedFloat32Array = PackedFloat32Array()
	hw.resize(m)
	hr.resize(m)
	var last: int = st.points.size() - 1
	for i in m:
		var src: int = mini(int(round(float(i) / float(m - 1) * float(last))), last)
		hw[i] = st.widths[src]
		hr[i] = st.reveal[src]
	_builder.add_polyline(soft, hw, hr, width * halo_width, st.level, st.brightness, 1.0, PackedFloat32Array(), width * halo_width * 0.5)


## Small sideways shift of the existing channel, used between return strokes.
func _jitter(amount: float) -> void:
	for st in _strands:
		var n: int = st.points.size()
		for i in range(1, n - 1):
			st.points[i] += Vector3(rng.randfn(), rng.randfn(), rng.randfn()) * amount
	_rebuild_mesh()


func _envelope(t: float) -> float:
	var e: float = 0.0
	if t < leader_time:
		e = 0.35
	for i in _stroke_times.size():
		var dt: float = t - _stroke_times[i]
		if dt >= 0.0:
			e = maxf(e, _stroke_amps[i] * exp(-maxf(dt - 0.03, 0.0) * 9.0))
	var glow_t: float = t - leader_time
	var tail: float = 0.0
	if glow_t >= 0.0:
		var end_t: float = flicker_time + afterglow
		tail = 0.22 * (1.0 - smoothstep(0.0, maxf(end_t, 0.001), glow_t))
	return maxf(e, tail)


func _tick(delta: float) -> void:
	var sparks_alive: bool = false
	if _sparks.count() > 0:
		sparks_alive = _sparks.update(delta, world_scale())
	if _age >= 0.0:
		_age += delta
		_phase += delta * 28.0
		if _next_stroke < _stroke_times.size() and _age >= _stroke_times[_next_stroke]:
			_next_stroke += 1
			_jitter(segment_length * 0.08)
		var env: float = _envelope(_age)
		var reveal: float = _age / maxf(leader_time, 0.0001) if _age < leader_time else 2.0
		if stepped_leader and reveal < 1.0:
			reveal = (floor(reveal * 7.0) + 1.0) / 7.0 * 0.98
		var post: float = maxf(_age - leader_time, 0.0)
		var core: float = clampf(env * 1.6, 0.0, 1.0)
		_mat.set_shader_parameter("intensity", env * intensity * 1.4)
		_mat.set_shader_parameter("core_gain", core)
		_mat.set_shader_parameter("reveal", reveal)
		_mat.set_shader_parameter("phase", _phase)
		_mat.set_shader_parameter("branch_intensity", exp(-post * branch_decay))
		_mat.set_shader_parameter("width_scale", lerpf(0.55, 1.0, clampf(env * 1.5, 0.0, 1.0)))
		var fm_end: ShaderMaterial = _flare_end.material_override as ShaderMaterial
		var fm_start: ShaderMaterial = _flare_start.material_override as ShaderMaterial
		var flash: float = env if _age >= leader_time else 0.0
		fm_end.set_shader_parameter("intensity", flash * intensity * (1.0 if impact_flare else 0.0))
		fm_end.set_shader_parameter("size", impact_flare_size * (0.6 + 0.5 * flash))
		fm_start.set_shader_parameter("intensity", env * intensity * 0.8 * (1.0 if source_flare else 0.0))
		drive_light(_light, env)
		_on_strike_tick(env, delta)
		if _age >= total_time():
			_age = -1.0
			_mat.set_shader_parameter("intensity", 0.0)
			fm_end.set_shader_parameter("intensity", 0.0)
			fm_start.set_shader_parameter("intensity", 0.0)
			drive_light(_light, 0.0)
			_builder.clear()
			_builder.commit(_ribbon.mesh as ArrayMesh)
			_finish()
	if _looping:
		_repeat_timer += delta
		if _repeat_timer >= _wait:
			_fire_default()
	elif _age < 0.0 and not sparks_alive:
		if free_on_finish and not Engine.is_editor_hint() and _can_free():
			queue_free()
		else:
			set_process(false)


## Virtual: subclasses with lingering parts return false until those are done.
func _can_free() -> bool:
	return true
