@tool
@icon("res://addons/arcflux_fx/icons/beam.svg")
class_name ArcfluxLaser3D
extends ArcfluxBeam3D
## Continuous laser. Aims along local -Z (or at target), snaps to the first collision and
## shows a muzzle glow, a flowing body and a sparking impact.
##
## [codeblock]
## $Laser.set_active(Input.is_action_pressed("fire"))
## [/codeblock]


func _class_defaults() -> Dictionary:
	var d: Dictionary = super._class_defaults()
	d.merge({
		&"width": 0.16,
		&"core_ratio": 0.2,
		&"halo_width": 5.0,
		&"body_glow": 0.8,
		&"flow_speed": 18.0,
		&"edge_noise": 0.2,
		&"body_noise": 0.3,
		&"pulse": 0.06,
		&"light_energy": 2.5,
		&"light_range": 4.0,
	}, true)
	return d
