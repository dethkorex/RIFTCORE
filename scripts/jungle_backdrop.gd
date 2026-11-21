@tool
extends Node3D

var skyline: MeshInstance3D
@export_range(0.0, 1.0) var vertical_parallax := 0.0
@export var panorama_texture: Texture2D
@export var shadow_tint := Vector3(0.016, 0.036, 0.093)
@export var panorama_filter := Vector3(0.66, 0.74, 0.84)

func _ready() -> void:
	var texture := panorama_texture if panorama_texture else load("res://assets/machine_jungle/jungle_panorama.png") as Texture2D
	if not texture:
		return
	skyline = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(245, 160)
	var effect := ShaderMaterial.new()
	effect.shader = preload("res://assets/neon_factory/factory_panorama.gdshader")
	effect.set_shader_parameter("skyline", texture)
	effect.set_shader_parameter("shadow_tint", shadow_tint)
	effect.set_shader_parameter("panorama_filter", panorama_filter)
	skyline.mesh = quad
	skyline.material_override = effect
	skyline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	skyline.position = Vector3(0, 14, -34)
	add_child(skyline)

func _process(_delta: float) -> void:
	if not is_instance_valid(skyline):
		return
	var camera := get_viewport().get_camera_3d()
	if camera:
		skyline.global_position.x = camera.global_position.x
		skyline.global_position.y = global_position.y + 14.0 + maxf(camera.global_position.y - 5.0, 0.0) * vertical_parallax
