extends Combatant

const Crate := preload("res://scripts/cargo_crate.gd")
@export var reward: PackedScene
var adaptive_supply := false
var supply_target: RiftPlayer
var faction := "enemy"
var origin: Vector3
var clock := 0.0

func _ready() -> void:
	# Shootable layer: projectiles can hit it; player movement cannot.
	collision_layer = 2
	collision_mask = 0
	max_health = 18.0
	super._ready()
	origin = position
	add_to_group(&"shootable_cargo")
	var scene := preload("res://assets/enemies/factory_flyer.tscn")
	var drone := scene.instantiate() as Node3D
	drone.scale = Vector3.ONE * 0.65
	add_child(drone)
	var cargo := Crate.make_visual()
	cargo.position.y -= 0.6
	add_child(cargo)
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.47
	shape.shape = sphere
	add_child(shape)
	died.connect(drop_crate)

func _physics_process(delta: float) -> void:
	clock += delta
	position = origin + Vector3(sin(clock * 1.25) * 0.34, sin(clock * 2.1) * 0.18, 0.0)

func drop_crate() -> void:
	var crate := Crate.new()
	crate.reward = reward
	crate.sector = int(get_tree().current_scene.get("sector")) if get_tree().current_scene and "sector" in get_tree().current_scene else 1
	if adaptive_supply:
		var need_energy := is_instance_valid(supply_target) and supply_target.health / supply_target.max_health > 0.8
		crate.reward = preload("res://assets/pickups/energy_large.tscn") if need_energy else preload("res://assets/pickups/health_large.tscn")
		crate.add_to_group(&"boss_supply")
	crate.position = position - Vector3.UP * 0.6
	get_parent().add_child.call_deferred(crate)
	hide()
	queue_free()
