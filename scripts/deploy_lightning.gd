extends Node3D

const Bolt := preload("res://addons/arcflux_fx/nodes_3d/arcflux_bolt_3d.gd")
const CYAN := Color("42dfff")

func strike() -> void:
	var bolt := Bolt.new()
	bolt.autoplay = false
	bolt.width = 0.10
	bolt.halo_width = 4.2
	bolt.branches = 3.0
	bolt.branch_depth = 1
	bolt.restrikes = 1
	bolt.flicker_time = 0.16
	bolt.afterglow = 0.17
	bolt.source_flare = false
	bolt.impact_flare_size = 1.5
	bolt.impact_sparks = 12
	bolt.light_range = 4.3
	var palette := ArcfluxPalette.new()
	palette.glow_color = CYAN
	palette.core_color = Color("d6f7ff")
	bolt.palette = palette
	add_child(bolt)
	bolt.strike(to_global(Vector3(-0.5, 6.0, 0.06)), to_global(Vector3(0, 0.09, 0.12)))
	get_tree().create_timer(bolt.total_time() + 0.10, false).timeout.connect(queue_free)
