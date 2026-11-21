extends Area3D

const Blueprints := preload("res://scripts/blueprint_catalog.gd")
const Difficulty := preload("res://scripts/mission_difficulty.gd")
const Orbs := preload("res://scripts/material_pickup.gd")
const Materials := preload("res://scripts/fabrication_catalog.gd")
static var rng := RandomNumberGenerator.new()

@export var sector := 1
@export var materials := 4
@export var weapon_cache := false
@export var fixed_blueprint := ""
@export var fixed_supply := ""
var opened := false
var difficulty := 0

func _ready() -> void:
	body_entered.connect(open_chest)

func open_chest(body: Node3D) -> void:
	if opened or not body is RiftPlayer or body.health <= 0:
		return
	opened = true
	var opened_caches: Array = body.get_meta("factory_caches", [])
	opened_caches.append(String(name))
	body.set_meta("factory_caches", opened_caches)
	burst.call_deferred(body)

func burst(operator: RiftPlayer) -> void:
	var terrain := get_parent() as Node3D
	var at := global_position + Vector3.UP * .46
	var personalized: Callable = terrain.get_parent().get_meta(&"personal_chest", Callable())
	if personalized.is_valid():
		personalized.call(String(name), at, self)
	elif is_instance_valid(operator):
		Orbs.spill(terrain, at, roll_loot(RiftPlayer.level_for_experience(operator.experience)))
	finish_open()

func roll_loot(level: int) -> Dictionary:
	var salvage := {"scrap": materials, Materials.sector_key(sector): materials}
	if not fixed_blueprint.is_empty() or not fixed_supply.is_empty():
		return {"materials": salvage, "blueprint": fixed_blueprint, "supply": fixed_supply, "life": rng.randf() < Orbs.EXTRA_LIFE_CHANCE}
	var blueprint := Blueprints.roll_cache(sector, difficulty, level, false, rng)
	if weapon_cache:
		var pool := Blueprints.drop_pool(sector, difficulty, level, false)
		for part in [10, 8, 2]:
			if part in pool:
				blueprint = Blueprints.blueprint_id(sector, part)
				break
	return {
		"materials": salvage,
		"blueprint": blueprint,
		"supply": Orbs.supply_roll(rng, .022 * Difficulty.LOOT[difficulty], difficulty > 0),
		"life": rng.randf() < Orbs.EXTRA_LIFE_CHANCE,
	}

func finish_open() -> void:
	var flash := preload("res://scripts/pit_burst.gd").new()
	get_parent().add_child.call_deferred(flash)
	flash.set_deferred("position", position)
	flash.ignite.call_deferred()
	get_tree().create_timer(.45, false).timeout.connect(flash.queue_free)
	RiftAudio.play_effect(&"enemy_break")
	queue_free()
