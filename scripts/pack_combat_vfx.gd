extends RefCounted

const Trail := preload("res://addons/edgeflux_fx/nodes_3d/edgeflux_weapon_trail_3d.gd")
const SaberHit := preload("res://addons/edgeflux_fx/nodes_3d/edgeflux_hit_3d.gd")
const MetalHit := preload("res://addons/muzzlux_fx/presets/3d/impact_metal.tscn")
const Wave := preload("res://addons/blastlux_fx/nodes_3d/blastlux_shockwave_3d.gd")
const IceHit := preload("res://addons/glacilux_fx/nodes_3d/glacilux_impact_3d.gd")
const Laser := preload("res://addons/arcflux_fx/nodes_3d/arcflux_laser_3d.gd")

static func blade_trail(blade: Node3D, duration: float, tint: Color, finisher: bool) -> void:
	var trail := Trail.new()
	trail.name = "SaberRibbon"
	trail.base_offset = Vector3(0.08, 0, 0)
	trail.tip_offset = Vector3(1.62, 0, 0)
	trail.lifetime = 0.16 if finisher else 0.12
	trail.intensity = 1.35 if finisher else 1.05
	trail.palette = saber_palette(tint)
	trail.light_enabled = false
	trail.emitting = false
	blade.add_child(trail)
	trail.burst(duration)
	blade.get_tree().create_timer(duration + trail.lifetime, false).timeout.connect(trail.queue_free)

static func saber_hit(parent: Node3D, at: Vector3, facing: float, tint: Color) -> void:
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var sparks := SaberHit.new()
	sparks.autoplay = false
	sparks.free_when_finished = true
	sparks.palette = saber_palette(tint)
	sparks.light_enabled = false
	parent.add_child(sparks)
	sparks.hit(at, Vector3(-facing, 0.2, 0.65))

static func saber_palette(tint: Color) -> EdgefluxPalette:
	var palette := EdgefluxPalette.new()
	palette.core_color = tint.lerp(Color.WHITE, 0.53)
	palette.glow_color = tint
	return palette

static func projectile_hit(parent: Node3D, direction: Vector3, tint: Color, charged: bool, weapon: String) -> void:
	if weapon == "frost_lance":
		var ice := IceHit.new()
		ice.name = "FrostLanceShatter"
		ice.autoplay = false
		ice.radius = 0.82 if charged else 0.46
		ice.shards = 26 if charged else 13
		ice.shard_lifetime = 0.48
		ice.crown = 0
		ice.mist = 0
		ice.sparkles = 5
		ice.spread_time = 0.18
		ice.hold_time = 0.08
		ice.frost = false
		ice.ground_from_raycast = false
		parent.add_child(ice)
		ice.burst_at(parent.global_position, Vector3.UP)
	else:
		var sparks := MetalHit.instantiate() as MuzzluxImpact3D
		sparks.name = "MetalImpact"
		sparks.autoplay = false
		sparks.size = 0.78 if charged else 0.51
		sparks.spark_count = 12 if charged else 7
		sparks.debris_count = 3
		sparks.dust_count = 0
		parent.add_child(sparks)
		sparks.burst(parent.global_position, (-direction + Vector3.BACK * 0.5).normalized(), &"metal")
	if charged:
		var wave := Wave.new()
		wave.name = "ChargeShockwave"
		var palette := BlastluxPalette.new()
		palette.hot = tint
		palette.core = tint.lerp(Color.WHITE, 0.45)
		wave.palette = palette
		wave.radius = 1.62
		wave.wave_speed = 7.8
		wave.thickness = 0.12
		wave.ripple = false
		wave.dust = false
		wave.disc = false
		wave.ground_from_raycast = false
		wave.rotation_degrees.x = 63
		parent.add_child(wave)

static func orbital_beam(parent: Node3D, radius: float, height: float, tint: Color, duration: float) -> void:
	var beam := Laser.new()
	beam.name = "OrbitalLaser"
	beam.position = Vector3(0, height, 0)
	beam.rotation.x = -PI * 0.5
	beam.max_length = height * 2.0
	beam.width = radius * 1.24
	beam.halo_width = 1.56
	beam.ramp_time = minf(0.10, duration * 0.2)
	beam.collide = false
	beam.impact_in_air = true
	beam.light_enabled = false
	var palette := ArcfluxPalette.new()
	palette.core_color = tint.lerp(Color.WHITE, 0.71)
	palette.glow_color = tint
	beam.palette = palette
	parent.add_child(beam)


static func explosion(parent: Node3D, tint: Color, radius: float) -> void:
	var blast := preload("res://addons/pyrolux_fx/nodes_3d/pyrolux_explosion_3d.gd").new()
	blast.name = "PyroluxBurst"
	blast.style = PyroluxExplosion3D.Style.AIR
	blast.radius = radius
	blast.fireball = 20
	blast.sparks = 22
	blast.smoke = 12
	blast.debris = 6
	blast.smoke_time = 0.6
	blast.smoke_opacity = 0.5
	blast.scorch = false
	blast.dust = false
	blast.shockwave = false
	blast.time_scale = 2.2
	blast.light_enabled = false
	blast.free_when_done = true
	var palette := PyroluxPalette.new()
	palette.core = tint.lerp(Color.WHITE, 0.72)
	palette.hot = tint
	palette.cool = tint.darkened(0.42)
	palette.smoke = Color("334051")
	blast.palette = palette
	parent.add_child(blast)
