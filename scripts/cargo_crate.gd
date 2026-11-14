extends CharacterBody3D

var reward: PackedScene
var sector := 1

func _ready() -> void:
	collision_layer = 0
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.65, 0.58, 0.65)
	collider.shape = box
	add_child(collider)
	add_child(make_visual())

static func make_visual() -> Node3D:
	var scene := load("res://assets/enemies/Lootbox.gltf") as PackedScene
	var visual := scene.instantiate() as Node3D
	visual.scale = Vector3.ONE * 0.68
	visual.position.y = -0.29
	return visual

func _physics_process(delta: float) -> void:
	velocity.y -= 24.0 * delta
	move_and_slide()
	if global_position.y < -5.0:
		queue_free()
	elif is_on_floor():
		break_open()

func break_open() -> void:
	preload("res://scripts/material_pickup.gd").roll_at(get_parent_node_3d(), global_position, sector, "container")
	if reward:
		var pickup := reward.instantiate() as Area3D
		pickup.position = position + Vector3.UP * 0.15
		get_parent().add_child.call_deferred(pickup)
	var burst := preload("res://scripts/pit_burst.gd").new()
	get_parent().add_child(burst)
	burst.global_position = global_position
	burst.scale = Vector3.ONE * 0.55
	burst.ignite()
	RiftAudio.play_effect(&"enemy_break")
	get_tree().create_timer(0.45, false).timeout.connect(burst.queue_free)
	queue_free()
