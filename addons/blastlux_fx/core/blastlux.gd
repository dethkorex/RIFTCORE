class_name Blastlux
extends RefCounted
## Global settings and the one-line helpers of BLASTLUX.
## Lite version: BlastluxShockwave3D and its three presets. The full pack adds the blasts
## themselves (fireball, crater, debris, meshes that buckle, scorch and break), clusters, flak,
## smoke columns, debris and the 2D nodes.
##
##   Blastlux.spawn(self, "shockwave_dust_ring", point)   # a wave there, freed when done
##   Blastlux.wind = Vector3(1.5, 0.0, 0.0)               # dust drift

enum Quality { LOW, MEDIUM, HIGH }

const VERSION: String = "1.0.0"
const MIN_GODOT: Array[int] = [4, 4]
const PRESET_DIR_3D: String = "res://addons/blastlux_fx/presets/3d/"
const SHADER_DIR: String = "res://addons/blastlux_fx/shaders/"
const WARMUP_FRAMES: int = 3

static var quality: Quality = Quality.HIGH
static var wind: Vector3 = Vector3.ZERO
static var _version_result: int = -1


class WarmupHolder extends Node3D:
	var frames_left: int = Blastlux.WARMUP_FRAMES

	func _process(_delta: float) -> void:
		frames_left -= 1
		if frames_left <= 0:
			queue_free()


static func check_version() -> bool:
	if _version_result < 0:
		var v: Dictionary = Engine.get_version_info()
		var major: int = v.get("major", 0)
		var minor: int = v.get("minor", 0)
		var ok: bool = major > MIN_GODOT[0] or (major == MIN_GODOT[0] and minor >= MIN_GODOT[1])
		if not ok:
			push_error("BLASTLUX needs Godot %d.%d or newer (you have %s)" % [MIN_GODOT[0], MIN_GODOT[1], str(v["string"])])
		_version_result = 1 if ok else 0
	return _version_result == 1


static func quality_factor(q: Quality) -> float:
	match q:
		Quality.LOW:
			return 0.35
		Quality.MEDIUM:
			return 0.65
	return 1.0


## Instances a preset under `parent`, moves it to `position` and plays it; a one-shot frees
## itself when done. `preset` is a preset name, a res:// path or a PackedScene.
static func spawn(parent: Node, preset: Variant, position: Variant = null) -> Node:
	var scene: PackedScene = null
	if preset is PackedScene:
		scene = preset
	elif preset is String or preset is StringName:
		var path: String = str(preset)
		if not path.begins_with("res://"):
			path = PRESET_DIR_3D + path + ".tscn"
		if ResourceLoader.exists(path):
			scene = load(path) as PackedScene
	if scene == null or parent == null:
		push_warning("Blastlux.spawn: preset not found: %s" % str(preset))
		return null
	var node: Node = scene.instantiate()
	if node is BlastluxEffect3D:
		var e3: BlastluxEffect3D = node
		e3.autoplay = false
		e3.free_when_done = e3.is_one_shot()
	parent.add_child(node)
	if position is Vector3 and node is Node3D:
		var n3: Node3D = node
		n3.global_position = position
	if node.has_method(&"play"):
		node.call(&"play")
	return node


## How hard a camera at `camera_pos` should shake for a blast of `radius` at `point`: 0..1.
## BLASTLUX never moves your camera; feed this to your own shake.
static func shake_hint(point: Vector3, radius: float, camera_pos: Vector3) -> float:
	var d: float = point.distance_to(camera_pos)
	var reach: float = maxf(radius, 0.1) * 6.0
	return clampf(1.0 - d / reach, 0.0, 1.0)


static func preset_names() -> Array[String]:
	var out: Array[String] = []
	if not DirAccess.dir_exists_absolute(PRESET_DIR_3D):
		return out
	for f: String in DirAccess.get_files_at(PRESET_DIR_3D):
		var n: String = f.trim_suffix(".remap")
		if n.ends_with(".tscn"):
			out.append(n.get_basename())
	return out


## Draws every shader (and preset, if names are given) once, tiny, so the first real blast
## does not stall on shader compilation. Returns the number of presets warmed.
static func warmup(parent: Node, presets: Array[String] = []) -> int:
	if parent == null or not parent.is_inside_tree():
		push_warning("Blastlux.warmup: parent must be inside the tree")
		return 0
	check_version()
	var names: Array[String] = presets if not presets.is_empty() else preset_names()
	var holder: WarmupHolder = WarmupHolder.new()
	holder.name = "BlastluxWarmup"
	holder.scale = Vector3.ONE * 0.001
	if parent is Camera3D:
		holder.position = Vector3(0.0, 0.0, -0.6)
	parent.add_child(holder)
	if presets.is_empty() and DirAccess.dir_exists_absolute(SHADER_DIR):
		for f: String in DirAccess.get_files_at(SHADER_DIR):
			if not f.ends_with(".gdshader"):
				continue
			var sh: Shader = load(SHADER_DIR + f) as Shader
			if sh == null or f.ends_with("_2d.gdshader"):
				continue
			var m: ShaderMaterial = ShaderMaterial.new()
			m.shader = sh
			var mi: MeshInstance3D = MeshInstance3D.new()
			var quad: QuadMesh = QuadMesh.new()
			quad.size = Vector2(0.5, 0.5)
			mi.mesh = quad
			mi.material_override = m
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			holder.add_child(mi)
	var n: int = 0
	for preset_name: String in names:
		var path: String = preset_name if preset_name.begins_with("res://") else PRESET_DIR_3D + preset_name + ".tscn"
		if not ResourceLoader.exists(path):
			continue
		var scene: PackedScene = load(path) as PackedScene
		if scene == null:
			continue
		var node: Node = scene.instantiate()
		if node is BlastluxEffect3D:
			var fx: BlastluxEffect3D = node
			fx.light_enabled = false
			fx.autoplay = false
			if fx.has_method(&"get_target"):
				var mi: MeshInstance3D = MeshInstance3D.new()
				var box: BoxMesh = BoxMesh.new()
				box.size = Vector3.ONE * 0.5
				mi.mesh = box
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				holder.add_child(mi)
				mi.add_child(fx)
			else:
				holder.add_child(fx)
			fx.play()
			n += 1
		else:
			node.free()
	return n
