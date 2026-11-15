extends StaticBody3D

@export var platform_path: NodePath
@export var travel := Vector3(0, -3, 0)
@export var operation := "BRIDGE"
@export var lift := false
@export var repeat_hold := 4.5
@export var departure_delay := 0.0
@export var floating := false
@export var heat_key := false
@export var pressure_plate := false
@onready var platform := get_node_or_null(platform_path) as AnimatableBody3D
@onready var lamp: MeshInstance3D = $Lamp
var triggered := false
var running := false
var red := Color("ff5d43")
var green := Color("63ffb0")
var shown_power := -1
var floating_clock := 0.0
var authority := true
var plate_trigger: Area3D

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
	if pressure_plate:
		plate_trigger = Area3D.new()
		plate_trigger.collision_layer = 0
		plate_trigger.collision_mask = 1
		var trigger_shape := CollisionShape3D.new()
		var volume := BoxShape3D.new()
		volume.size = Vector3(1.45, 0.48, 2.1)
		trigger_shape.shape = volume
		plate_trigger.add_child(trigger_shape)
		add_child(plate_trigger)

func _physics_process(_delta: float) -> void:
	if authority and is_instance_valid(plate_trigger) and not triggered:
		for body in plate_trigger.get_overlapping_bodies():
			if body is RiftPlayer and body.health > 0.0 and body.is_on_floor():
				activate()
				break

func hit_by_projectile(shot: RiftProjectile) -> bool:
	if pressure_plate or not authority or not is_instance_valid(platform) or shot.owner_faction != "player":
		return false
	if heat_key and not shot.is_magma and shot.launch_profile != -2:
		return true
	activate()
	return true

func activate() -> void:
	if running or triggered and not lift:
		return
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
