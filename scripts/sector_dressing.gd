@tool
extends Node3D

const SURFACE := preload("res://assets/campaign/sector_surface.gdshader")
const CHAMFER := preload("res://scripts/factory_chamfer.gd")
const ORGANIC := [2, 3, 5, 10]
const PALETTES := [
	["382b24", "c28345", "ff6d20"], ["333020", "526c38", "b2d75c"],
	["234559", "70b6d7", "81cadd"], ["203744", "4b8790", "66cbbb"],
	["4a352b", "ae8555", "edb95c"], ["283a4e", "708ea8", "89d7ed"],
	["373345", "767898", "c1a1f4"], ["25263e", "686687", "8c9ff9"],
	["39302b", "946247", "f3ad78"], ["281e34", "8a509c", "e385ec"]
]

@export_range(1, 10) var sector := 1
@export var albedo: Texture2D
@export var left_edge := 0.0
@export var right_edge := 12.0
@export var cave_floor := -1.0
@export var cave_roof := 12.0
@export var arena := false

var rng := RandomNumberGenerator.new()
var stone: ShaderMaterial
var base: StandardMaterial3D
var trim: StandardMaterial3D
var glow: StandardMaterial3D
var foliage: StandardMaterial3D
var leaves := SurfaceTool.new()
var leaf_count := 0
var dressing := false
var details: Array[MeshInstance3D] = []

func _ready() -> void:
	if albedo == null or right_edge <= left_edge or cave_roof <= cave_floor:
		return
	rng.seed = hash(Vector4(left_edge, right_edge, cave_floor, sector))
	var palette: Array = PALETTES[sector - 1]
	base = finish(Color(palette[0]), 0.28)
	trim = finish(Color(palette[1]), 0.36)
	glow = finish(Color(palette[2]), 0.21, 0.75)
	foliage = finish(Color.WHITE, 0.0, 0.06)
	foliage.vertex_color_use_as_albedo = true
	foliage.cull_mode = BaseMaterial3D.CULL_DISABLED
	stone = ShaderMaterial.new()
	stone.shader = SURFACE
	stone.set_shader_parameter("terrain_albedo", albedo)
	stone.set_shader_parameter("texture_scale", 0.175 if sector in ORGANIC else 0.21)
	stone.set_shader_parameter("metal", 0.0 if sector in ORGANIC else 0.12)
	stone.set_shader_parameter("brightness", 0.47 if sector in [2, 3] else 0.53)
	stone.set_shader_parameter("roughness", 0.48 if sector == 3 else 0.83)
	stone.set_shader_parameter("reflected_light", 0.25 if sector in [2, 3] else 0.19)
	if sector == 3:
		stone.set_shader_parameter("surface_tint", Color("91b3c9"))
	elif sector == 2:
		stone.set_shader_parameter("surface_tint", Color("c3bb98"))
	elif sector == 7:
		stone.set_shader_parameter("surface_tint", Color("9d91ae"))
	build_wall()
	if sector == 2:
		leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	dressing = true
	var bay := 12.0 if arena else (9.0 if sector in [2, 3] else 15.0)
	var rows := maxi(1, ceili((cave_roof - cave_floor) / 8.5))
	for row in rows:
		var y := minf(cave_roof - 0.8, cave_floor + 5.8 + 8.5 * row)
		var x := left_edge + 2.2 + rng.randf_range(0.0, 2.5)
		while x < right_edge - 1.75:
			decorate_bay(x, y, row)
			x += bay * rng.randf_range(0.75, 1.35)
	dressing = false
	batch_details()
	if leaf_count > 0:
		leaves.generate_normals()
		part("Ferns and vine leaves", leaves.commit(), Vector3.ZERO, foliage)

func build_wall() -> void:
	var rock := SurfaceTool.new()
	rock.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols := maxi(2, ceili((right_edge - left_edge) / 2.4))
	var rows := maxi(2, ceili((cave_roof - cave_floor) / 1.9))
	var vertices := PackedVector3Array()
	var organic := sector in ORGANIC
	var lower_wall := cave_floor - (8.4 if arena else 3.4)
	for row in rows + 1:
		for col in cols + 1:
			var x := lerpf(left_edge, right_edge, float(col) / cols)
			var y := lerpf(lower_wall, cave_roof, float(row) / rows)
			if organic and col > 0 and col < cols:
				x += rng.randf_range(-0.55, 0.55)
			if organic and row > 0 and row < rows:
				y += rng.randf_range(-0.42, 0.42)
			var depth := -4.9 + (rng.randf_range(-0.55, 0.54) if organic else 0.02 * (col % 3))
			vertices.append(Vector3(x, y, depth))
	for row in rows:
		for col in cols:
			var i := row * (cols + 1) + col
			var a := vertices[i]
			var b := vertices[i + 1]
			var c := vertices[i + cols + 1]
			var d := vertices[i + cols + 2]
			triangle(rock, a, c, b)
			triangle(rock, b, c, d)
	rock.generate_normals()
	part("Layered sector wall", rock.commit(), Vector3.ZERO, stone)

func triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	surface.add_vertex(a)
	surface.add_vertex(b)
	surface.add_vertex(c)

func finish(color: Color, metallic: float, emission := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.78 if metallic < 0.24 else 0.56
	material.metallic = metallic
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	return material

func part(label: String, mesh: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	instance.position = at
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if dressing:
		details.append(instance)
	else:
		add_child(instance, true)
	return instance

func batch_details() -> void:
	var buffers: Dictionary = {}
	for detail in details:
		var material := detail.material_override
		if not buffers.has(material):
			var batch := SurfaceTool.new()
			batch.begin(Mesh.PRIMITIVE_TRIANGLES)
			buffers[material] = batch
		buffers[material].append_from(detail.mesh, 0, detail.transform)
		detail.free()
	details.clear()
	for material: Material in buffers:
		part("Sculpted environmental details", buffers[material].commit(), Vector3.ZERO, material)

func plate(label: String, at: Vector3, size: Vector3, material: Material, bevel := 0.075) -> MeshInstance3D:
	var block := BoxMesh.new()
	block.size = size
	return part(label, CHAMFER.from_box(block, bevel), at, material)

func branch(label: String, a: Vector3, b: Vector3, r1: float, r2: float, material: Material, sides := 7) -> void:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = r1
	mesh.top_radius = r2
	mesh.radial_segments = sides
	mesh.height = a.distance_to(b) + minf(r1, r2) * 0.6
	var segment := part(label, mesh, a.lerp(b, 0.5), material)
	var axis := (b - a).normalized()
	var cross := Vector3.FORWARD.cross(axis).normalized()
	segment.basis = Basis(cross, axis, cross.cross(axis))

func decorate_bay(x: float, y: float, row: int) -> void:
	var origin := Vector3(x, y, -4.16)
	match sector:
		1:
			plate("Heat exchanger collar", origin, Vector3(3.2, 1.55, 0.70), trim, 0.15)
			for fin in 6:
				plate("Sooted radiator fin", origin + Vector3((fin - 2.5) * 0.46, 0.0, 0.36), Vector3(0.20, 1.30, 0.42), base)
			branch("Heated exhaust return", origin + Vector3(-2.5,0.66,0), origin + Vector3(3.0,0.66,0), 0.18, 0.18, trim)
		2, 3:
			cave_formation(origin)
		4:
			branch("Water main", origin + Vector3(-2.85,0,0), origin + Vector3(2.85,0,0), 0.42, 0.42, trim, 14)
			for offset in [-1.75, 0.0, 1.75]:
				branch("Pressure pipe flange", origin + Vector3(offset - .12,0,0), origin + Vector3(offset + .12,0,0), 0.52, 0.52, base, 14)
			plate("Pressure gauge", origin + Vector3(0, 0.46, 0.26), Vector3(.55,.42,.35), glow)
		5:
			plate("Carved archive seal", origin, Vector3(2.05, 2.7, 0.64), stone, 0.29)
			for tier in 3:
				var line := plate("Inlaid glyph", origin + Vector3(0,0.63 - tier * 0.60, 0.328), Vector3(0.8 + tier * .25,.10,.056), trim)
				line.rotation.z = (tier - 1) * 0.18
		6:
			for side in [-1, 1]:
				branch("Hangar cross bracing", origin + Vector3(side * 2.65,-1.75,0), origin + Vector3(-side * 2.65,1.75,0), 0.26, 0.26, trim, 4)
			plate("Landing guidance lamp", origin + Vector3(0, 0, 0.32), Vector3(1.45,.11,.17), glow)
		7:
			for i in [-1, 1]:
				var at := origin + Vector3(i * 0.91, 0, 0)
				branch("Culture vessel", at + Vector3.DOWN * 1.11, at + Vector3.UP * 1.11, 0.39, 0.39, glow, 16)
				for dy in [-1.0,1.0]:
					branch("Containment coupling", at + Vector3.UP * (dy - 0.20), at + Vector3.UP * (dy + 0.20), 0.55, 0.55, base, 12)
		8:
			plate("Radiator bed", origin, Vector3(3.5, 2.03, 0.38), base, .13)
			for i in 8:
				plate("Radiator louvre", origin + Vector3((i-3.5)*0.41,0,.23), Vector3(.20,1.6,.32), trim, .013)
			plate("Coolant feed", origin + Vector3(0,.86,0.39), Vector3(2.7,.07,.12), glow)
		9:
			for i in 3:
				var panel := plate("Salvaged hull armor", origin + Vector3((i-1)*1.17,(i%2)*0.3,.12 * i), Vector3(1.56,1.7,.38), stone, .12)
				panel.rotation.z = rng.randf_range(-.23,.23)
			branch("Exposed manifold", origin + Vector3(-2.2,-.91,0), origin + Vector3(2.2,-1.22,0), 0.20, 0.20, trim)
		10:
			for i in 5:
				var at := origin + Vector3((i-2)*.68, -0.85, .11)
				var tip := at + Vector3(rng.randf_range(-0.75,0.75),rng.randf_range(0.7,2.05),0.25)
				branch("Rift crystal", at, tip, rng.randf_range(.19,.42), .018, glow if i == row % 5 else trim, 5)

func build_arena_backdrop() -> void:
	var at := Vector3((left_edge + right_edge) * 0.5, cave_floor + 7.25, -4.10)
	var core := Vector3(0,1.0,0)
	match sector:
		1:
			plate("Smelting furnace", at, Vector3(7.9,5.5,.94), base, .40)
			for i in 7:
				var x := (i-3)*.87
				plate("Furnace intake", at + Vector3(x,0,.52), Vector3(.40,3.22,.24), trim, .082)
				plate("Banked furnace light", at + Vector3(x,0,.66), Vector3(.12,2.2,.067), glow)
		2:
			branch("Massive canopy root", at + Vector3(-5.0,3.2,-.2), at + Vector3(.8,-3.2,.06), .82,.42,base,10)
			branch("Crossing canopy root", at + Vector3(5.4,2.6,-.22), at + Vector3(-1.4,-.7,.12), .65,.22,trim,10)
			cave_formation(at + Vector3(-2.65,1.25,0))
			cave_formation(at + Vector3(3.1,2.30,0))
		3:
			for offset in [-3.4,0.0,3.4]:
				cave_formation(at + Vector3(offset,2.3 - absf(offset)*.33,0))
			plate("Cold fusion containment", at, Vector3(3.4,4.5,.83), base, .24)
			for i in 3:
				plate("Heat sink fins", at + Vector3((i-1)*.82,-.22,.46), Vector3(.28,3.4,.19), trim)
		4:
			branch("Pressure chamber vessel", at + Vector3(-4.03,0,0), at + Vector3(4.03,0,0), 1.35,1.35,base,16)
			for i in [-1,0,1]:
				branch("Pressure hoops", at + Vector3(i*1.95-.094,0,0), at + Vector3(i*1.95+.094,0,0), 1.43,1.43,trim,16)
		5:
			for i in [-1,0,1]:
				plate("Archive monolith", at + Vector3(i*2.1,0,0), Vector3(1.74,4.8,.71), stone,.24)
				var sigil := plate("Inlaid triangular seal", at + Vector3(i*2.1,.48,.39),
					Vector3(.68,.68,.06), glow,.04)
				sigil.rotation.z = PI / 4.0
		6:
			plate("Hangar bay bulkhead", at, Vector3(10.2,4.62,.74), base,.25)
			for i in [-1,1]:
				branch("Hangar strut", at + Vector3(i*4.7,-1.88,.30), at + Vector3(i*1.38,1.8,.30), .24,.32,trim,4)
			plate("Flight approach marker", at + Vector3(0,0,.42), Vector3(3.8,.14,.11), glow)
		7:
			for x in [-2.37,2.37]:
				var vessel := at + Vector3(x,0,0)
				branch("Bioreactor culture tank", vessel - core * 2.25, vessel + core * 2.25, .91,.91,base,18)
				for y in [-1.56,1.56]:
					plate("Reactor tank brace", vessel + core*y, Vector3(2.06,.23,1.88), trim,.13)
				plate("Sample observation window", vessel + Vector3(0,.02,.83), Vector3(.57,2.54,.15), glow,.12)
		8, 10:
			var ring := TorusMesh.new()
			ring.rings = 32
			ring.ring_segments = 8
			ring.outer_radius = 2.81
			ring.inner_radius = 2.54
			part("Resonance ring", ring, at, trim).rotation.x = PI * 0.5
			for i in 7:
				var a := TAU * i / 7.0
				var axis := Vector3(cos(a),sin(a),0)
				branch("Field conductor", at + axis*1.62, at + axis*2.81, .096,.18,glow,5)
		9:
			branch("Gantry crane crossmember", at + Vector3(-5.1,1.80,0), at + Vector3(5.1,1.80,0), .31,.31,trim,4)
			for offset in [-3.6,2.7]:
				var origin := at + Vector3(offset,-.1,.17)
				branch("Crane hoist cable", origin, origin + core*2.0, .051,.068,base,6)
				plate("Magnet hoist", origin - core*.24, Vector3(1.6,.72,.82), stone, .14)

func cave_formation(origin: Vector3) -> void:
	for i in 3:
		var offset := Vector3((i - 1) * 0.91, rng.randf_range(-0.17, 0.21), -0.18)
		var rock := plate("Rock overhang", origin + offset, Vector3(rng.randf_range(1.30, 2.48),rng.randf_range(.56,1.18),1.84), stone, .28)
		rock.rotation.z = rng.randf_range(-.27,.27)
	if sector == 3:
		for i in rng.randi_range(5, 9):
			var start := origin + Vector3(rng.randf_range(-1.58,1.58), -.13, rng.randf_range(.35,.75))
			var size := rng.randf_range(.10,.30)
			var end := start + Vector3(rng.randf_range(-.24,.24),-rng.randf_range(.65,2.6),0.14)
			var shoulder := start.lerp(end, .32) + Vector3(.09,0,.04)
			branch("Ice collar", start, shoulder, size * 1.34, size * 0.74, trim)
			branch("Tapering icicle", shoulder, end, size * 0.75, .008, glow if i % 4 == 0 else trim)
	else:
		for i in rng.randi_range(4, 7):
			var start := origin + Vector3((i - 2.0) * .57, rng.randf_range(-.15,.2), .71)
			var length := rng.randf_range(1.25,4.85)
			var sway := rng.randf_range(-1.25, 1.2)
			var last := start
			for j in range(1, 7):
				var t := float(j) / 6.0
				var next := start + Vector3(sway * t + sin(t * 7.0) * .23, -t * length, sin(t * 4.0) * .23)
				branch("Trailing root", last, next, lerpf(.087,.019,t), lerpf(.069,.014,t), trim if i % 2 else base)
				if j % 2 == i % 2:
					var direction := 1.0 if (j + i) % 3 == 0 else -1.0
					leaf(next, direction, rng.randf_range(.34,.74))
					leaf(next + Vector3.DOWN * .19, -direction, rng.randf_range(.27,.48))
				last = next

func leaf(at: Vector3, side: float, length: float) -> void:
	leaf_count += 1
	var tip := at + Vector3(side * length, -length * .64, .12)
	var mid := at.lerp(tip, .46) + Vector3(0,0,.10)
	var edge := Vector3.UP * length * .25 + Vector3(side * length * .08,0,0)
	leaves.set_color(Color("3a602e").lerp(Color("65803d"), rng.randf()))
	triangle(leaves, at, mid + edge, mid)
	triangle(leaves, mid, mid + edge, tip)
	leaves.set_color(Color("2b5236").lerp(Color("466831"), rng.randf()))
	triangle(leaves, at, mid, mid - edge)
	triangle(leaves, mid, tip, mid - edge)
