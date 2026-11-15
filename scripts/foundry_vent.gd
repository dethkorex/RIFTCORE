@tool
extends Area3D

const Flame := preload("res://scripts/foundry_flame.gd")
const Nozzle := preload("res://assets/neon_factory/foundry/flame_nozzle.glb")

@export var offset := 0.0
@export var period := 3.4
@export var flame_height := 2.35
@export var damage := 23.0
@export var nozzle_width := 1.62
@export var purge_relay: NodePath
@onready var relief_valve := get_node_or_null(purge_relay) if not purge_relay.is_empty() else null
var phase_time: Callable
var authority := true
var phase := 0.0
var lit := false
var struck := {}
var flame: Node3D

func _ready() -> void:
	var housing := Nozzle.instantiate() as Node3D
	housing.scale = Vector3.ONE * (nozzle_width / 1.3)
	add_child(housing)
	if Engine.is_editor_hint():
		set_physics_process(false)
		return
	add_to_group(&"factory_interior_trap")
	collision_layer = 0
	collision_mask = 1
	var shape := BoxShape3D.new()
	shape.size = Vector3(nozzle_width * 0.87, flame_height - 0.10, nozzle_width * 0.94)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = flame_height * 0.5 + 0.10
	add_child(collider)
	flame = Flame.new()
	flame.height = flame_height
	flame.width = nozzle_width
	add_child(flame)

func _physics_process(delta: float) -> void:
	phase += delta
	var time: float = phase_time.call() if phase_time.is_valid() else phase
	var at := fposmod(time + offset, period)
	if relief_valve and relief_valve.shown_power == 1:
		at = -1.0
	flame.show_phase(at)
	var burning: bool = at >= flame.warning_time and at < flame.warning_time + flame.burst_time - 0.08
	if burning and not lit:
		RiftAudio.foundry_sound(&"fire_jet", global_position)
	lit = burning
	if not burning:
		struck.clear()
		return
	if not authority:
		return
	for body in get_overlapping_bodies():
		if body is RiftPlayer and not struck.has(body.get_instance_id()):
			struck[body.get_instance_id()] = true
			body.take_damage(damage, global_position)
