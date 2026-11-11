extends Node3D

const COMBAT_VFX := preload("res://scripts/combat_vfx.gd")

func ignite(tint := Color("62e7ff")) -> void:
	COMBAT_VFX.explosion(self, tint)
	var flash := OmniLight3D.new()
	flash.light_color = tint
	flash.light_energy = 5.0
	flash.omni_range = 5.0
	add_child(flash)
	create_tween().tween_property(flash, "light_energy", 0.0, 0.36)
	for index in range(18):
		var fragment := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.19, 0.06, 0.06)
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color("fcf6c3") if index % 3 == 0 else tint
		mesh.material = material
		fragment.mesh = mesh
		var angle := TAU * index / 18.0
		fragment.rotation.z = angle
		add_child(fragment)
		var direction := Vector3(cos(angle), sin(angle), 0.0)
		var spread := direction * (0.65 + 0.28 * (index % 5))
		var burst := create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		burst.tween_property(fragment, "position", spread, 0.4)
		burst.tween_property(fragment, "scale", Vector3.ONE * 0.03, 0.4)
