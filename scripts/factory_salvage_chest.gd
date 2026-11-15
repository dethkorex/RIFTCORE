extends Area3D

signal spilled(key: String, at: Vector3, rewards: Dictionary, drops: Array[Area3D])

const Orbs := preload("res://scripts/material_pickup.gd")
const Materials := preload("res://scripts/fabrication_catalog.gd")
static var rng := RandomNumberGenerator.new()

@export var sector := 1
@export var blueprint := ""
@export var bolts := 85
@export var materials := 4
@export var experience := 22
var opened := false

func _ready() -> void:
	body_entered.connect(open_chest)

func open_chest(body: Node3D) -> void:
	if opened or not body is RiftPlayer or body.health <= 0:
		return
	opened = true
	var opened_caches: Array = body.get_meta("factory_caches", [])
	opened_caches.append(String(name))
	body.set_meta("factory_caches", opened_caches)
	burst.call_deferred()

func burst() -> void:
	var terrain := get_parent() as Node3D
	var at := global_position + Vector3.UP * .46
	var rewards := {
		"materials": {"scrap": materials, Materials.sector_key(sector): materials},
		"blueprint": blueprint, "bolts": bolts, "xp": experience,
		"supply": Orbs.supply_roll(rng, .33, sector >= 4),
	}
	var drops := Orbs.spill(terrain, at, rewards)
	spilled.emit(String(name), at, rewards, drops)
	finish_open()

func finish_open() -> void:
	var flash := preload("res://scripts/pit_burst.gd").new()
	get_parent().add_child.call_deferred(flash)
	flash.set_deferred("position", position)
	flash.ignite.call_deferred()
	get_tree().create_timer(.45, false).timeout.connect(flash.queue_free)
	RiftAudio.play_effect(&"enemy_break")
	queue_free()
