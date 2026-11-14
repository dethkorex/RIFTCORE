@tool
@icon("res://addons/edgeflux_fx/icons/effect.svg")
class_name EdgefluxEffect3D
extends Node3D
## Base class for EDGEFLUX 3D effects. Owns the palette, timing, looping, lights and the
## internal helper meshes. Helpers are internal children, so they are never saved into
## scenes and never show up in the scene tree.

## Emitted when a one-shot run has fully faded.
signal finished

const STREAK_SHADER: Shader = preload("res://addons/edgeflux_fx/shaders/edgeflux_streaks.gdshader")
const DEBRIS_SHADER: Shader = preload("res://addons/edgeflux_fx/shaders/edgeflux_debris.gdshader")
const FLARE_SHADER: Shader = preload("res://addons/edgeflux_fx/shaders/edgeflux_flare.gdshader")
const WALL_SHADER: Shader = preload("res://addons/edgeflux_fx/shaders/edgeflux_wall.gdshader")
const GROUND_SHADER: Shader = preload("res://addons/edgeflux_fx/shaders/edgeflux_ground.gdshader")

## Colours. Leave empty for the default steel-blue palette.
@export var palette: EdgefluxPalette:
	set(value):
		if palette and palette.changed.is_connected(_apply_palette):
			palette.changed.disconnect(_apply_palette)
		palette = value
		if palette and not palette.changed.is_connected(_apply_palette):
			palette.changed.connect(_apply_palette)
		_apply_palette()
## Brightness of the whole effect.
@export_range(0.0, 4.0, 0.01) var intensity: float = 1.0:
	set(v):
		intensity = v
		_on_intensity_changed()
## Playback speed.
@export_range(0.05, 4.0, 0.01) var time_scale: float = 1.0
## Play once when the node enters the tree at runtime. Turn off for effects you trigger from code.
@export var autoplay: bool = _default(&"autoplay", true)
## Replay automatically every loop_interval seconds.
@export var loop: bool = false
@export_range(0.1, 10.0, 0.01, "or_greater") var loop_interval: float = _default(&"loop_interval", 1.6)
## Replay in the editor viewport so you can see the effect while tuning it.
@export var preview_in_editor: bool = true
## Free the node after a one-shot run (handy for effects spawned at a hit point).
@export var free_when_finished: bool = false
## Random seed. 0 picks a different seed for every instance.
@export var random_seed: int = 0

@export_group("Light")
## Cast a short light pulse on the scene.
@export var light_enabled: bool = _default(&"light_enabled", true)
@export_range(0.0, 32.0, 0.01) var light_energy: float = _default(&"light_energy", 3.0)
## Light range in metres before node scale.
@export_range(0.1, 50.0, 0.01, "or_greater") var light_range: float = _default(&"light_range", 4.0)

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var seed_value: float = 0.0
## Seconds since the last play().
var age: float = 1000.0
var _active: bool = false
var _idle: float = 0.0
var _materials: Array[ShaderMaterial] = []
var _lights: Array[OmniLight3D] = []
var _light_base: Dictionary = {}
var _streak_slots: Array[MeshInstance3D] = []
var _streak_age: PackedFloat32Array = PackedFloat32Array()
var _streak_life: PackedFloat32Array = PackedFloat32Array()
var _streak_group: PackedInt32Array = PackedInt32Array()
var _group_next: Dictionary = {}
var _default_palette: EdgefluxPalette
var _built: bool = false


func _ready() -> void:
	if random_seed != 0:
		rng.seed = random_seed
	else:
		rng.randomize()
	seed_value = rng.randf() * 1000.0
	_build()
	_built = true
	_apply_palette()
	_on_intensity_changed()
	if not Engine.is_editor_hint() and autoplay:
		play()


func _process(delta: float) -> void:
	var dt: float = delta * time_scale
	if Engine.is_editor_hint() and not preview_in_editor:
		return
	age += dt
	_update_streaks(dt)
	_tick(dt)
	if _active and _is_done():
		_active = false
		_idle = 0.0
		finished.emit()
		if free_when_finished and not Engine.is_editor_hint():
			queue_free()
			return
	if not _active:
		_idle += dt
		var looping: bool = loop or (Engine.is_editor_hint() and preview_in_editor)
		if looping and _idle >= loop_interval and _auto_replay():
			play()


## Starts the effect from the beginning.
func play() -> void:
	age = 0.0
	_active = true
	_idle = 0.0
	_on_play()


## Stops looping effects and lets them fade.
func stop() -> void:
	loop = false
	_on_stop()


## True while a run is playing.
func is_active() -> bool:
	return _active


func world_scale() -> float:
	return global_basis.get_scale().x if is_inside_tree() else scale.x


func get_palette() -> EdgefluxPalette:
	if palette:
		return palette
	if not _default_palette:
		_default_palette = EdgefluxPalette.new()
	return _default_palette


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


## Virtual: create helper meshes.
func _build() -> void:
	pass


## Virtual: called by play().
func _on_play() -> void:
	pass


## Virtual: called by stop().
func _on_stop() -> void:
	pass


## Virtual: advance by a scaled delta and update shader parameters.
func _tick(_delta: float) -> void:
	pass


## Virtual: true once a one-shot run has fully faded.
func _is_done() -> bool:
	return age > 2.0


## Virtual: whether the editor / loop may restart the effect by itself.
func _auto_replay() -> bool:
	return true


## Virtual: react to intensity changes (most effects read `intensity` every frame instead).
func _on_intensity_changed() -> void:
	pass


## Adds an internal mesh with its own material. Local meshes follow the node; top-level
## meshes stay at the world origin and are positioned by their shader.
func make_mesh(mesh: Mesh, shader: Shader, top_level_mesh: bool = false) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("seed", rng.randf() * 100.0)
	mi.material_override = mat
	_materials.append(mat)
	add_child(mi, false, Node.INTERNAL_MODE_BACK)
	if top_level_mesh:
		mi.top_level = true
		mi.global_transform = Transform3D.IDENTITY
	return mi


func mat_of(mi: MeshInstance3D) -> ShaderMaterial:
	return mi.material_override as ShaderMaterial


## Creates `slots` pooled particle meshes of `count` particles each, for emit_streaks().
## Pools with different shaders or sizes go in different groups.
func make_streak_pool(slots: int, count: int, shader: Shader = STREAK_SHADER, group: int = 0) -> void:
	for i in slots:
		var mi: MeshInstance3D = make_mesh(EdgefluxMeshes.particle_quads(count), shader, true)
		mi.visible = false
		_streak_slots.append(mi)
		_streak_age.append(1000.0)
		_streak_life.append(0.0)
		_streak_group.append(group)


## Fires one burst on the next pooled slot of `group` (or on slot `slot` when given).
## `params` are shader uniforms (origin, emit_dir, speed_min, ...). `reach` bounds the burst
## for culling, in world units.
func emit_streaks(params: Dictionary, reach: float = 4.0, slot: int = -1, group: int = 0) -> ShaderMaterial:
	if _streak_slots.is_empty():
		return null
	var i: int = slot
	if i < 0:
		var start: int = _group_next.get(group, 0)
		for k in _streak_slots.size():
			var c: int = (start + k) % _streak_slots.size()
			if _streak_group[c] == group:
				i = c
				break
		if i < 0:
			return null
		_group_next[group] = i + 1
	var mi: MeshInstance3D = _streak_slots[i]
	var m: ShaderMaterial = mat_of(mi)
	for k: Variant in params.keys():
		m.set_shader_parameter(StringName(str(k)), params[k])
	m.set_shader_parameter("seed", rng.randf() * 500.0)
	m.set_shader_parameter("scale", world_scale())
	m.set_shader_parameter("age", 0.0)
	var o: Vector3 = params.get("origin", global_position)
	var r: float = maxf(reach, 0.5)
	mi.custom_aabb = AABB(o - Vector3.ONE * r, Vector3.ONE * r * 2.0)
	mi.visible = true
	_streak_age[i] = 0.0
	var life: float = params.get("life_max", 1.0)
	var spread_t: float = params.get("delay_spread", 0.0)
	var dur: float = params.get("duration", 0.0)
	_streak_life[i] = life + spread_t + dur + 0.05
	return m


func _update_streaks(dt: float) -> void:
	for i in _streak_slots.size():
		if _streak_age[i] > _streak_life[i]:
			if _streak_slots[i].visible:
				_streak_slots[i].visible = false
			continue
		_streak_age[i] += dt
		mat_of(_streak_slots[i]).set_shader_parameter("age", _streak_age[i])


func streaks_busy() -> bool:
	for i in _streak_slots.size():
		if _streak_age[i] <= _streak_life[i]:
			return true
	return false


func make_flare(shape: int, billboard: bool = true) -> MeshInstance3D:
	var mi: MeshInstance3D = make_mesh(EdgefluxMeshes.quad(), FLARE_SHADER)
	var m: ShaderMaterial = mat_of(mi)
	m.set_shader_parameter("shape", shape)
	m.set_shader_parameter("billboard", billboard)
	m.set_shader_parameter("intensity", 0.0)
	m.set_shader_parameter("rotation", rng.randf() * TAU)
	mi.extra_cull_margin = 4.0
	return mi


func make_light(range_mult: float = 1.0) -> OmniLight3D:
	var l: OmniLight3D = OmniLight3D.new()
	l.shadow_enabled = false
	l.light_energy = 0.0
	l.omni_attenuation = 1.4
	l.visible = false
	_light_base[l] = range_mult
	_lights.append(l)
	add_child(l, false, Node.INTERNAL_MODE_BACK)
	l.light_color = get_palette().light_color
	return l


## Sets a light pulse. level is 0..1 relative to light_energy.
func drive_light(l: OmniLight3D, level: float) -> void:
	var on: bool = light_enabled and level > 0.003
	if l.visible != on:
		l.visible = on
	if not on:
		return
	l.light_energy = light_energy * intensity * level
	var mult: float = _light_base.get(l, 1.0)
	l.omni_range = light_range * mult * world_scale()


func _apply_palette() -> void:
	if not _built:
		return
	var p: EdgefluxPalette = get_palette()
	for m in _materials:
		p.apply_to(m)
	for l in _lights:
		l.light_color = p.light_color
	_palette_applied(p)


## Virtual: extra colour work after the palette changes.
func _palette_applied(_p: EdgefluxPalette) -> void:
	pass


## Smooth 0..1 envelope: rises over `attack`, holds, falls over `release` ending at `length`.
static func envelope(t: float, attack: float, length: float, release: float) -> float:
	if t < 0.0 or t > length:
		return 0.0
	var up: float = clampf(t / maxf(attack, 0.0001), 0.0, 1.0)
	var down: float = clampf((length - t) / maxf(release, 0.0001), 0.0, 1.0)
	return minf(up, down * down)
