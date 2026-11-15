extends Area3D

signal collected

const Catalog := preload("res://scripts/fabrication_catalog.gd")
const Blueprints := preload("res://scripts/blueprint_catalog.gd")
const Orb := preload("res://scripts/pickup_orb_visual.gd")
static var rng := RandomNumberGenerator.new()
var materials: Dictionary
var blueprint_id := ""
var consumed := false
var bonus: Dictionary
var scatter_origin := Vector3.INF
var authoritative := true

static func supply_roll(random: RandomNumberGenerator, chance: float, rare: bool) -> String:
	if random.randf() >= chance:
		return ""
	var pool := ["patch_kit", "spark_cell", "field_pack", "guard_film", "strike_amp", "stride_gel"]
	if rare:
		pool.append_array(["trauma_kit", "ion_cell", "pulse_amp", "shield_coat"])
	return pool[random.randi_range(0, pool.size() - 1)]

static func roll_at(host: Node3D, at: Vector3, sector: int, source: String) -> void:
	var loot_scale := float(host.get_meta("loot_scale", 1.0))
	var materials := Catalog.roll(sector, source, rng, loot_scale)
	var blueprint := Blueprints.roll(sector, source, rng, loot_scale)
	spawn(host, at, materials)
	if not blueprint.is_empty():
		spawn(host, at + Vector3(0.63, 0.04, 0), {}, blueprint)

static func spawn(host: Node3D, at: Vector3, loot: Dictionary, blueprint := "", payload: Dictionary = {}, origin := Vector3.INF, authority := true) -> Area3D:
	var drop := new()
	drop.materials = loot
	drop.blueprint_id = blueprint
	drop.bonus = payload
	drop.scatter_origin = origin
	drop.authoritative = authority
	drop.position = host.to_local(at)
	host.add_child.call_deferred(drop)
	return drop

static func spill(host: Node3D, at: Vector3, rewards: Dictionary, authority := true) -> Array[Area3D]:
	var drops: Array[Area3D] = []
	var contents: Array[Dictionary] = [{"materials": rewards.materials}]
	for kind in ["bolts", "xp", "blueprint", "supply"]:
		if rewards.has(kind) and (int(rewards[kind]) > 0 if kind in ["bolts", "xp"] else not String(rewards[kind]).is_empty()):
			contents.append({kind: rewards[kind]})
	for index in contents.size():
		var offset: float = [0.95, -1.0, 1.9, -2.0, 2.75][index]
		var drop_position := at + Vector3(offset, 0, 0)
		var query := PhysicsRayQueryParameters3D.create(drop_position + Vector3.UP, drop_position - Vector3.UP * 1.4, 1)
		var ground := host.get_world_3d().direct_space_state.intersect_ray(query)
		if not ground.is_empty() and ground.collider is PhysicsBody3D and not ground.collider is CharacterBody3D:
			drop_position.y = ground.position.y + .44
		else:
			drop_position = at + Vector3(offset * .22, .10 * index, 0)
		var payload := contents[index]
		drops.append(spawn(host, drop_position, payload.get("materials", {}), payload.get("blueprint", ""), payload, at, authority))
	return drops

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 if authoritative else 0
	var collider := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.74
	collider.shape = shape
	add_child(collider)
	var orb := Orb.new()
	orb.tint = Color("ff7957") if blueprint_id.is_empty() else Color("2abbff")
	orb.mark = Orb.Mark.MATERIAL if blueprint_id.is_empty() else Orb.Mark.BLUEPRINT
	if bonus.has("bolts"):
		orb.tint = Color("ffce50")
		orb.mark = Orb.Mark.NONE
	elif bonus.has("xp"):
		orb.tint = Color("bf72ff")
		orb.mark = Orb.Mark.XP
	elif bonus.has("supply"):
		orb.tint = Color("75ffd2")
		orb.mark = Orb.Mark.SUPPLY
	add_child(orb)
	if scatter_origin.is_finite():
		monitoring = false
		orb.global_position = scatter_origin
		var toss := create_tween()
		var midpoint := to_local(scatter_origin).lerp(Vector3.ZERO, .5) + Vector3.UP * .70
		toss.tween_property(orb, "position", midpoint, .14).set_ease(Tween.EASE_OUT)
		toss.tween_property(orb, "position", Vector3.ZERO, .20).set_ease(Tween.EASE_IN)
		toss.tween_callback(func():
			monitoring = authoritative
			start_bob(orb)
		)
	else:
		start_bob(orb)
	if authoritative:
		body_entered.connect(collect)

func start_bob(orb: Node3D) -> void:
	var bob := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(orb, "position:y", 0.13, 0.65)
	bob.tween_property(orb, "position:y", 0.0, 0.65)

func collect(body: Node3D) -> void:
	var operator := body as RiftPlayer
	if consumed or not authoritative or not operator or operator.health <= 0.0 or is_queued_for_deletion():
		return
	if bonus.has("supply") and not operator.collect_supply(String(bonus.supply)):
		return
	consumed = true
	if bonus.has("bolts"):
		operator.credits += int(bonus.bolts)
		operator.credits_changed.emit(operator.credits)
	if bonus.has("xp"):
		if operator.coop_xp_pickup.is_valid():
			operator.coop_xp_pickup.call(int(bonus.xp))
		else:
			operator.gain_experience(int(bonus.xp))
	if not materials.is_empty():
		operator.collect_salvage(materials)
	if not blueprint_id.is_empty() and not operator.recovered_blueprints.has(blueprint_id):
		operator.recovered_blueprints[blueprint_id] = true
		operator.blueprint_found.emit(blueprint_id)
	RiftAudio.play_effect(&"pickup")
	collected.emit()
	queue_free()
