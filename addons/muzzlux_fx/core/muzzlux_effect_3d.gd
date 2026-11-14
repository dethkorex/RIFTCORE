@tool
@icon("res://addons/muzzlux_fx/icons/effect.svg")
class_name MuzzluxEffect3D
extends Node3D
## Base class for the MUZZLUX 3D effects. It owns the clock, the fade, the one-shot rule, the
## colours, the shot-slot ring and the flash light. Geometry lives in internal child nodes,
## so it is never saved into a scene and never shows up in the scene tree.
##
## Lite version. The full pack has the same class with a colour-table resource export on it
## (six of them: service, night, sci_fi_blue, sci_fi_green, retro, mono) and one more method,
## which turns a surface name into the row index the shaders read. Lite has the one service
## set of colours below as constants, and its only node writes its own slots.
##
## Two rules this class exists to keep:
## 1. **Every node gets its own material.** make_layer() builds a fresh ShaderMaterial per
##    layer per node, so four copies of one preset in a scene animate independently. Nothing
##    here ever writes a shared resource.
## 2. **An exported value never reverts at runtime.** Inherited exports are initialised
##    through _default(), which reads _class_defaults(). A property with no constant default
##    is always stored in the scene file, so a saved value survives a reload outside the
##    editor.

## Emitted when a one-shot has finished, or when stop() has fully faded a looping effect.
signal finished

enum QualitySetting { DEFAULT, LOW, MEDIUM, HIGH }

## Longest slot ring Lite builds. The full pack's cap is MuzzluxShots.SHOT_CAP = 32.
const LITE_SLOTS: int = 4

## The service colours, the ones the full pack ships as its default. The rule they keep: the
## brightest part of a flash or a spark is colourless, because burning propellant is a few
## thousand kelvin. All the colour lives in the mid tone and the falloff.
const COL_CORE: Color = Color(1.0, 0.99, 0.96)
const COL_MID: Color = Color(1.0, 0.63, 0.20)
const COL_FALLOFF: Color = Color(0.46, 0.12, 0.04)
const COL_SMOKE: Color = Color(0.58, 0.57, 0.55, 0.42)
const COL_DEBRIS: Color = Color(0.62, 0.60, 0.56)
const COL_LIGHT: Color = Color(1.0, 0.74, 0.42)
const EMISSION: float = 2.4

## Strength of the effect, 0 = off, 1 = full.
@export_range(0.0, 1.0, 0.01) var amount: float = _default(&"amount", 1.0)
## Playback speed.
@export_range(0.0, 4.0, 0.01) var time_scale: float = _default(&"time_scale", 1.0)
## Start when the node enters the tree at runtime. When off, call play(), trigger() or fire().
@export var autoplay: bool = _default(&"autoplay", true)
## Seconds play() and stop() take to fade a looping effect in and out.
@export_range(0.0, 30.0, 0.01, "or_greater") var fade_time: float = _default(&"fade_time", 0.4)
## Animate inside the editor viewport. One-shots repeat every preview_interval seconds.
@export var preview_in_editor: bool = true
## Seconds between repeats of a one-shot in the editor preview.
@export_range(0.5, 20.0, 0.1) var preview_interval: float = _default(&"preview_interval", 1.6)
## Random seed. 0 picks a different one for every instance, so two guns never fire the same
## shape at the same time.
@export var random_seed: int = 0
## Element counts. DEFAULT follows Muzzlux.quality.
@export var quality: QualitySetting = QualitySetting.DEFAULT:
	set(value):
		quality = value
		_rebuild_queued = true
## How many hits can be alive at once. Hit `max_concurrent` + 1 overwrites the oldest slot,
## so nothing is allocated while hits keep coming. **Lite caps this at LITE_SLOTS = 4**; the
## full pack ships 16 and allows up to 32, which is what sustained fire needs.
@export_range(1, 4, 1) var max_concurrent: int = _default(&"max_concurrent", 16):
	set(value):
		max_concurrent = clampi(value, 1, LITE_SLOTS)
		if _shots != null:
			_shots.set_capacity(max_concurrent)

@export_group("Air")
## Add Muzzlux.wind. Gun smoke and cordite haze drift with it; flashes and tracers do not.
@export var use_global_wind: bool = true
## Extra air movement for this node, metres per second.
@export var wind: Vector3 = _default(&"wind", Vector3.ZERO)

@export_group("Light")
## Adds an OmniLight3D that flashes with the effect.
@export var light_enabled: bool = _default(&"light_enabled", true):
	set(value):
		light_enabled = value
		_rebuild_queued = true
## Light brightness at full strength.
@export_range(0.0, 64.0, 0.01, "or_greater") var light_energy: float = _default(&"light_energy", 6.0)
## Light reach in metres before node scale.
@export_range(0.0, 100.0, 0.01, "or_greater") var light_range: float = _default(&"light_range", 6.0)
## Cast shadows from the light. Costly on a 600 RPM weapon; off by default.
@export var light_shadows: bool = false

## Set by Muzzlux.shot(): free the node when a one-shot finishes.
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
var _colors_dirty: bool = true
var _built: bool = false
var _shots: MuzzluxShots
var _shots_rev: int = -1


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
		_colors_dirty = true
	if Engine.is_editor_hint() and not preview_in_editor:
		_set_visible(false)
		if _light != null:
			_light.visible = false
		return
	var dt: float = delta * time_scale
	# The clock wraps after an hour to keep float precision. Every live shot slot is moved
	# with it, or the shots already in the ring would look like they are in the future and
	# blink out for the length of their own lifetime.
	_time += dt
	if _time >= 3600.0:
		_time -= 3600.0
		if _shots != null:
			_shots.shift_time(-3600.0)
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


## Starts a looping effect (fades in over fade_time).
func play() -> void:
	if is_one_shot():
		trigger()
		return
	_running = true
	_finished_emitted = false


## Stops a looping effect (fades out over fade_time, then emits finished).
func stop() -> void:
	_running = false


func is_playing() -> bool:
	return _burst_age >= 0.0 if is_one_shot() else _running


## Restarts a one-shot from the beginning. On a looping effect it is the same as play(), so
## Muzzlux.shot() starts either kind with one call.
func trigger() -> void:
	_burst_age = 0.0
	_level = 1.0
	_finished_emitted = false
	_preview_clock = 0.0
	if not is_one_shot():
		_running = true
	_on_trigger()


## Puts everything back to the state the node had when it entered the tree: no live shots, no
## accumulated debris, the clock at zero, the light off. Subclasses extend _on_reset().
func reset() -> void:
	_burst_age = -1.0
	_level = 0.0
	_running = false
	_finished_emitted = true
	_time = 0.0
	_velocity = Vector3.ZERO
	if _shots != null:
		_shots.clear()
	if _light != null:
		_light.visible = false
	_on_reset()
	_set_visible(false)


## Changes amount smoothly over `seconds`.
func set_amount_smooth(value: float, seconds: float) -> void:
	var tw: Tween = create_tween()
	tw.tween_property(self, "amount", clampf(value, 0.0, 1.0), maxf(seconds, 0.0))


## amount multiplied by the play/stop fade.
func effective_amount() -> float:
	return clampf(amount, 0.0, 1.0) * _level


## The average of the node's three global scale axes, so the root scale scales everything.
func world_scale() -> float:
	var b: Basis = global_basis if is_inside_tree() else basis
	var s: Vector3 = b.get_scale()
	return (s.x + s.y + s.z) / 3.0


## Air movement acting on this effect, in world units per second.
func get_wind() -> Vector3:
	var w: Vector3 = wind
	if use_global_wind:
		w += Muzzlux.wind
	return w * world_scale()


## Seconds since the last trigger(), or -1 when a one-shot is idle.
func get_age() -> float:
	return _burst_age


## Effect time in seconds. The same clock a shot slot's start_time is stamped with.
func get_time() -> float:
	return _time


## The shot-slot ring this effect fires from, created on first use.
func shots() -> MuzzluxShots:
	if _shots == null:
		_shots = MuzzluxShots.new(max_concurrent, MuzzluxShots.SHOT_CAP)
	return _shots


func quality_factor() -> float:
	match quality:
		QualitySetting.LOW:
			return Muzzlux.quality_factor(Muzzlux.Quality.LOW)
		QualitySetting.MEDIUM:
			return Muzzlux.quality_factor(Muzzlux.Quality.MEDIUM)
		QualitySetting.HIGH:
			return Muzzlux.quality_factor(Muzzlux.Quality.HIGH)
	return Muzzlux.quality_factor(Muzzlux.quality)


## Element count for a layer, scaled by quality.
func count_for(base: int) -> int:
	return maxi(1, roundi(float(base) * quality_factor()))


## Rebuilds every layer (call after changing counts or shapes from code).
func rebuild() -> void:
	_rebuild_queued = true


func is_built() -> bool:
	return _built


func get_light() -> OmniLight3D:
	return _light


func get_camera() -> Camera3D:
	if not is_inside_tree():
		return null
	if Engine.is_editor_hint():
		if Engine.has_singleton(&"EditorInterface"):
			var ei: Object = Engine.get_singleton(&"EditorInterface")
			var obj: Object = ei.call(&"get_editor_viewport_3d", 0)
			var vp: SubViewport = obj as SubViewport
			if vp != null:
				return vp.get_camera_3d()
		return null
	return get_viewport().get_camera_3d()


# ---------------------------------------------------------------- virtuals

## True for effects that play once (a flash, an impact, a burst).
func is_one_shot() -> bool:
	return false


## Length of a one-shot in seconds (scaled time).
func get_duration() -> float:
	return 1.2


## Half size of the area the effect can draw in, before node scale (for culling).
func _extent() -> Vector3:
	return Vector3(3.0, 3.0, 3.0)


## Per-class defaults for inherited exports. Subclasses extend this dictionary instead of
## assigning values in _init(). Properties initialised through _default() have no constant
## default, so Godot always stores them in the scene and a saved value never reverts.
func _class_defaults() -> Dictionary:
	return {}


func _default(property: StringName, fallback: Variant) -> Variant:
	return _class_defaults().get(property, fallback)


func _property_can_revert(property: StringName) -> bool:
	return _class_defaults().has(property)


func _property_get_revert(property: StringName) -> Variant:
	return _class_defaults().get(property)


## Create the layers.
func _build() -> void:
	pass


## Advance by a scaled delta and update shader parameters.
func _tick(_delta: float) -> void:
	pass


func _on_trigger() -> void:
	pass


## Extra clean-up for reset(): drop accumulated holes, casings, the flashbang overlay.
func _on_reset() -> void:
	pass


# ---------------------------------------------------------------- layers

## Creates an internal, top-level layer driven by `shader`. The material is new for every
## call, so no two nodes and no two layers share one.
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


func layer_count() -> int:
	return _layers.size()


func get_layer_material(i: int) -> ShaderMaterial:
	return _layer_materials[i] if i >= 0 and i < _layer_materials.size() else null


## The MeshInstance3D a layer draws into, so an effect can give it its own transform.
func get_layer_node(mat: ShaderMaterial) -> MeshInstance3D:
	var i: int = _layer_materials.find(mat)
	return _layers[i] as MeshInstance3D if i >= 0 else null


func set_layer_enabled(mat: ShaderMaterial, on: bool) -> void:
	var i: int = _layer_materials.find(mat)
	if i >= 0:
		_layers[i].set_meta(&"muzzlux_off", not on)
		if not on:
			_layers[i].visible = false


## Lets a layer keep the transform the effect gives it instead of being pinned to the world
## origin. A hole manager with `follow` set needs this: its quads live in a moving body's
## local space.
func set_layer_own_transform(mat: ShaderMaterial, on: bool) -> void:
	var mi: MeshInstance3D = get_layer_node(mat)
	if mi != null:
		mi.set_meta(&"muzzlux_own_xform", on)


## Gives one layer an emitter transform of its own instead of _emitter_transform(). The
## impact and the hole of a shot sit where the round landed, not at the muzzle, so their
## layers get the hit point while the flash's layers stay on the node.
func set_layer_emitter(mat: ShaderMaterial, xform: Transform3D, on: bool = true) -> void:
	var mi: MeshInstance3D = get_layer_node(mat)
	if mi != null:
		mi.set_meta(&"muzzlux_emitter", xform)
		mi.set_meta(&"muzzlux_emitter_on", on)


func set_layer_mesh(mat: ShaderMaterial, mesh: Mesh) -> void:
	var mi: MeshInstance3D = get_layer_node(mat)
	if mi != null:
		mi.mesh = mesh


## Sets one shader parameter on every layer.
func set_all(param: StringName, value: Variant) -> void:
	for m in _layer_materials:
		m.set_shader_parameter(param, value)


## Uploads the service colours to one material. The full pack hands this job to its colour
## resource, which is why the uniform names below are the same ones.
func apply_colors(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("col_core", COL_CORE)
	mat.set_shader_parameter("col_mid", COL_MID)
	mat.set_shader_parameter("col_falloff", COL_FALLOFF)
	mat.set_shader_parameter("col_smoke", COL_SMOKE)
	mat.set_shader_parameter("col_debris", COL_DEBRIS)
	mat.set_shader_parameter("col_light", COL_LIGHT)
	mat.set_shader_parameter("emission", EMISSION)


## Light intensity 0..1 for this frame; the light is hidden at 0.
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


## World y of the floor below `from`, from one raycast of `reach` metres straight down. Shell
## casings bounce on it. Gives `fallback` back in the editor preview or when nothing was hit.
func ground_below(from: Vector3, reach: float, fallback: float) -> float:
	if not is_inside_tree() or Engine.is_editor_hint():
		return fallback
	var world3: World3D = get_world_3d()
	var space: PhysicsDirectSpaceState3D = world3.direct_space_state if world3 != null else null
	if space == null:
		return fallback
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		from, from - Vector3(0.0, maxf(reach, 0.01), 0.0))
	var hit: Dictionary = space.intersect_ray(q)
	if hit.is_empty():
		return fallback
	if not hit.has("position"):
		return fallback
	var pos: Vector3 = hit["position"]
	return pos.y


# ---------------------------------------------------------------- internals

## Transform the elements are placed from. Defaults to the node itself.
func _emitter_transform() -> Transform3D:
	return global_transform


func _rebuild() -> void:
	_rebuild_queued = false
	for mi in _layers:
		remove_child(mi)
		mi.queue_free()
	_layers.clear()
	_layer_materials.clear()
	# The light is kept across rebuilds on purpose. Freeing a light in the same frame as the
	# geometry it lit makes the renderer print "BUG, indexing did not unpair geometries from
	# light" (an engine-internal check), and a rebuild happens whenever a count changes.
	if _light != null and not light_enabled:
		remove_child(_light)
		_light.queue_free()
		_light = null
	if light_enabled and _light == null:
		_light = OmniLight3D.new()
		add_child(_light, false, Node.INTERNAL_MODE_BACK)
	if _light != null:
		_light.light_color = COL_LIGHT
		_light.shadow_enabled = light_shadows
		_light.visible = false
	_build()
	_colors_dirty = true
	_shots_rev = -1
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
	for mi in _layers:
		mi.visible = on and mi.get_meta(&"muzzlux_off", false) != true


func _update_pixel_angle() -> void:
	var cam: Camera3D = get_camera()
	if cam != null and cam.projection == Camera3D.PROJECTION_PERSPECTIVE:
		var h: float = 720.0
		if not Engine.is_editor_hint():
			h = float(get_viewport().get_visible_rect().size.y)
		_pixel_angle = 2.0 * tan(deg_to_rad(cam.fov) * 0.5) / maxf(h, 1.0)


func _push_common() -> void:
	var t: Transform3D = _emitter_transform()
	var s: float = world_scale()
	var ext: Vector3 = _extent() * s
	var aabb: AABB = AABB(t.origin - ext - Vector3.ONE * 2.0, ext * 2.0 + Vector3.ONE * 4.0)
	var w: Vector3 = get_wind()
	for i in _layers.size():
		var gi: GeometryInstance3D = _layers[i]
		gi.custom_aabb = aabb
		if gi.top_level and gi.get_meta(&"muzzlux_own_xform", false) != true and gi.global_transform != Transform3D.IDENTITY:
			gi.global_transform = Transform3D.IDENTITY
		var m: ShaderMaterial = _layer_materials[i]
		var lt: Transform3D = t
		if gi.get_meta(&"muzzlux_emitter_on", false) == true:
			lt = gi.get_meta(&"muzzlux_emitter", t)
		m.set_shader_parameter("mx_time", _time)
		m.set_shader_parameter("time", _time)
		m.set_shader_parameter("level", effective_amount())
		m.set_shader_parameter("age", _burst_age)
		m.set_shader_parameter("node_scale", s)
		m.set_shader_parameter("em_origin", lt.origin)
		m.set_shader_parameter("em_x", lt.basis.x)
		m.set_shader_parameter("em_y", lt.basis.y)
		m.set_shader_parameter("em_z", lt.basis.z)
		m.set_shader_parameter("em_velocity", _velocity)
		m.set_shader_parameter("wind", w)
		m.set_shader_parameter("pixel_angle", _pixel_angle)
		if _shots != null and _shots.revision() != _shots_rev:
			_shots.apply_to(m)
		if _colors_dirty:
			apply_colors(m)
	if _shots != null:
		_shots_rev = _shots.revision()
	if _colors_dirty and _light != null:
		_light.light_color = COL_LIGHT
	_colors_dirty = false
