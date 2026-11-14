extends StaticBody3D

@export var platform_path: NodePath
@export var travel := Vector3(0, -3, 0)
@export var operation := "BRIDGE"
@export var lift := false
@export var repeat_hold := 4.5
@onready var platform := get_node(platform_path) as AnimatableBody3D
@onready var lamp: MeshInstance3D = $Lamp
@onready var signpost: Label3D = $Status
var triggered := false
var running := false
var red := Color("ff5d43")
var green := Color("63ffb0")
var shown_power := -1

func _ready() -> void:
	set_meta("parked", platform.position)
	show_state(false)

func hit_by_projectile(shot: RiftProjectile) -> bool:
	if not is_instance_valid(platform) or shot.owner_faction != "player":
		return false
	if running or triggered and not lift:
		return true
	triggered = true
	running = true
	var resting := platform.position
	var motion := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
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
	lamp.material_override = RiftProjectile.light_paint(green if powered else red, 2.25)
	signpost.modulate = green if powered else red
	signpost.text = operation + ("  /  ACTIVE" if powered else "  /  SHOOT TARGET")

func reflect_motion() -> void:
	show_state(not platform.position.is_equal_approx(get_meta("parked", platform.position)))


func restore_bridge() -> void:
	if not lift and not triggered:
		triggered = true
		platform.position += travel
		show_state(true)
