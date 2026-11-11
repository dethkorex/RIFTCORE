extends Node3D

const EMBER := Color("ff5420")
const HOT := Color("ffd391")
const PINK := Color("ff3cbd")

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

static func make_laser() -> Node3D:
	var root := Node3D.new()
	for config in [[0.11, PINK, 0.75], [0.036, HOT, 2.35]]:
		var beam := CylinderMesh.new()
		beam.top_radius = config[0]
		beam.bottom_radius = config[0]
		beam.height = 2.40
		beam.radial_segments = 12
		RiftProjectile.part(root, beam, RiftProjectile.light_paint(config[1], config[2]), Vector3(0, 1.2, 0), Vector3.ONE)

	for y in [0.12, 1.2, 2.28]:
		var rim := RiftProjectile.add_glow(root, PINK, 1.04)
		rim.position = Vector3(0.0, y, 0.16)
	return root

static func throw_sparks(host: Node3D, tint: Color, power: float) -> void:
	var sparks := Node3D.new()
	host.add_child(sparks)
	var decay := sparks.create_tween().set_parallel()
	for i in range(7):
		var angle := float(i) / 7.0 * TAU
		var spark := RiftProjectile.part(sparks, RiftProjectile.cached_mesh("Orb"), RiftProjectile.light_paint(tint, 1.75), Vector3(0, 0.065, 0.08), Vector3(0.027, 0.074, 0.025) * power)
		var end := Vector3(cos(angle) * 0.77, 0.21 + sin(angle + 1.2) * 0.31, sin(angle) * 0.34) * power
		decay.tween_property(spark, "position", end, 0.23).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		decay.tween_property(spark, "scale", Vector3.ONE * 0.008, 0.24)
	decay.chain().tween_callback(sparks.queue_free)
