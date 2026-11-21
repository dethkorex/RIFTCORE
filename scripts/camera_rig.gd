class_name SideCameraRig
extends Node3D

@export var damping := 7.0
@export var gameplay_distance := 7.43
@export var look_ahead := 1.25
@export var minimum_follow_y := 0.85
var target: RiftPlayer
var min_x := -18.0
var max_x := 38.0

func _ready() -> void:
	var scene_camera := get_node_or_null("Camera3D") as Camera3D
	if scene_camera:
		scene_camera.position.z = gameplay_distance
		scene_camera.fov = 80.0
		return
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.position = Vector3(0.0, 0.65, gameplay_distance)
	camera.rotation_degrees.x = -5.0
	camera.current = true
	camera.fov = 80.0
	add_child(camera)

func _process(delta: float) -> void:
	if is_instance_valid(target):
		global_position = global_position.lerp(target_position(true), 1.0 - exp(-damping * delta))

func snap_to_target() -> void:
	if is_instance_valid(target):
		global_position = target_position()

func target_position(interpolated := false) -> Vector3:
	var at := target.get_global_transform_interpolated().origin if interpolated else target.global_position
	var lead := 6.6 if is_instance_valid(target.rocket_course) else look_ahead
	return Vector3(clampf(at.x + target.facing * lead, min_x, max_x), maxf(minimum_follow_y, at.y + 0.35), 0.0)

