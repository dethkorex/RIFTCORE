class_name Combatant
extends CharacterBody3D

signal health_changed(current: float, maximum: float)
signal died

const DAMAGE_NUMBER := preload("res://scripts/damage_number.gd")

@export var max_health: float = 100.0
@export_range(1.0, 3.0, 0.1) var fire_weakness := 1.0
var incoming_critical := false
var health: float
var invulnerable_time := 0.0
var burn_left := 0.0
var burn_clock := 0.0
var burn_power := 0.0
var burn_effect: Node3D

func _ready() -> void:
	health = max_health

func take_damage(amount: float, source_position := Vector3.ZERO) -> void:
	if invulnerable_time > 0.0 or health <= 0.0:
		return
	health = maxf(0.0, health - amount)
	show_damage.call_deferred(amount, false, incoming_critical)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		died.emit()

func take_fire_damage(amount: float, source_position := Vector3.ZERO) -> void:
	incoming_critical = fire_weakness > 1.0
	take_damage(amount * fire_weakness, source_position)
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

func ignite(power: float, seconds: float) -> void:
	if health <= 0.0 or seconds <= 0.0:
		return
	burn_left = maxf(seconds, burn_left)
	burn_power = maxf(power, burn_power)
	if not is_instance_valid(burn_effect):
		burn_clock = 0.5
		burn_effect = preload("res://scripts/fire_burn_fx.gd").new()
		add_child.call_deferred(burn_effect)

func _process(delta: float) -> void:
	invulnerable_time = maxf(0.0, invulnerable_time - delta)
	if burn_left <= 0.0 or health <= 0.0:
		return
	burn_left = maxf(0.0, burn_left - delta)
	burn_clock -= delta
	if burn_clock <= 0.001:
		burn_clock += 0.5
		health = maxf(0.0, health - burn_power)
		show_damage.call_deferred(burn_power, true)
		health_changed.emit(health, max_health)
		if health <= 0.0:
			died.emit()
	if burn_left <= 0.0 and is_instance_valid(burn_effect):
		burn_effect.queue_free()
		burn_effect = null
		burn_power = 0.0

