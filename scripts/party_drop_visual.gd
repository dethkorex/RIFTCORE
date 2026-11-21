extends Node3D

const Orb := preload("res://scripts/pickup_orb_visual.gd")
const Profile := preload("res://scripts/rogue_profile.gd")

var tint := Color("75ffd2")

func configure(item: String) -> void:
	var orb = $Orb
	if item.begins_with("blueprint/"):
		tint = Color("2abbff")
		orb.mark = Orb.Mark.BLUEPRINT
	elif Profile.stock[item].has("material"):
		tint = Color("ff7957")
		orb.mark = Orb.Mark.MATERIAL
	else:
		orb.mark = Orb.Mark.SUPPLY
	orb.tint = tint

func _ready() -> void:
	var bob := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property($Orb, "position:y", 0.10, 0.65)
	bob.tween_property($Orb, "position:y", 0.0, 0.65)
