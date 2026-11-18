extends Node3D

const IMPACT := preload("res://addons/muzzlux_fx/presets/3d/impact_metal.tscn")

const EMBER := Color("ff5420")

static func make_spikes(factor := 1.0) -> Node3D:
	var root := Node3D.new()
	var mount := Node3D.new()
	mount.position.y = 0.43 * factor
	mount.rotation.x = -PI * 0.5
	root.add_child(mount)
	var rotor := RiftProjectile.drill_visual(mount, EMBER, factor)
	rotor.name = "DrillRotor"
	var collar := RiftProjectile.part(root, RiftProjectile.cached_mesh("Ring"), RiftProjectile.light_paint(EMBER, 1.35), Vector3(0, 0.035, 0), Vector3(factor, 0.65, factor))
	collar.scale.x *= 1.20
	return root

static func impact(host: Node3D, power: float, surface: StringName = &"metal") -> void:
	var burst := IMPACT.instantiate() as MuzzluxImpact3D
	burst.autoplay = false
	burst.free_when_done = true
	burst.max_concurrent = 1
	burst.size = clampf(power * 0.8, 0.38, 2.2)
	burst.light_enabled = power > 1.5
	burst.light_energy = 1.4
	burst.light_range = 3.2
	burst.bloom = false
	burst.debris_count = 6
	burst.dust_count = 3
	burst.spark_count = 14 if power > 1.0 else 8
	host.add_child(burst)
	burst.burst(host.global_position + Vector3(0.0, 0.065, 0.08),
		Vector3(0.0, 0.82, 0.57), surface, clampf(power, 0.65, 1.6))
