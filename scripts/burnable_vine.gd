@tool
extends StaticBody3D

var faction := "scenery"
var health := 1.0
var lattice: Node3D

func _ready() -> void:
	lattice = Node3D.new()
	add_child(lattice)
	var root_color := RiftProjectile.light_paint(Color("295c40"), 0.1)
	var leaf := RiftProjectile.light_paint(Color("8edb52"), 0.38)
	for vine in range(4):
		var prev := Vector3(0.0, -0.15, -0.78 + vine * 0.5)
		for joint in range(1, 8):
			var at := Vector3(sin(joint * 0.91 + vine * 1.5) * 0.23, joint * 0.40 - 0.12, prev.z)
			var branch := CylinderMesh.new()
			branch.top_radius = 0.085
			branch.bottom_radius = 0.13
			branch.height = at.distance_to(prev) * 1.08
			branch.radial_segments = 6
			var part := RiftProjectile.part(lattice, branch, root_color, prev.lerp(at, 0.5), Vector3.ONE)
			part.quaternion = Quaternion(Vector3.UP, (at - prev).normalized())
			if (vine + joint) % 2 == 0:
				var blade := RiftProjectile.part(lattice, RiftProjectile.cached_mesh("Orb"), leaf, at + Vector3(0.13, 0.04, 0.09), Vector3(0.19, 0.06, 0.11))
				blade.rotation.z = sin(joint) * 0.72
			prev = at

func take_damage(_amount: float, _source := Vector3.ZERO) -> void:
	pass

func take_fire_damage(amount: float, _source := Vector3.ZERO) -> void:
	if health <= 0.0 or amount <= 0.0:
		return
	health = 0.0
	$CollisionShape3D.set_deferred("disabled", true)
	_burn.call_deferred()

func _burn() -> void:
	var fire := preload("res://scripts/pit_burst.gd").new()
	add_child(fire)
	fire.position.y = 1.16
	fire.ignite(Color("ff8d39"))
	RiftAudio.play_effect(&"enemy_break")
	var collapse := create_tween().set_parallel().set_trans(Tween.TRANS_QUAD)
	collapse.tween_property(lattice, "scale:y", 0.04, 0.48)
	collapse.tween_property(lattice, "rotation:z", 0.65, 0.48)
	collapse.chain().tween_callback(queue_free)
