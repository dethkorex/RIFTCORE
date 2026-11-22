class_name SideCameraRig
extends Node3D

@export var damping := 7.0
@export var gameplay_distance := 7.43
@export var look_ahead := 1.25
@export var minimum_follow_y := 0.85
var target: RiftPlayer
var min_x := -18.0
var max_x := 38.0
var warden_framing := 0.0
@onready var camera_view := get_node_or_null("Camera3D") as Camera3D

func _ready() -> void:
	if camera_view:
		camera_view.position.z = gameplay_distance
		camera_view.fov = 80.0
		return
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.position = Vector3(0.0, 0.65, gameplay_distance)
	camera.rotation_degrees.x = -5.0
	camera.current = true
	camera.fov = 80.0
	add_child(camera)
	camera_view = camera

func _process(delta: float) -> void:
	if is_instance_valid(target):
		var boss := get_tree().get_first_node_in_group(&"warden_lava_phase") as Node3D
		var framing := 0.0
		var lead := 0.0
		var frame_height := 7.4
		if boss and boss.get_parent() == target.get_parent() and not boss.exposed:
			var separation: float = boss.warden_perch.global_position.x - target.global_position.x
			framing = 1.0 - smoothstep(14.0, 26.0, absf(separation))
			frame_height = boss.warden_perch.global_position.y * .52
			lead = clampf(separation * .27, -4.9, 4.9) * framing
		var blend := 1.0 - exp(-damping * delta)
		warden_framing = lerpf(warden_framing, framing, blend)
		camera_view.position.z = gameplay_distance + warden_framing * 5.10
		var desired := target_position(true)
		desired.x = clampf(desired.x + lead, min_x, max_x)
		desired.y += maxf(0.0, frame_height - desired.y) * warden_framing
		global_position = global_position.lerp(desired, blend)

func snap_to_target() -> void:
	if is_instance_valid(target):
		global_position = target_position()

func target_position(interpolated := false) -> Vector3:
	var at := target.get_global_transform_interpolated().origin if interpolated else target.global_position
	var lead := 6.6 if is_instance_valid(target.rocket_course) else look_ahead
	return Vector3(clampf(at.x + target.facing * lead, min_x, max_x), maxf(minimum_follow_y, at.y + 0.35), 0.0)

