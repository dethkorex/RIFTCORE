extends Area3D

signal collected

const Orb := preload("res://scripts/pickup_orb_visual.gd")
const EXTRA_LIFE := preload("res://assets/pickups/extra_life.tscn")
const EXTRA_LIFE_CHANCE := 0.08
var materials: Dictionary
var blueprint_id := ""
var consumed := false
var bonus: Dictionary
var scatter_origin := Vector3.INF
var authoritative := true
var claimant: RiftPlayer
var local_copy := true

static func supply_roll(random: RandomNumberGenerator, chance: float, rare: bool) -> String:
	if random.randf() >= chance:
		return ""
	var pool := ["patch_kit", "spark_cell", "field_pack", "guard_film", "strike_amp", "stride_gel"]
	if rare:
		pool.append_array(["trauma_kit", "ion_cell", "pulse_amp", "shield_coat"])
	return pool[random.randi_range(0, pool.size() - 1)]

static func spawn(host: Node3D, at: Vector3, loot: Dictionary, blueprint := "", payload: Dictionary = {}, origin := Vector3.INF, authority := true, owner: RiftPlayer = null, show_local := true) -> Area3D:
	var drop := new()
	drop.materials = loot
	drop.blueprint_id = blueprint
	drop.bonus = payload
	drop.scatter_origin = origin
	drop.authoritative = authority
	drop.claimant = owner
	drop.local_copy = show_local
	drop.position = host.to_local(at)
	host.add_child.call_deferred(drop)
	return drop

static func spill(host: Node3D, at: Vector3, rewards: Dictionary, authority := true, owner: RiftPlayer = null, show_local := true) -> Array[Area3D]:
	var drops: Array[Area3D] = []
	var contents: Array[Dictionary] = []
	var materials_in_cache: Dictionary = rewards.get("materials", {})
	if not materials_in_cache.is_empty():
		contents.append({"materials": materials_in_cache})
	for kind in ["blueprint", "supply"]:
		if not String(rewards.get(kind, "")).is_empty():
			contents.append({kind: rewards[kind]})
	if rewards.get("life", false):
		contents.append({"life": true})
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
		if payload.has("life"):
			var life := EXTRA_LIFE.instantiate() as Area3D
			life.position = host.to_local(drop_position)
			life.claimant = owner
			life.replica = not authority
			life.local_copy = show_local
			host.add_child.call_deferred(life)
			drops.append(life)
		else:
			drops.append(spawn(host, drop_position, payload.get("materials", {}), payload.get("blueprint", ""), payload, at, authority, owner, show_local))
	return drops

func _ready() -> void:
	collision_layer = 0
	visible = local_copy
	collision_mask = 1 if authoritative else 0
	var collider := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.74
	collider.shape = shape
	add_child(collider)
	var orb := Orb.new()
	orb.tint = Color("ff7957") if blueprint_id.is_empty() else Color("2abbff")
	orb.mark = Orb.Mark.MATERIAL if blueprint_id.is_empty() else Orb.Mark.BLUEPRINT
	if bonus.has("supply"):
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
	if consumed or not authoritative or not operator or operator.health <= 0.0 or is_queued_for_deletion() or (is_instance_valid(claimant) and operator != claimant):
		return
	if bonus.has("supply") and not operator.collect_supply(String(bonus.supply)):
		return
	consumed = true
	if not materials.is_empty():
		operator.collect_salvage(materials)
	if not blueprint_id.is_empty() and not operator.recovered_blueprints.has(blueprint_id):
		operator.recovered_blueprints[blueprint_id] = true
		operator.blueprint_found.emit(blueprint_id)
	if local_copy:
		RiftAudio.play_effect(&"pickup")
	collected.emit()
	queue_free()
