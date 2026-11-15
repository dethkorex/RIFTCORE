extends StaticBody3D

@export var platform_path: NodePath
@export var travel := Vector3(0, -3, 0)
@export var operation := "BRIDGE"
@export var lift := false
@export var repeat_hold := 4.5
@export var departure_delay := 0.0
@export var floating := false
@export var heat_key := false
@onready var platform := get_node_or_null(platform_path) as AnimatableBody3D
@onready var lamp: MeshInstance3D = $Lamp
var triggered := false
var running := false
var red := Color("ff5d43")
var green := Color("63ffb0")
var shown_power := -1
var floating_clock := 0.0

func _process(delta: float) -> void:
	if not floating:
		return
	floating_clock += delta
	$Art.position.y = sin(floating_clock * 2.8) * 0.077
	$Art.rotation.y = floating_clock * 0.72
	lamp.position.y = $Art.position.y

func _ready() -> void:
	if not is_instance_valid(platform):
		push_warning("Missing relay platform at %s." % get_path())
		return
	show_state(false)

func hit_by_projectile(shot: RiftProjectile) -> bool:
	if not is_instance_valid(platform) or shot.owner_faction != "player":
		return false
	if heat_key and not shot.is_magma and shot.launch_profile != -2:
		return true
	if running or triggered and not lift:
		return true
	triggered = true
	running = true
	var resting := platform.position
	var motion := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	if departure_delay > 0.0:
		motion.tween_interval(departure_delay)
	motion.tween_property(platform, "position", resting + travel, 1.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	if lift:
		motion.tween_interval(repeat_hold)
		motion.tween_property(platform, "position", resting, 1.25).from(resting + travel).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	motion.tween_callback(func():
		running = false
		show_state(not lift)
	)
	RiftAudio.play_effect(&"checkpoint")
	show_state(true)
	return true

func show_state(powered: bool) -> void:
	if shown_power == int(powered):
		return
	shown_power = int(powered)
	lamp.material_override = RiftProjectile.light_paint(green if powered else red, 1.30 if powered else 0.63)

func restore_bridge() -> void:
	if is_instance_valid(platform) and not lift and not triggered:
		triggered = true
		platform.position += travel
		show_state(true)
