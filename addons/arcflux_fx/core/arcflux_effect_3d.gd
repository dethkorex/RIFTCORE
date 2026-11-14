@tool
@icon("res://addons/arcflux_fx/icons/effect.svg")
class_name ArcfluxEffect3D
extends Node3D
## Base class for ARCFLUX 3D effects. Owns the palette, timing and the helper nodes
## (ribbons, flares, lights) that concrete effects build on. Helper nodes are internal
## children, so they are never saved into scenes and never show up in the scene tree.

signal finished

const RIBBON_SHADER: Shader = preload("res://addons/arcflux_fx/shaders/arcflux_ribbon.gdshader")
const BEAM_SHADER: Shader = preload("res://addons/arcflux_fx/shaders/arcflux_beam.gdshader")
const FLARE_SHADER: Shader = preload("res://addons/arcflux_fx/shaders/arcflux_flare.gdshader")
const GROUND_SHADER: Shader = preload("res://addons/arcflux_fx/shaders/arcflux_ground.gdshader")

@export var palette: ArcfluxPalette:
	set(value):
		if palette and palette.changed.is_connected(_apply_palette):
			palette.changed.disconnect(_apply_palette)
		palette = value
		if palette and not palette.changed.is_connected(_apply_palette):
			palette.changed.connect(_apply_palette)
		_apply_palette()
## Global brightness multiplier.
@export_range(0.0, 4.0, 0.01) var intensity: float = 1.0
## Playback speed of the whole effect.
@export_range(0.05, 4.0, 0.01) var time_scale: float = 1.0
## Start automatically when the node enters the tree at runtime.
@export var autoplay: bool = true
## Keep the effect animating inside the editor viewport.
@export var preview_in_editor: bool = true
## Random seed. 0 picks a different seed for every instance.
@export var random_seed: int = 0

@export_group("Flares")
## Flares draw on top of geometry and are hidden when a physics collider blocks the line
## of sight from the camera. Colliders on these layers count as occluders.
@export_flags_3d_physics var flare_occlusion_mask: int = 1

@export_group("Light")
@export var light_enabled: bool = true
@export_range(0.0, 64.0, 0.01) var light_energy: float = _default(&"light_energy", 4.0)
@export_range(0.1, 100.0, 0.01, "or_greater") var light_range: float = _default(&"light_range", 6.0)

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _materials: Array[ShaderMaterial] = []
var _spark_materials: Array[ShaderMaterial] = []
var _lights: Array[OmniLight3D] = []
var _light_base: Dictionary = {}
var _flares: Array[MeshInstance3D] = []
var _flare_vis: Dictionary = {}
var _default_palette: ArcfluxPalette


func _ready() -> void:
	if random_seed != 0:
		rng.seed = random_seed
	else:
		rng.randomize()
	_build()
	_apply_palette()
	if Engine.is_editor_hint():
		set_process(preview_in_editor)
		if preview_in_editor:
			_start_preview()
	elif autoplay:
		play()


func _process(delta: float) -> void:
	_tick(delta * time_scale)
	_update_flare_visibility(delta)


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


## Emits finished. Called by concrete effects when a one-shot run has fully faded.
func _finish() -> void:
	finished.emit()


func get_palette() -> ArcfluxPalette:
	if palette:
		return palette
	if not _default_palette:
		_default_palette = ArcfluxPalette.new()
	return _default_palette


## Starts the effect. Concrete effects override this.
func play() -> void:
	pass


## Stops the effect. Concrete effects override this.
func stop() -> void:
	pass


## Virtual: create helper nodes.
func _build() -> void:
	pass


## Virtual: advance animation by a scaled delta.
func _tick(_delta: float) -> void:
	pass


## Virtual: what to do when the node is shown in the editor.
func _start_preview() -> void:
	play()


func world_scale() -> float:
	return global_basis.get_scale().x if is_inside_tree() else scale.x


func make_ribbon(material_shader: Shader = RIBBON_SHADER, spark: bool = false) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = ArrayMesh.new()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = material_shader
	mat.set_shader_parameter("seed", rng.randf() * 100.0)
	mi.material_override = mat
	if spark:
		_spark_materials.append(mat)
	else:
		_materials.append(mat)
	add_child(mi, false, Node.INTERNAL_MODE_BACK)
	return mi


func make_flare(size: float) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2.ONE
	mi.mesh = quad
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mi.extra_cull_margin = size
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = FLARE_SHADER
	mat.set_shader_parameter("size", size)
	mat.set_shader_parameter("rotation", rng.randf() * TAU)
	mat.set_shader_parameter("intensity", 0.0)
	mi.material_override = mat
	_materials.append(mat)
	_flares.append(mi)
	add_child(mi, false, Node.INTERNAL_MODE_BACK)
	return mi


## Fades flares whose centre is hidden behind a collider (flares skip the depth test).
func _update_flare_visibility(delta: float) -> void:
	if _flares.is_empty() or not is_inside_tree():
		return
	var cam: Camera3D = get_viewport().get_camera_3d()
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	for f in _flares:
		var mat: ShaderMaterial = f.material_override as ShaderMaterial
		var target: float = 1.0
		var lit: bool = float(mat.get_shader_parameter("intensity")) > 0.0005
		if lit and cam and space and not Engine.is_editor_hint() and flare_occlusion_mask != 0:
			var from: Vector3 = cam.global_position
			var to: Vector3 = f.global_position
			var dist: float = from.distance_to(to)
			var margin: float = minf(float(mat.get_shader_parameter("size")) * world_scale() * 0.2, dist * 0.5)
			if dist > margin + 0.01:
				var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to + (from - to) / dist * margin, flare_occlusion_mask)
				if not space.intersect_ray(q).is_empty():
					target = 0.0
		var v: float = float(_flare_vis.get(f, target))
		v = move_toward(v, target, delta * 12.0) if lit else target
		_flare_vis[f] = v
		mat.set_shader_parameter("visibility", v)


## Flat quad lying on the local XZ plane, for flashes, rings and scorch marks.
func make_ground_mark() -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2.ONE
	mi.mesh = plane
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = GROUND_SHADER
	mat.set_shader_parameter("seed", rng.randf() * 100.0)
	mi.material_override = mat
	_materials.append(mat)
	mi.visible = false
	add_child(mi, false, Node.INTERNAL_MODE_BACK)
	return mi


func make_light(range_mult: float = 1.0) -> OmniLight3D:
	var l: OmniLight3D = OmniLight3D.new()
	l.shadow_enabled = false
	l.light_energy = 0.0
	l.omni_attenuation = 1.6
	l.visible = false
	_light_base[l] = range_mult
	_lights.append(l)
	add_child(l, false, Node.INTERNAL_MODE_BACK)
	_apply_light_color(l)
	return l


## Sets a light pulse. level is 0..1 relative to light_energy.
func drive_light(l: OmniLight3D, level: float) -> void:
	var on: bool = light_enabled and level > 0.002
	l.visible = on
	if not on:
		return
	var s: float = world_scale()
	l.light_energy = light_energy * intensity * level
	l.omni_range = light_range * float(_light_base.get(l, 1.0)) * s


func _apply_light_color(l: OmniLight3D) -> void:
	l.light_color = get_palette().light_color


func _apply_palette() -> void:
	var p: ArcfluxPalette = get_palette()
	for m in _materials:
		m.set_shader_parameter("core_color", p.core_color)
		m.set_shader_parameter("glow_color", p.glow_color)
		m.set_shader_parameter("core_energy", p.core_energy)
		m.set_shader_parameter("glow_energy", p.glow_energy)
	for m in _spark_materials:
		m.set_shader_parameter("core_color", p.core_color)
		m.set_shader_parameter("glow_color", p.spark_color)
		m.set_shader_parameter("core_energy", p.core_energy)
		m.set_shader_parameter("glow_energy", p.glow_energy)
	for l in _lights:
		_apply_light_color(l)
