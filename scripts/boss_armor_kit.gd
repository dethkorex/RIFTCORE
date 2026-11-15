extends RefCounted

const Trim := preload("res://scripts/sector_material_trim.gd")
const Chamfer := preload("res://scripts/factory_chamfer.gd")
const MODULES := [
	"Exhaust", "SeedBank", "CryoFins", "PressureTank", "CipherBlades",
	"Turbines", "SporeVials", "OrbitalDish", "MagnetCoils", "RiftWings"
]
static var kits: Dictionary = {}

var batches: Dictionary = {}
var plate: ShaderMaterial
var metal: StandardMaterial3D
var ceramic: StandardMaterial3D
var energy: StandardMaterial3D

static func mount(armor: Node3D, sector: int, miniboss: bool, accent: Color) -> void:
	var bounds := AABB()
	var found := false
	var local := armor.global_transform.affine_inverse()
	for mesh in armor.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null:
			continue
		var part_bounds: AABB = local * mesh.global_transform * mesh.get_aabb()
		bounds = bounds.merge(part_bounds) if found else part_bounds
		found = true
	if not found:
		return
	var key := Vector2i(sector, int(miniboss))
	if not kits.has(key):
		kits[key] = load("res://scripts/boss_armor_kit.gd").new().assemble(sector, miniboss, accent)
	var detail := MeshInstance3D.new()
	detail.name = MODULES[sector - 1]
	detail.mesh = kits[key]
	var center := bounds.get_center()
	var width := clampf(bounds.size.x, 1.3, 3.45)
	detail.scale = Vector3(width * (.47 if sector == 8 else .53), bounds.size.y * .59, clampf(bounds.size.z, 1.0, 1.8))
	detail.position = Vector3(center.x, bounds.position.y + bounds.size.y * .58, center.z)
	armor.add_child(detail)

func assemble(sector: int, mini: bool, accent: Color) -> ArrayMesh:
	plate = Trim.make(sector, true)
	metal = finish(Color("131a24"), .76, .44)
	ceramic = finish(Color("a1afb8").lerp(accent, .32), .53, .32)
	energy = RiftProjectile.light_paint(accent.lerp(Color.WHITE, .13), 1.8)
	var spacing := .70 if mini else .81
	box(Vector3(0.0, .11 if mini else .20, -.29), Vector3(spacing * 2.0, .16, .21), metal, .045)
	for side in [-1.0, 1.0]:
		var x: float = spacing * side
		var base := Vector3(x, .11 if mini else .20, -.24)
		box(base, Vector3(.37, .31, .34), metal, .07, side * -.29)
		box(base + Vector3(side * .08, .06, .055), Vector3(.31, .22, .28), plate, .064, side * -.24)
		for bolt in [-1.0, 1.0]:
			cylinder(base + Vector3(bolt * .10, .105, .218), .025, .032, ceramic, Vector3.RIGHT * PI * 0.5, 12)
		var point := base + Vector3(side * .12, .18, -.09)
		match sector:
			1:
				cylinder(point, .108, .55, plate, Vector3.BACK * side * .18)
				for lip in [-.20, .19, .25]:
					cylinder(point + Vector3(0, lip, .0), .119, .057, energy if lip == .19 else metal)
			2:
				for stalk in 3 if mini else 4:
					var pos := point + Vector3(side * stalk * .095, -stalk * .022, -.11)
					cylinder(pos, .062, .49 - stalk * .048, ceramic, Vector3.BACK * side * -.25)
					cylinder(pos + Vector3(side * .047, .165 - stalk * .03, 0), .067, .092, energy)
			3:
				for fin in 3:
					box(point + Vector3(side * fin * .095, .025 + fin * .036, -.01), Vector3(.10, .51 - .07 * fin, .24), ceramic, .045, side * -.29)
			4:
				cylinder(point, .131, .51, plate, Vector3.BACK * side * -.36)
				cylinder(point + Vector3(side * .078, .19, 0), .145, .09, ceramic, Vector3.BACK * side * -.36)
				box(point + Vector3(0, .02, .119), Vector3(.055, .21, .034), energy, .01)
			5:
				for fin in 3:
					box(point + Vector3(side * (.08 + fin * .064), .17 - fin * .12, 0), Vector3(.12, .61 - fin * .10, .32), plate, .055, side * -.55)
			6:
				port(point + Vector3(side * .10, -.01, .055), .21 if mini else .27)
			7:
				for tube in [-1.0, 1.0]:
					var vial := point + Vector3(tube * .109, -.06, 0.04)
					cylinder(vial, .073, .45, energy, Vector3.BACK * tube * .09)
					cylinder(vial + Vector3(0, -.18, 0), .087, .08, metal)
					cylinder(vial + Vector3(0, .18, 0), .087, .08, plate)
			8:
				port(point + Vector3(side * .08, .12, -.04), .18 if mini else .23)
				box(point + Vector3(side * .20, -.12, -.17), Vector3(.40, .12, .26), plate, .044, -side * .55)
			9:
				for coil in 4:
					cylinder(point + Vector3(0, coil * .105 - .175, .025), .132, .081, metal if coil % 2 == 0 else energy)
				cylinder(point, .106, .58, plate)
			10:
				for fin in 2 if mini else 3:
					var wing := point + Vector3(side * (fin * .18 + .04), .09 - fin * .12, -.03)
					box(wing, Vector3(.16, .59, .36), plate, .066, side * -.62)
					box(wing + Vector3(0, .03, .174), Vector3(.045, .49, .028), energy, .009, side * -.62)
	var assembled := ArrayMesh.new()
	for material: Material in batches:
		var batch := batches[material] as SurfaceTool
		batch.set_material(material)
		batch.commit(assembled)
	return assembled

func finish(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material

func append(shape: Mesh, material: Material, at: Vector3, angles: Vector3) -> void:
	if not batches.has(material):
		var buffer := SurfaceTool.new()
		buffer.begin(Mesh.PRIMITIVE_TRIANGLES)
		batches[material] = buffer
	batches[material].append_from(shape, 0, Transform3D(Basis.from_euler(angles), at))

func box(at: Vector3, size: Vector3, material: Material, bevel: float, angle := 0.0) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	append(Chamfer.from_box(mesh, bevel), material, at, Vector3.BACK * angle)

func cylinder(at: Vector3, radius: float, depth: float, material: Material, rotation := Vector3.ZERO, segments := 28) -> void:
	var body := CylinderMesh.new()
	body.top_radius = radius * .91
	body.bottom_radius = radius
	body.height = depth
	body.radial_segments = segments
	append(body, material, at, rotation)

func port(at: Vector3, radius: float) -> void:
	var edge := TorusMesh.new()
	edge.inner_radius = radius * .8
	edge.outer_radius = radius
	edge.rings = 32
	edge.ring_segments = 12
	append(edge, ceramic, at, Vector3.RIGHT * PI * 0.5)
	cylinder(at - Vector3.BACK * .02, radius * .81, .082, metal, Vector3.RIGHT * PI * .5)
	cylinder(at + Vector3.BACK * .044, radius * .24, .065, energy, Vector3.RIGHT * PI * .5)
	for fin in 7:
		var angle := fin * TAU / 7.0
		box(at + Vector3(cos(angle) * radius * .54, sin(angle) * radius * .54, .037),
			Vector3(radius * .42, .038, .038), plate, .008, angle)
