extends Node3D

const COMBAT_VFX := preload("res://scripts/combat_vfx.gd")

func ignite(tint := Color("62e7ff")) -> void:
	light(self, tint)

static func spawn(parent: Node3D, at: Vector3, tint: Color, lifetime: float) -> void:
	if not is_instance_valid(parent) or not parent.is_inside_tree() or parent.is_queued_for_deletion():
		return
	var effect := Node3D.new()
	parent.add_child(effect)
	effect.global_position = at
	light(effect, tint)
	effect.get_tree().create_timer(lifetime, false).timeout.connect(effect.queue_free)

static func light(effect: Node3D, tint: Color) -> void:
	COMBAT_VFX.explosion(effect, tint)
	var flash := OmniLight3D.new()
	flash.light_color = tint
	flash.light_energy = 5.0
	flash.omni_range = 5.0
	effect.add_child(flash)
	effect.create_tween().tween_property(flash, "light_energy", 0.0, 0.36)
