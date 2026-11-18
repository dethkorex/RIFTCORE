extends Node3D

const JADE := preload("res://assets/machine_jungle/jade.tres")
const BARK := preload("res://assets/machine_jungle/tread.tres")
const FERN := preload("res://assets/machine_jungle/fern.tres")
const VINE_GLOW := Color("c3ff6f")

@export var length := 4.4
var stem: Node3D
var leader: WeakRef

func _ready() -> void:
	add_to_group(&"jungle_swing")
	var crown := SphereMesh.new()
	crown.radius = 0.5
	crown.height = 1.0
	RiftProjectile.part(self, crown, BARK, Vector3(0, 0, -0.8), Vector3(2.8, 0.65, 2.0))
	stem = Node3D.new()
	add_child(stem)
	var leaf := SphereMesh.new()
	leaf.radius = 0.5
	leaf.height = 1.0
	for index in 7:
		var section := CylinderMesh.new()
		section.top_radius = lerpf(0.15, 0.075, index / 7.0)
		section.bottom_radius = lerpf(0.14, 0.06, index / 7.0)
		section.height = length / 7.0 + 0.06
		var point := Vector3(sin(index * 2.3) * 0.05, -(index + 0.5) * length / 7.0, 0.0)
		RiftProjectile.part(stem, section, BARK, point, Vector3.ONE)
		if index % 2 == 1:
			var side := -1.0 if index % 4 == 1 else 1.0
			var sprout := RiftProjectile.part(stem, leaf, FERN, point + Vector3(side * 0.19, 0.12, 0.04), Vector3(0.55, 0.12, 0.24))
			sprout.rotation.z = side * 0.58
	var loop := TorusMesh.new()
	loop.inner_radius = 0.14
	loop.outer_radius = 0.24
	var grip := RiftProjectile.part(stem, loop, JADE, Vector3.DOWN * length, Vector3.ONE)
	grip.rotation.x = PI * 0.5
	var marker := RiftProjectile.part(stem, leaf, RiftProjectile.light_paint(VINE_GLOW, 1.75), Vector3(0.0, -length + 0.20, 0.045), Vector3(.18, .13, .16))
	marker.name = "GripMarker"
	stem.rotation.z = angle_at(0.0)

func angle_at(elapsed: float) -> float:
	return -0.82 * cos(elapsed * 2.85)

func hang_at(elapsed: float) -> Vector3:
	var angle := angle_at(elapsed)
	return global_position + Vector3(sin(angle) * length, -cos(angle) * length - 0.58, 0.0)

func capture(rider: Node3D) -> void:
	leader = weakref(rider)

func _process(delta: float) -> void:
	var rider: Node3D = leader.get_ref() if leader else null
	var occupied: bool = is_instance_valid(rider) and rider.jungle_vine == self and rider.visible
	var angle: float = angle_at(rider.jungle_swing_time) if occupied else angle_at(0.0)
	stem.rotation.z = lerpf(stem.rotation.z, angle, minf(delta * (25.0 if occupied else 6.0), 1.0))
