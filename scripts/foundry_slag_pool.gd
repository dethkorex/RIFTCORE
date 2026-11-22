@tool
extends Area3D

@export_range(1.0, 16.0, 0.05) var width := 4.0:
	set(value):
		width = value
		if is_node_ready():
			size_pool()

func _ready() -> void:
	size_pool()
	if not Engine.is_editor_hint():
		body_entered.connect(touch_slag)

func size_pool() -> void:
	var surface := PlaneMesh.new()
	surface.size = Vector2(width + .46, 8.1)
	surface.subdivide_width = ceili(width * 5.0)
	surface.subdivide_depth = 22
	$Surface.mesh = surface
	var contact := BoxShape3D.new()
	contact.size = Vector3(width, 1.48, 3.5)
	$Contact.shape = contact

func touch_slag(body: Node3D) -> void:
	if body is RiftPlayer and body.is_physics_processing() and not body.local_prediction:
		body.die_in_pit()
