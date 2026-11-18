extends RefCounted

const PACK_VFX := preload("res://scripts/pack_combat_vfx.gd")

const VFX := preload("res://scripts/combat_vfx.gd")
const PALETTES := ["ff6639", "9cf765", "8cecff", "42fff1", "ffbc61", "a6eeff", "e9ff43", "db9dff", "ff954f", "ff70ef"]
static var materials := {}
static var cube := BoxMesh.new()
static var crystal := PrismMesh.new()
static var bulb := SphereMesh.new()

static func tint_for(sector: int) -> Color:
	return Color(PALETTES[clampi(sector - 1, 0, PALETTES.size() - 1)])

static func paint(tint: Color) -> StandardMaterial3D:
	if not materials.has(tint):
		var surface := StandardMaterial3D.new()
		surface.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		surface.albedo_color = tint
		surface.emission_enabled = true
		surface.emission = tint
		surface.emission_energy_multiplier = 0.8
		materials[tint] = surface
	return materials[tint]

static func piece(parent: Node3D, mesh: Mesh, at: Vector3, dimensions: Vector3, tint: Color) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = paint(tint)
	part.position = at
	part.scale = dimensions
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(part)
	return part

static func projectile(parent: Node3D, sector: int, role: int, heavy: bool, tint_override := Color.TRANSPARENT) -> void:
	var tint := tint_override if tint_override.a > 0.0 else tint_for(sector)
	var size := 1.45 if heavy else 1.0
	var edge := tint.lerp(Color.WHITE, 0.72)
	match sector:
		3:
			for i in range(3):
				var shard := piece(parent, crystal, Vector3(0, 0, 0.07 - 0.21 * i), Vector3(0.17, 0.54, 0.15) * size, edge if i == 0 else tint)
				shard.rotation = Vector3(PI / 2.0, 0, i * 2.1)
		4, 9:
			var start := Vector3(0, 0, 0.24)
			for i in range(1, 7):
				var end := Vector3(0.1 * (-1 if i % 2 else 1), 0.06 * sin(i * 1.8), 0.24 - i * 0.13) * size
				var segment := piece(parent, cube, (start + end) * 0.5, Vector3(0.045, 0.045, start.distance_to(end)), edge if i % 2 else tint)
				segment.basis = Basis.looking_at((end - start).normalized(), Vector3.UP).scaled_local(segment.scale)
				start = end
		2:
			if role == 3:
				var thorn := piece(parent, crystal, Vector3(0, 0, .14), Vector3(.21, .64, .20) * size, tint)
				thorn.rotation.x = PI * .5
				piece(parent, bulb, Vector3(0, 0, -.18), Vector3(.15, .14, .44) * size, edge)
			elif role == 4:
				piece(parent, bulb, Vector3(0, 0, .11), Vector3(.38, .38, .55) * size, tint)
				piece(parent, bulb, Vector3(0, 0, .21), Vector3(.23, .23, .48) * size, edge)
				for index in 3:
					var angle := float(index) * TAU / 3.0
					piece(parent, bulb, Vector3(sin(angle) * .18, cos(angle) * .18, -.30 - index * .10), Vector3(.16, .16, .28) * size, tint.darkened(.21))
			else:
				draw_spores(parent, size, tint, edge)
		5, 7:
			draw_spores(parent, size, tint, edge)
		_:
			piece(parent, bulb, Vector3.ZERO, Vector3(0.17, 0.17, 0.67) * size, tint)
			piece(parent, bulb, Vector3(0, 0, 0.16), Vector3(0.105, 0.105, 0.38) * size, edge)
			for side in [-1.0, 1.0]:
				var fin := piece(parent, crystal, Vector3(side * 0.1, 0, -0.18), Vector3(0.11, 0.37, 0.055) * size, tint)
				fin.rotation.x = PI / 2.0
	var length := (0.48 + 0.1 * role) * size
	piece(parent, bulb, Vector3(0, 0, -0.34), Vector3(0.068, 0.068, length), tint.darkened(0.17))

static func draw_spores(parent: Node3D, size: float, tint: Color, edge: Color) -> void:
	piece(parent, bulb, Vector3(0, 0, 0.13), Vector3(0.24, 0.24, 0.38) * size, tint)
	for i in 3:
		piece(parent, bulb, Vector3(0.07 * sin(i * 2.5), 0.07 * cos(i * 2.5), -0.17 - 0.15 * i), Vector3.ONE * (0.15 - 0.03 * i) * size, edge)

static func charged_saber(parent: Node3D, tint: Color) -> void:
	var surface := ImmediateMesh.new()
	var material := paint(tint).duplicate() as StandardMaterial3D
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color.WHITE
	material.emission_energy_multiplier = .50
	surface.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, material)
	for i in range(25):
		var t := float(i) / 24.0
		var arc := sin(t * PI)
		var height := (t - .5) * 2.23
		var forward := -.65 + .94 * arc
		surface.surface_set_color(tint.lerp(Color.WHITE, .76))
		surface.surface_add_vertex(Vector3(height * .22, height, forward))
		surface.surface_set_color(tint.darkened(.28))
		surface.surface_add_vertex(Vector3(height * .22, height, forward - arc * .65))
	surface.surface_end()
	var slash := MeshInstance3D.new()
	slash.mesh = surface
	slash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(slash)

static func muzzle(parent: Node3D, at: Vector3, tint: Color, strength := 0.8) -> void:
	var flash := Node3D.new()
	parent.add_child(flash)
	flash.global_position = at
	VFX.hit(flash, tint, strength)
	flash.get_tree().create_timer(0.24, false).timeout.connect(flash.queue_free)

static func charge(parent: Node3D, at: Vector3, tint: Color, duration: float) -> void:
	var warning := Node3D.new()
	parent.add_child(warning)
	warning.global_position = at
	var ring := VFX.sprite(warning, VFX.RING, Vector3.ZERO, 0.92, Color(tint, 0.78))
	var core := VFX.sprite(warning, VFX.FLASH, Vector3(0, 0, 0.04), 0.32, Color(tint.lerp(Color.WHITE, 0.48), 0.9))
	var build := warning.create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	build.tween_property(ring, "scale", Vector3.ONE * 0.24, duration)
	build.tween_property(core, "scale", Vector3.ONE * 2.15, duration)
	build.chain().tween_callback(warning.queue_free)

static func telegraph(parent: Node3D, width: float, tint: Color, duration: float) -> void:
	var count := clampi(ceili(width / 1.8), 1, 18)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.39
	ring.outer_radius = 0.49
	ring.rings = 12
	ring.ring_segments = 5
	var pulse := parent.create_tween().set_parallel()
	for index in count:
		var x := width * ((index + 0.5) / count - 0.5)
		var footprint := clampf(width / count * 0.86, 0.44, 1.68)
		var beacon := piece(parent, ring, Vector3(x, 0.042, 0), Vector3(footprint, 0.23, 0.94), tint)
		beacon.transparency = 0.48
		pulse.tween_property(beacon, "transparency", 0.0, maxf(duration, 0.12)).set_trans(Tween.TRANS_CUBIC)
		for side in [-1, 1]:
			var spark := piece(parent, crystal, Vector3(x, 0.125, side * 0.52),
				Vector3(0.105, 0.18, 0.085), tint.lerp(Color.WHITE, 0.4))
			spark.rotation.z = side * 0.26
			pulse.tween_property(spark, "position:y", 0.37, maxf(duration, 0.12))

static func field(parent: Node3D, sector: int, radius: float, height: float, duration: float, move: String) -> void:
	var tint := tint_for(sector)
	if move == "orbital_beam":
		PACK_VFX.orbital_beam(parent, radius, height, tint, duration)
		return
	var span := radius * 2.0
	var tween := parent.create_tween().set_parallel()
	if move == "flood":
		for band in range(3):
			var current := piece(parent, cube, Vector3(0, -height * 0.49 + band * 0.34, 0.28 - band * 0.10),
				Vector3(span, 0.055, 0.24), tint.lerp(Color.WHITE, 0.13 * band))
			tween.tween_property(current, "position:y", height * 0.43 + band * 0.24, minf(duration, 0.67 + band * 0.12))
	elif move in ["sandstorm", "tornado", "well", "gravity", "magnet", "gust"]:
		for index in range(4):
			var eddy := VFX.sprite(parent, VFX.RING, Vector3(0, -height * 0.24 + index * 0.38, 0.21), minf(span, height) * (0.65 + index * 0.20), Color(tint, 0.50))
			eddy.scale.y = 0.44
			eddy.rotation.z = (index - 1.5) * 0.20
			tween.tween_property(eddy, "rotation:z", eddy.rotation.z + 2.3 * (-1 if index % 2 else 1), duration)
			tween.tween_property(eddy, "modulate:a", 0.06, duration)
	if height <= 0.3:
		var beam := piece(parent, cube, Vector3.ZERO, Vector3(span, maxf(height * 1.8, 0.11), 0.21), tint)
		piece(parent, cube, Vector3(0, 0, 0.13), Vector3(span * 0.99, maxf(height * 1.55, 0.06), 0.10), tint.lerp(Color.WHITE, 0.8))
		tween.tween_property(beam, "scale:z", 0.04, duration)
		return
	var count := clampi(ceili(span / 0.85), 3, 24)

	for i in range(count):
		var x := span * ((i + 0.5) / count - 0.5)
		var size := minf(height, 2.65) * (0.45 + 0.11 * (i % 5))
		var shape: Mesh = crystal if sector in [2, 3, 7, 9, 10] else bulb
		var streak := piece(parent, shape, Vector3(x, -height * 0.32, 0.05 * (i % 3)),
			Vector3(minf(0.38, span / count * 0.84), size, 0.26), tint.lerp(Color.WHITE, (i % 3) * 0.25))
		streak.rotation.z = (i % 3 - 1) * 0.24
		tween.tween_property(streak, "position:y", height * 0.35, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(streak, "scale:x", 0.03, duration)
