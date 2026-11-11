extends Area3D

signal activated(spawn: Vector3)
var online := false

func _ready() -> void:
	body_entered.connect(activate)

func activate(body: Node3D) -> void:
	if online or not body is RiftPlayer or body.health <= 0.0:
		return
	online = true
	activated.emit(global_position + Vector3.UP * 0.88)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.42
	torus.outer_radius = 0.5
	ring.mesh = torus
	ring.material_override = preload("res://assets/neon_factory/cyan.tres")
	add_child(ring)
	ring.position.y = 0.12
	var pulse := create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pulse.tween_property(ring, "scale", Vector3.ONE * 3.4, 0.65)
	pulse.tween_property(ring, "position:y", 0.95, 0.65)
	pulse.chain().tween_callback(ring.queue_free)
	$Status.text = "CHECKPOINT ACTIVE"
