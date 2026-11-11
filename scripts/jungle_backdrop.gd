@tool
extends Node3D

var skyline: MeshInstance3D

func _ready() -> void:
	var texture := load("res://assets/machine_jungle/jungle_panorama.png") as Texture2D
	if not texture:
		return
	skyline = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(245, 160)
	var effect := ShaderMaterial.new()
	effect.shader = preload("res://assets/neon_factory/factory_panorama.gdshader")
	effect.set_shader_parameter("skyline", texture)
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
