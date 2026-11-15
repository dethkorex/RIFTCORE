extends CharacterBody3D

const Orbs := preload("res://scripts/material_pickup.gd")
const HEALTH := preload("res://assets/pickups/health_large.tscn")
const ENERGY := preload("res://assets/pickups/energy_large.tscn")
static var rng := RandomNumberGenerator.new()

var reward: PackedScene
var adaptive_supply := false
var authority := true
var operator: RiftPlayer
var opened := false

static func supply_loot(standard: PackedScene, adaptive: bool, recipient: RiftPlayer) -> Dictionary:
	var quick := Orbs.supply_roll(rng, 0.0125, false)
	if not quick.is_empty():
		return {"supply": quick}
	var pickup := standard
	if adaptive:
		var needs_energy := is_instance_valid(recipient) and recipient.health > recipient.max_health * 0.8
		pickup = ENERGY if needs_energy else HEALTH
	return {"pickup": pickup.resource_path if pickup else HEALTH.resource_path}

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
	if global_position.y < -16.0:
		queue_free()
	elif is_on_floor():
		break_open()

func break_open() -> void:
	if opened:
		return
	opened = true
	var terrain := get_parent() as Node3D
	var at := global_position + Vector3.UP * 0.15
	var personalized: Callable = terrain.get_parent().get_meta(&"personal_drone_loot", Callable())
	if authority:
		if personalized.is_valid():
			personalized.call(at, reward, adaptive_supply)
		else:
			var supply := supply_loot(reward, adaptive_supply, operator)
			if supply.has("pickup"):
				var pickup := (load(supply.pickup) as PackedScene).instantiate() as Area3D
				pickup.position = terrain.to_local(at)
				terrain.add_child.call_deferred(pickup)
			else:
				Orbs.spill(terrain, at, supply)
	var burst := preload("res://scripts/pit_burst.gd").new()
	get_parent().add_child(burst)
	burst.global_position = global_position
	burst.scale = Vector3.ONE * 0.55
	burst.ignite()
	RiftAudio.play_effect(&"enemy_break")
	get_tree().create_timer(0.45, false).timeout.connect(burst.queue_free)
	queue_free()
