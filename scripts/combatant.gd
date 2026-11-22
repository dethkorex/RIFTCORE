class_name Combatant
extends CharacterBody3D

# Boss art is mounted with its nose on local +Z. Combat takes place on world X.
const BOSS_SIDE_YAW := PI * 0.5

signal health_changed(current: float, maximum: float)
signal enemy_damaged(fatal: bool)
signal died

const EnemyDamageFlash := preload("res://scripts/enemy_damage_flash.gd")
const DAMAGE_NUMBER := preload("res://scripts/damage_number.gd")
const BOSS_DIFFICULTY := preload("res://scripts/mission_difficulty.gd")

@export var max_health: float = 100.0
@export_range(1.0, 3.0, 0.1) var fire_weakness := 1.0
@export var weakness_weapon := ""
@export var weapon_weakness := 1.45
var incoming_critical := false
var damage_operator_id := 0
var defeated_by_operator_id := 0
var health: float
var encounter_attack_scale := 1.0
var invulnerable_time := 0.0
var burn_left := 0.0
var corrosion_left := 0.0
var burn_clock := 0.0
var burn_power := 0.0
var burn_effect: Node3D
var burn_source := 0
var damage_flash: EnemyDamageFlash

func _ready() -> void:
	health = max_health

func apply_boss_scaling(sector: int, mode: int, act: int, party_size := 1) -> void:
	if has_method("configure_difficulty"):
		call("configure_difficulty", mode)
	max_health = BOSS_DIFFICULTY.boss_health(sector, mode, act, party_size)
	encounter_attack_scale = BOSS_DIFFICULTY.MINIBOSS_ATTACK_SCALE if act == 1 else BOSS_DIFFICULTY.BOSS_ATTACK_SCALE
	health = max_health

func take_damage(amount: float, source_position := Vector3.ZERO) -> void:
	if invulnerable_time > 0.0 or health <= 0.0:
		return
	lose_health(amount, false, incoming_critical)

func damage_model() -> Node3D:
	return null

func present_enemy_hit(fatal: bool) -> void:
	var model := damage_model()
	if not is_instance_valid(model):
		return
	RiftAudio.enemy_damage(global_position)
	if not damage_flash:
		damage_flash = EnemyDamageFlash.new(model)
	damage_flash.pulse(model, fatal)

func lose_health(amount: float, burning: bool, critical: bool) -> void:
	var previous := health
	health = maxf(0.0, health - amount)
	if health < previous and is_instance_valid(damage_model()):
		var fatal := health <= 0.0
		present_enemy_hit(fatal)
		enemy_damaged.emit(fatal)
	show_damage.call_deferred(amount, burning, critical)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		defeated_by_operator_id = burn_source if burning else damage_operator_id
		died.emit()

func take_operator_damage(amount: float, at: Vector3, operator_id: int) -> void:
	damage_operator_id = operator_id
	take_damage(amount, at)
	damage_operator_id = 0

func take_fire_damage(amount: float, source_position := Vector3.ZERO) -> void:
	incoming_critical = fire_weakness > 1.0
	take_damage(amount * fire_weakness, source_position)
	incoming_critical = false

func take_element_damage(amount: float, source_position: Vector3, weapon_id: String) -> void:
	incoming_critical = not weapon_id.is_empty() and weapon_id == weakness_weapon
	take_damage(amount * (weapon_weakness if incoming_critical else 1.0), source_position)
	incoming_critical = false

func show_damage(amount: float, burning := false, critical := false) -> void:
	var scene := get_tree().current_scene
	if not scene or amount <= 0.0:
		return
	var counter := DAMAGE_NUMBER.new()
	scene.add_child(counter)
	var hurt_player: bool = get("faction") == "player"
	var offset := 1.1 if hurt_player else (1.7 if max_health >= 1000 else 1.03)
	counter.global_position = global_position + Vector3(randf_range(-0.08, 0.08), offset, 0.27)
	counter.animate(amount, hurt_player, burning, critical)

func ignite(power: float, seconds: float, source := 0) -> void:
	if health <= 0.0 or seconds <= 0.0:
		return
	burn_source = source
	burn_left = maxf(seconds, burn_left)
	burn_power = maxf(power, burn_power)
	if not is_instance_valid(burn_effect):
		burn_clock = 0.5
		burn_effect = preload("res://scripts/fire_burn_fx.gd").new()
		add_child.call_deferred(burn_effect)

func detonate_ally_burn(attacker: int) -> float:
	if burn_left <= 0.0 or burn_source == 0 or attacker == 0 or attacker == burn_source:
		return 0.0
	var burst := burn_power * 3.0
	burn_left = 0.0
	burn_power = 0.0
	burn_source = 0
	if is_instance_valid(burn_effect):
		burn_effect.queue_free()
		burn_effect = null
	return burst

func _process(delta: float) -> void:
	invulnerable_time = maxf(0.0, invulnerable_time - delta)
	corrosion_left = maxf(0.0, corrosion_left - delta)
	if burn_left <= 0.0 or health <= 0.0:
		return
	burn_left = maxf(0.0, burn_left - delta)
	burn_clock -= delta
	if burn_clock <= 0.001:
		burn_clock += 0.5
		apply_burn_tick()
	if burn_left <= 0.0 and is_instance_valid(burn_effect):
		burn_effect.queue_free()
		burn_effect = null
		burn_power = 0.0


func apply_burn_tick() -> void:
	lose_health(burn_power, true, false)


func ignore_arena_access_decks() -> void:
	# Arena decks carry the operators, while the boss keeps its lane and floor collision.
	for deck in get_tree().get_nodes_in_group(&"arena_player_deck"):
		if deck is PhysicsBody3D:
			add_collision_exception_with(deck)
		for body in deck.find_children("*", "PhysicsBody3D", true, false):
			add_collision_exception_with(body)

func arena_supply_anchor(index: int) -> Node3D:
	var stage := get_parent().get_parent()
	var arena := stage.get_node_or_null("TERRAIN/BossWing")
	if arena:
		for platform: Node3D in arena.get_children():
			if int(platform.get_meta(&"boss_supply_anchor", -1)) == index:
				return platform
	return null
