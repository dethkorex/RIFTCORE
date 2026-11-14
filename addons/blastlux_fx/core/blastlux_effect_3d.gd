@tool
@icon("res://addons/blastlux_fx/icons/effect.svg")
class_name BlastluxEffect3D
extends Node3D
## Base of every BLASTLUX 3D effect: the clock, one-shot bursts, fading, the palette, wind,
## the dynamic light and the layer list (one MeshInstance3D + ShaderMaterial per layer).

signal finished

enum QualitySetting { DEFAULT, LOW, MEDIUM, HIGH }

@export_range(0.0, 1.0, 0.01) var amount: float = _default(&"amount", 1.0)
@export_range(0.0, 4.0, 0.01) var time_scale: float = _default(&"time_scale", 1.0)
@export var autoplay: bool = _default(&"autoplay", true)
@export_range(0.0, 30.0, 0.01, "or_greater") var fade_time: float = _default(&"fade_time", 0.5)
@export var preview_in_editor: bool = true
@export_range(0.5, 20.0, 0.1) var preview_interval: float = _default(&"preview_interval", 4.0)
@export var random_seed: int = 0
@export var palette: BlastluxPalette = _default(&"palette", null):
	set(value):
		palette = value
		_palette_dirty = true
@export var quality: QualitySetting = QualitySetting.DEFAULT:
	set(value):
		quality = value
		_rebuild_queued = true

@export_group("Wind")
@export var use_global_wind: bool = true
@export var wind: Vector3 = _default(&"wind", Vector3.ZERO)

@export_group("Light")
@export var light_enabled: bool = _default(&"light_enabled", true):
	set(value):
		light_enabled = value
		_rebuild_queued = true
@export_range(0.0, 64.0, 0.01, "or_greater") var light_energy: float = _default(&"light_energy", 6.0)
@export_range(0.0, 100.0, 0.01, "or_greater") var light_range: float = _default(&"light_range", 10.0)
@export var light_shadows: bool = false

var free_when_done: bool = false
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var seed_value: int = 1
var _time: float = 0.0
var _level: float = 0.0
var _running: bool = false
var _finished_emitted: bool = true
var _burst_age: float = -1.0
var _preview_clock: float = 0.0
var _layers: Array[GeometryInstance3D] = []
var _layer_materials: Array[ShaderMaterial] = []
var _light: OmniLight3D
var _pixel_angle: float = 0.002
var _last_pos: Vector3 = Vector3.ZERO
var _velocity: Vector3 = Vector3.ZERO
var _rebuild_queued: bool = false
var _palette_dirty: bool = true
var _built: bool = false
var _fallback_palette: BlastluxPalette


func _enter_tree() -> void:
	Blastlux.check_version()


func _ready() -> void:
	if random_seed != 0:
		rng.seed = random_seed
	else:
		rng.randomize()
	seed_value = rng.randi_range(1, 1 << 30)
	_last_pos = global_position
	_rebuild()
	if Engine.is_editor_hint():
		if preview_in_editor:
			_start_preview()
	elif autoplay:
		if is_one_shot():
			trigger()
		else:
			_running = true
			_level = 1.0
			_finished_emitted = false
	_process(0.0)


func _process(delta: float) -> void:
	if _rebuild_queued:
		_rebuild()
	if Engine.is_editor_hint():
		_palette_dirty = true
		if not preview_in_editor:
			_set_visible(false)
			if _light:
				_light.visible = false
			return
	var dt: float = delta * time_scale
	_time = fmod(_time + dt, 3600.0)
	if delta > 0.0:
		var pos: Vector3 = global_position
		_velocity = _velocity.lerp((pos - _last_pos) / delta, clampf(delta * 8.0, 0.0, 1.0))
		_last_pos = pos
	if is_one_shot():
		_process_one_shot(delta, dt)
	else:
		var target: float = 1.0 if _running else 0.0
		_level = move_toward(_level, target, delta / maxf(fade_time, 0.001)) if fade_time > 0.0 else target
		if not _running and _level <= 0.0 and not _finished_emitted:
			_finished_emitted = true
			finished.emit()
			if free_when_done and not Engine.is_editor_hint():
				queue_free()
	_set_visible(_is_active())
	_update_pixel_angle()
	_tick(dt)
	_push_common()


func _process_one_shot(delta: float, dt: float) -> void:
	if _burst_age >= 0.0:
		_burst_age += dt
		_level = 1.0
		if _burst_age > get_duration():
			_burst_age = -1.0
			_level = 0.0
			if not _finished_emitted:
				_finished_emitted = true
				finished.emit()
				if free_when_done and not Engine.is_editor_hint():
					queue_free()
	if Engine.is_editor_hint() and preview_in_editor:
		_preview_clock += delta
		if _preview_clock >= maxf(preview_interval, get_duration() * 0.5):
			_preview_clock = 0.0
			trigger()


# ---------------------------------------------------------------- control

func play() -> void:
	if is_one_shot():
		trigger()
		return
	_running = true
	_finished_emitted = false


func stop() -> void:
	_running = false


func is_playing() -> bool:
	return _burst_age >= 0.0 if is_one_shot() else _running


func trigger() -> void:
	_burst_age = 0.0
	_level = 1.0
	_finished_emitted = false
	_preview_clock = 0.0
	if not is_one_shot():
		_running = true
	_on_trigger()


func effective_amount() -> float:
	return clampf(amount, 0.0, 1.0) * _level


func world_scale() -> float:
	var b: Basis = global_basis if is_inside_tree() else basis
	var s: Vector3 = b.get_scale()
	return (s.x + s.y + s.z) / 3.0


func get_wind() -> Vector3:
	var w: Vector3 = wind
	if use_global_wind:
		w += Blastlux.wind
	return w * world_scale()


func get_age() -> float:
	return _burst_age


func get_time() -> float:
	return _time


func get_palette() -> BlastluxPalette:
	if palette:
		return palette
	if _fallback_palette == null:
		_fallback_palette = BlastluxPalette.new()
	return _fallback_palette


func quality_factor() -> float:
	match quality:
		QualitySetting.LOW:
			return Blastlux.quality_factor(Blastlux.Quality.LOW)
		QualitySetting.MEDIUM:
			return Blastlux.quality_factor(Blastlux.Quality.MEDIUM)
		QualitySetting.HIGH:
			return Blastlux.quality_factor(Blastlux.Quality.HIGH)
	return Blastlux.quality_factor(Blastlux.quality)


func count_for(base: int) -> int:
	return maxi(1, roundi(float(base) * quality_factor()))


func rebuild() -> void:
	_rebuild_queued = true


func is_built() -> bool:
	return _built


func get_camera() -> Camera3D:
	if not is_inside_tree():
		return null
	if Engine.is_editor_hint():
		if Engine.has_singleton(&"EditorInterface"):
			var ei: Object = Engine.get_singleton(&"EditorInterface")
			var obj: Object = ei.call(&"get_editor_viewport_3d", 0)
			var vp: SubViewport = obj as SubViewport
			if vp:
				return vp.get_camera_3d()
		return null
	return get_viewport().get_camera_3d()


func get_light() -> OmniLight3D:
	return _light


# ---------------------------------------------------------------- virtuals

func is_one_shot() -> bool:
	return false


func get_duration() -> float:
	return 2.0


## Half-size of the box the layers may draw in (world units before the root scale).
func _extent() -> Vector3:
	return Vector3(3.0, 3.0, 3.0)


func _class_defaults() -> Dictionary:
	return {}


func _default(property: StringName, fallback: Variant) -> Variant:
	return _class_defaults().get(property, fallback)


func _property_can_revert(property: StringName) -> bool:
	return _class_defaults().has(property)


func _property_get_revert(property: StringName) -> Variant:
	return _class_defaults().get(property)


func _build() -> void:
	pass


func _tick(_delta: float) -> void:
	pass


func _on_trigger() -> void:
	pass


# ---------------------------------------------------------------- layers

func make_layer(shader: Shader, mesh: Mesh, priority: int = 0) -> ShaderMaterial:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.top_level = true
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = shader
	mat.render_priority = priority
	mat.set_shader_parameter("seed", seed_value + _layers.size() * 7919)
	mi.material_override = mat
	add_child(mi, false, Node.INTERNAL_MODE_BACK)
	mi.global_transform = Transform3D.IDENTITY
	_layers.append(mi)
	_layer_materials.append(mat)
	return mat


func get_layer_node(mat: ShaderMaterial) -> MeshInstance3D:
	var i: int = _layer_materials.find(mat)
	return _layers[i] as MeshInstance3D if i >= 0 else null


func set_layer_enabled(mat: ShaderMaterial, on: bool) -> void:
	var i: int = _layer_materials.find(mat)
	if i >= 0:
		_layers[i].set_meta(&"bx_off", not on)
		if not on:
			_layers[i].visible = false


## A layer that keeps its own transform (a shell on a target mesh) instead of the identity.
func set_layer_own_transform(mat: ShaderMaterial, on: bool) -> void:
	var mi: MeshInstance3D = get_layer_node(mat)
	if mi:
		mi.set_meta(&"bx_own_xform", on)


func set_layer_mesh(mat: ShaderMaterial, mesh: Mesh) -> void:
	var mi: MeshInstance3D = get_layer_node(mat)
	if mi:
		mi.mesh = mesh


func set_all(param: StringName, value: Variant) -> void:
	for m: ShaderMaterial in _layer_materials:
		m.set_shader_parameter(param, value)


func _rebuild() -> void:
	_rebuild_queued = false
	for mi: GeometryInstance3D in _layers:
		remove_child(mi)
		mi.queue_free()
	_layers.clear()
	_layer_materials.clear()
	if _light != null and not light_enabled:
		remove_child(_light)
		_light.queue_free()
		_light = null
	if light_enabled and _light == null:
		_light = OmniLight3D.new()
		_light.light_specular = 0.3
		add_child(_light, false, Node.INTERNAL_MODE_BACK)
	if _light != null:
		_light.light_color = get_palette().light
		_light.shadow_enabled = light_shadows
		_light.visible = false
	_build()
	_palette_dirty = true
	_built = true


func _start_preview() -> void:
	if is_one_shot():
		trigger()
	else:
		_running = true
		_level = 1.0
		_finished_emitted = false


func _is_active() -> bool:
	if is_one_shot():
		return _burst_age >= 0.0 and amount > 0.0
	return effective_amount() > 0.0005


func _set_visible(on: bool) -> void:
	for mi: GeometryInstance3D in _layers:
		mi.visible = on and mi.get_meta(&"bx_off", false) != true


func _update_pixel_angle() -> void:
	var cam: Camera3D = get_camera()
	if cam and cam.projection == Camera3D.PROJECTION_PERSPECTIVE:
		var h: float = float(get_viewport().get_visible_rect().size.y) if not Engine.is_editor_hint() else 720.0
		_pixel_angle = 2.0 * tan(deg_to_rad(cam.fov) * 0.5) / maxf(h, 1.0)


## Light strength 0..1 (and more for a flash); the node's light_energy scales it.
func set_light_level(level: float, color: Color = Color(0, 0, 0, 0)) -> void:
	if _light == null:
		return
	var s: float = world_scale()
	_light.light_energy = light_energy * maxf(level, 0.0)
	_light.omni_range = light_range * s
	_light.visible = level > 0.001 and visible
	_light.shadow_enabled = light_shadows
	if color.a > 0.0:
		_light.light_color = color


## y of the first collider below `from` (reach metres down), else `fallback`. Editor: fallback.
func ground_below(from: Vector3, reach: float, fallback: float) -> float:
	if not is_inside_tree() or Engine.is_editor_hint():
		return fallback
	var world3: World3D = get_world_3d()
	var space: PhysicsDirectSpaceState3D = world3.direct_space_state if world3 else null
	if space == null:
		return fallback
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		from, from - Vector3(0.0, maxf(reach, 0.01), 0.0))
	var hit: Dictionary = space.intersect_ray(q)
	if hit.is_empty():
		return fallback
	var pos: Vector3 = hit.get("position", from)
	return pos.y


func _emitter_transform() -> Transform3D:
	return global_transform


func _push_common() -> void:
	var t: Transform3D = _emitter_transform()
	var s: float = world_scale()
	var ext: Vector3 = _extent() * s
	var aabb: AABB = AABB(t.origin - ext - Vector3.ONE * 2.0, ext * 2.0 + Vector3.ONE * 4.0)
	var pal: BlastluxPalette = get_palette()
	var w: Vector3 = get_wind()
	for i: int in _layers.size():
		var gi: GeometryInstance3D = _layers[i]
		gi.custom_aabb = aabb
		if gi.top_level and gi.get_meta(&"bx_own_xform", false) != true and gi.global_transform != Transform3D.IDENTITY:
			gi.global_transform = Transform3D.IDENTITY
		var m: ShaderMaterial = _layer_materials[i]
		m.set_shader_parameter("time", _time)
		m.set_shader_parameter("level", effective_amount())
		m.set_shader_parameter("age", _burst_age)
		m.set_shader_parameter("em_origin", t.origin)
		m.set_shader_parameter("em_x", t.basis.x)
		m.set_shader_parameter("em_y", t.basis.y)
		m.set_shader_parameter("em_z", t.basis.z)
		m.set_shader_parameter("em_velocity", _velocity)
		m.set_shader_parameter("wind", w)
		m.set_shader_parameter("pixel_angle", _pixel_angle)
		if _palette_dirty:
			pal.apply_to(m)
	if _palette_dirty and _light:
		_light.light_color = pal.light
	_palette_dirty = false
