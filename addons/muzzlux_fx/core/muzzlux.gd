class_name Muzzlux
extends RefCounted
## Global settings and the one-line helper for MUZZLUX Lite.
##
##   Muzzlux.impact(hit.position, hit.normal, &"metal")
##   Muzzlux.quality = Muzzlux.Quality.LOW
##
## Lite version. The full pack adds Muzzlux.shot(parent, "gun_rifle", muzzle_transform),
## which starts any of its 58 presets in one call, the 2D preset folder, and the master
## switch for its optional dark-red layer (off by default there too).

enum Quality { LOW, MEDIUM, HIGH }

const PRESET_DIR_3D: String = "res://addons/muzzlux_fx/presets/3d/"

## Default quality for every effect whose own quality is DEFAULT.
static var quality: Quality = Quality.HIGH
## Air movement shared by every effect with use_global_wind on, metres per second. The cloud
## a hit throws off drifts with it; sparks and solid pieces ignore it.
static var wind: Vector3 = Vector3.ZERO
## Where one-shot impacts spawned by Muzzlux.impact() are parented when no parent is given.
static var impact_parent: Node = null
## A scene Muzzlux.impact() uses instead of looking a preset up by surface name. Set it once
## at startup to a project's own impact scene (or to one of the pack's presets) and every
## impact() call goes through it; the surface id is still handed to its burst(). Null keeps
## the default behaviour, which is to look up `impact_<surface>` in the preset folder.
static var impact_scene: PackedScene = null


## Element count multiplier for a quality level.
static func quality_factor(q: Quality) -> float:
	match q:
		Quality.LOW:
			return 0.35
		Quality.MEDIUM:
			return 0.65
	return 1.0


## Fire-and-forget material impact at a hit point. `surface` is one of the three ids Lite
## ships a look for: &"concrete", &"metal", &"wood". An id Lite does not know draws the
## concrete hit, so a typo shows something rather than nothing.
##
## Lite has no surface table, so nothing works the surface out for you: pass the string. The
## full pack resolves it from the collider (a meta key, a PhysicsMaterial name or the node
## name) and ships nine surfaces plus `energy`.
##
## Set Muzzlux.impact_scene to use one scene for every surface instead of a preset per
## surface; the id is handed to burst() either way, so the look still comes from the table.
static func impact(position: Vector3, normal: Vector3, surface: StringName = &"concrete",
		parent: Node = null) -> Node:
	var host: Node = parent if parent != null else impact_parent
	if host == null:
		push_warning("Muzzlux.impact: no parent. Pass one, or set Muzzlux.impact_parent.")
		return null
	var scene: PackedScene = impact_scene
	if scene == null:
		scene = _find_preset("impact_%s" % surface)
	if scene == null:
		# A surface Lite has no preset for goes through the concrete one and is told which
		# surface it is: the look comes from the row, not from the file.
		scene = _find_preset("impact_concrete")
	if scene == null:
		push_warning("Muzzlux.impact: no impact preset for surface: %s" % str(surface))
		return null
	var node: Node = _spawn(host, scene, position)
	if node.has_method(&"burst"):
		node.call(&"burst", position, normal, surface, 1.0)
	return node


## Instances a scene, makes it free itself when it has finished, adds it and places it.
## It never starts the effect; impact() calls burst() itself straight afterwards.
static func _spawn(parent: Node, scene: PackedScene, place: Variant) -> Node:
	var node: Node = scene.instantiate()
	# autoplay off before it enters the tree. Every shipped preset has autoplay on, so a
	# one-shot would otherwise go off once at _ready at the node's own position and then
	# again where it was asked for: a hit at the wrong place, followed by the real one.
	var e3: MuzzluxEffect3D = node as MuzzluxEffect3D
	if e3 != null:
		e3.autoplay = false
		e3.free_when_done = true
	parent.add_child(node)
	_place(node, place)
	return node


static func _find_preset(preset: Variant) -> PackedScene:
	if preset is PackedScene:
		return preset
	if not (preset is String or preset is StringName):
		return null
	var path: String = str(preset)
	if not path.begins_with("res://"):
		path = PRESET_DIR_3D + path + ".tscn"
	if not ResourceLoader.exists(path):
		return null
	return load(path) as PackedScene


static func _place(node: Node, place: Variant) -> void:
	var n3: Node3D = node as Node3D
	if place is Transform3D and n3 != null:
		n3.global_transform = place
	elif place is Vector3 and n3 != null:
		n3.global_position = place
