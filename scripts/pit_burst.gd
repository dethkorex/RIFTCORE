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
