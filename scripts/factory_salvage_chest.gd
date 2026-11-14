extends Area3D

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
	body.credits += bolts
	body.credits_changed.emit(body.credits)
	body.collect_salvage({"scrap": materials, preload("res://scripts/fabrication_catalog.gd").sector_key(sector): materials})
	if body.coop_xp_pickup.is_valid():
		body.coop_xp_pickup.call(experience)
	else:
		body.gain_experience(experience)
	if not blueprint.is_empty() and not body.recovered_blueprints.has(blueprint):
		body.recovered_blueprints[blueprint] = true
		body.blueprint_found.emit(blueprint)
	RiftAudio.play_effect(&"pickup")
	queue_free()
