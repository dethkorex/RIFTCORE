extends Area3D

signal opened

const Crate := preload("res://scripts/cargo_crate.gd")
const UI := preload("res://scripts/rift_ui.gd")
const Orbs := preload("res://scripts/material_pickup.gd")
const Materials := preload("res://scripts/fabrication_catalog.gd")
const Blueprints := preload("res://scripts/blueprint_catalog.gd")
const Difficulty := preload("res://scripts/mission_difficulty.gd")
static var rng := RandomNumberGenerator.new()

var authoritative := true
var claimed := false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 if authoritative else 0
	var collider := CollisionShape3D.new()
	var trigger := SphereShape3D.new()
	trigger.radius = 0.88
	collider.shape = trigger
	add_child(collider)
	var chest := Crate.make_visual()
	chest.scale *= 1.45
	add_child(chest)
	var label := Label3D.new()
	label.text = "BOSS CACHE"
	label.font = UI.DISPLAY
	label.modulate = Color("ffc867")
	label.outline_size = 8
	label.pixel_size = 0.0047
	label.position.y = 0.70
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)
	if authoritative:
		body_entered.connect(try_open)

func try_open(body: Node3D) -> void:
	if claimed or not body is RiftPlayer or body.health <= 0.0:
		return
	claimed = true
	opened.emit()
	finish_open()

func finish_open() -> void:
	var flash := preload("res://scripts/pit_burst.gd").new()
	get_parent().add_child.call_deferred(flash)
	flash.set_deferred("position", position)
	flash.ignite.call_deferred()
	get_tree().create_timer(0.45, false).timeout.connect(flash.queue_free)
	RiftAudio.play_effect(&"enemy_break")
	queue_free()

static func roll_loot(sector: int, mode: int) -> Dictionary:
	var loot_scale: float = Difficulty.LOOT[mode]
	var bonus := Materials.roll(sector, "boss", rng, loot_scale)
	for item in ["scrap", Materials.sector_key(sector)]:
		bonus[item] = int(bonus.get(item, 0)) + 2
	var source := "nightmare_cache" if mode == Difficulty.NIGHTMARE else "boss_cache"
	return {"materials": bonus, "blueprint": Blueprints.roll(sector, source, rng, loot_scale)}

static func spill(parent: Node3D, at: Vector3, rewards: Dictionary) -> Array[Area3D]:
	var pickups: Array[Area3D] = [Orbs.spawn(parent, at + Vector3(-0.36, 0.14, 0), rewards.materials)]
	if not String(rewards.blueprint).is_empty():
		pickups.append(Orbs.spawn(parent, at + Vector3(0.53, 0.14, 0), {}, rewards.blueprint))
	return pickups
