@tool
extends Area3D

@export_range(1.0, 16.0, 0.05) var width := 4.0:
	set(value):
		width = value
		if is_node_ready():
			size_pool()

@export_range(2.0, 24.0, 0.1) var basin_depth := 14.0:
	set(value):
		basin_depth = value
		if is_node_ready():
			size_pool()

func _ready() -> void:
	size_pool()
	if not Engine.is_editor_hint():
		body_entered.connect(touch_slag)

func size_pool() -> void:
	var surface := BoxMesh.new()
	surface.size = Vector3(width + 0.18, 14, 7.6)
	surface.subdivide_width = ceili(width)
	$Surface.mesh = surface
	$Surface.scale = Vector3(1, basin_depth / 14.0, 1)
	$Surface.position = Vector3(0, -basin_depth * 0.5, -2.05)
	var contact := BoxShape3D.new()
	contact.size = Vector3(width, 1.4, 3.5)
	$Contact.shape = contact

func touch_slag(body: Node3D) -> void:
	if body is RiftPlayer and body.is_physics_processing() and not body.local_prediction:
		body.die_in_pit()
