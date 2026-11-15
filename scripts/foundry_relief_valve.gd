extends StaticBody3D

signal released

const ORANGE := Color("ff9e46")
var ready_to_shoot := false
var lamp: MeshInstance3D
var wheel: MeshInstance3D

func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = Vector3(.55, .74, .72)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	add_child(collider)
	var steel := RiftProjectile.light_paint(Color("3d2731"), 0.0)
	var frame := BoxMesh.new()
	RiftProjectile.part(self, frame, steel, Vector3(-.06, -.45, -.27), Vector3(.65, 1.65, .36))
	var ring := TorusMesh.new()
	ring.inner_radius = .24
	ring.outer_radius = .37
	wheel = RiftProjectile.part(self, ring, steel, Vector3.ZERO, Vector3.ONE)
	wheel.rotation.x = PI * .5
	lamp = RiftProjectile.part(self, RiftProjectile.cached_mesh("Orb"), steel, Vector3(0, 0, .16), Vector3.ONE * .26)

func present_vent(enabled: bool, authority: bool) -> void:
	if enabled == ready_to_shoot:
		return
	ready_to_shoot = enabled
	set_deferred("collision_layer", 2 if enabled and authority else 0)
	var paint := RiftProjectile.light_paint(ORANGE if enabled else Color("483845"), 2.8 if enabled else .08)
	wheel.material_override = paint
	lamp.material_override = paint

func hit_by_projectile(shot: RiftProjectile) -> bool:
	if not ready_to_shoot or shot.owner_faction != "player":
		return false
	present_vent(false, true)
	released.emit()
	return true
