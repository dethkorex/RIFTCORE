extends Area3D

signal collected

const Catalog := preload("res://scripts/fabrication_catalog.gd")
const Blueprints := preload("res://scripts/blueprint_catalog.gd")
const Orb := preload("res://scripts/pickup_orb_visual.gd")
static var rng := RandomNumberGenerator.new()
var materials: Dictionary
var blueprint_id := ""
var consumed := false

static func roll_at(host: Node3D, at: Vector3, sector: int, source: String) -> void:
	var loot_scale := float(host.get_meta("loot_scale", 1.0))
	var materials := Catalog.roll(sector, source, rng, loot_scale)
	var blueprint := Blueprints.roll(sector, source, rng, loot_scale)
	spawn(host, at, materials)
	if not blueprint.is_empty():
		spawn(host, at + Vector3(0.63, 0.04, 0), {}, blueprint)

static func spawn(host: Node3D, at: Vector3, loot: Dictionary, blueprint := "") -> Area3D:
	var drop := new()
	drop.materials = loot
	drop.blueprint_id = blueprint
	drop.position = host.to_local(at)
	host.add_child.call_deferred(drop)
	return drop

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	var collider := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.74
	collider.shape = shape
	add_child(collider)
	var orb := Orb.new()
	orb.tint = Color("ff7957") if blueprint_id.is_empty() else Color("2abbff")
	orb.mark = Orb.Mark.MATERIAL if blueprint_id.is_empty() else Orb.Mark.BLUEPRINT
	add_child(orb)
	var bob := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(orb, "position:y", 0.13, 0.65)
	bob.tween_property(orb, "position:y", 0.0, 0.65)
	body_entered.connect(collect)

func collect(body: Node3D) -> void:
	var operator := body as RiftPlayer
	if consumed or not operator or operator.health <= 0.0 or is_queued_for_deletion():
		return
	consumed = true
	if not materials.is_empty():
		operator.collect_salvage(materials)
	if not blueprint_id.is_empty() and not operator.recovered_blueprints.has(blueprint_id):
		operator.recovered_blueprints[blueprint_id] = true
		operator.blueprint_found.emit(blueprint_id)
	RiftAudio.play_effect(&"pickup")
	collected.emit()
	queue_free()
