@tool
extends Node3D

const Ladder := preload("res://scripts/factory_ladder.gd")
const Vine := preload("res://scripts/climb_vine.gd")
const Chamfer := preload("res://scripts/factory_chamfer.gd")

enum Hatch { LEFT, CENTER, RIGHT }
const OPENING_WIDTH := 1.02
const OPENING_DEPTH := 1.12

@export var hatch: Hatch = Hatch.CENTER:
	set(value):
		hatch = value
		queue_rebuild()
@export_range(3.0, 12.0, 0.05) var deck_width := 4.0:
	set(value):
		deck_width = value
		queue_rebuild()
@export_range(1.8, 3.5, 0.05) var deck_depth := 1.94:
	set(value):
		deck_depth = value
		queue_rebuild()
@export_range(1.2, 12.0, 0.05) var climb_height := 3.2:
	set(value):
		climb_height = value
		queue_rebuild()
@export var vines := false:
	set(value):
		vines = value
		queue_rebuild()
@export var deck_material: Material = preload("res://assets/neon_factory/platform_deck.tres"):
	set(value):
		deck_material = value
		queue_rebuild()
@export var frame_material: Material = preload("res://assets/neon_factory/platform_rail.tres"):
	set(value):
		frame_material = value
		queue_rebuild()
@export var accent_material: Material = preload("res://assets/neon_factory/cyan.tres"):
	set(value):
		accent_material = value
		queue_rebuild()

var assembly: Node3D
var rebuild_pending := false
var hatch_x := 0.0

func _ready() -> void:
	rebuild()

func queue_rebuild() -> void:
	if not is_inside_tree() or rebuild_pending:
		return
	rebuild_pending = true
	rebuild.call_deferred()

func rebuild() -> void:
	rebuild_pending = false
	if not is_inside_tree():
		return
	if assembly:
		remove_child(assembly)
		assembly.queue_free()
	assembly = Node3D.new()
	assembly.name = "Assembly"
	add_child(assembly)
	var half := deck_width * 0.5
	var half_opening := OPENING_WIDTH * 0.5
	hatch_x = 0.0
	if hatch != Hatch.CENTER:
		hatch_x = (-1.0 if hatch == Hatch.LEFT else 1.0) * (half - half_opening - 0.28)
	var left := hatch_x - half_opening
	var right := hatch_x + half_opening
	build_section(-half, left, -deck_depth * 0.5, deck_depth * 0.5)
	build_section(right, half, -deck_depth * 0.5, deck_depth * 0.5)
	build_section(left, right, -deck_depth * 0.5, -OPENING_DEPTH * 0.5)
	build_section(left, right, OPENING_DEPTH * 0.5, deck_depth * 0.5)
	var climb: Node3D = Vine.new() if vines else Ladder.new()
	climb.name = "Climb"
	climb.position = Vector3(hatch_x, -climb_height, 0)
	climb.set("rise", climb_height)
	climb.set_meta("hatch_exit", -1.0 if hatch == Hatch.RIGHT else 1.0)
	climb.set_meta("hatch_landing_distance", half_opening + 0.48)
	climb.set_meta("hatch_support", build_hatch_support(hatch_x))
	assembly.add_child(climb)
	climb.add_to_group(&"factory_ladder")
	# Bright corners mark the actual opening. Keep all trim outside the climb lane.
	for side in [-1.0, 1.0]:
		for end in [-1.0, 1.0]:
			panel(assembly, Vector3(hatch_x + side * (half_opening + 0.06), 0.012, end * (OPENING_DEPTH * 0.5 + 0.06)),
				Vector3(0.10, 0.024, 0.16), accent_material)

func build_hatch_support(at_x: float) -> StaticBody3D:
	# The opening stays visible. A one-way surface catches players walking across.
	var support := StaticBody3D.new()
	support.name = "HatchWalkSupport"
	support.position = Vector3(at_x, -0.11, 0)
	support.set_meta("hatch_walk_support", true)
	assembly.add_child(support)
	support.add_to_group(&"factory_one_way")
	var collider := CollisionShape3D.new()
	collider.name = "Collider"
	var shape := BoxShape3D.new()
	shape.size = Vector3(OPENING_WIDTH, 0.22, OPENING_DEPTH)
	collider.shape = shape
	support.add_child(collider)
	return support

func supply_landing_point() -> Vector3:
	var side := -1.0 if hatch == Hatch.RIGHT else 1.0
	var edge := deck_width * 0.5 * side
	return to_global(Vector3((hatch_x + side * OPENING_WIDTH * 0.5 + edge) * 0.5, 0, 0))

func build_section(left: float, right: float, back: float, front: float) -> void:
	var size := Vector3(right - left, 0.58, front - back)
	var body := StaticBody3D.new()
	body.position = Vector3((left + right) * 0.5, -size.y * 0.5, (back + front) * 0.5)
	assembly.add_child(body)
	body.add_to_group(&"factory_one_way")
	var collider := CollisionShape3D.new()
	collider.name = "Collider"
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	panel(body, Vector3(0, -0.035, 0), size - Vector3(0.008, 0.07, 0.008), frame_material)
	panel(body, Vector3(0, size.y * 0.5 - 0.045, 0),
		Vector3(size.x - 0.026, 0.09, size.z - 0.025), deck_material)
	if front >= deck_depth * 0.5 - 0.01:
		var strips := maxi(1, roundi(size.x / 1.15))
		for index in strips:
			var x := ((index + 0.5) / strips - 0.5) * size.x
			panel(body, Vector3(x, 0.03, size.z * 0.5 + 0.008),
				Vector3(size.x / strips * 0.70, 0.045, 0.020), accent_material)

func panel(parent: Node3D, at: Vector3, size: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var piece := MeshInstance3D.new()
	piece.position = at
	piece.mesh = Chamfer.from_box(mesh, 0.035)
	piece.material_override = material
	parent.add_child(piece)
