extends Area3D

const Catalog := preload("res://scripts/fabrication_catalog.gd")
static var rng := RandomNumberGenerator.new()
var materials: Dictionary

static func roll_at(host: Node3D, at: Vector3, sector: int, source: String) -> void:
	var drop := new()
	drop.materials = Catalog.roll(sector, source, rng)
	drop.position = host.to_local(at)
	host.add_child.call_deferred(drop)

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	var collider := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.74
	collider.shape = shape
	add_child(collider)
	var mesh := PrismMesh.new()
	mesh.size = Vector3(0.36, 0.45, 0.34)
	var shard := RiftProjectile.part(self, mesh, RiftProjectile.light_paint(Color("ff5ecc"), 1.5), Vector3.ZERO, Vector3.ONE)
	var spin := create_tween().set_loops()
	spin.tween_property(shard, "rotation:y", TAU, 1.8).from(0.0)
	body_entered.connect(collect)

func collect(body: Node3D) -> void:
	var operator := body as RiftPlayer
	if not operator or operator.health <= 0.0 or is_queued_for_deletion():
		return
	operator.collect_salvage(materials)
	RiftAudio.play_effect(&"pickup")
	queue_free()
