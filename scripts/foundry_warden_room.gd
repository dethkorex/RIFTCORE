@tool
extends Node3D

const Bevel := preload("res://scripts/factory_chamfer.gd")
const PanelTexture := preload("res://assets/campaign/neon_factory/surfaces/sector_wall.jpg")
const BROKEN_SHALE := Color("252b33")
const FRAME := Color("434851")
const BRONZE := Color("9b4d2e")
const HEAT := Color("ff802e")
const COOLANT := Color("67dee0")
const ROOF := 26.4
const ENTRY_X := -33.5
const EXIT_X := 22.5
const BACK := -1.25
const FRONT := 5.65
const PORTAL_HEIGHT := 6.49

var door_left: Node3D
var door_right: Node3D
var kiln_light: OmniLight3D
var ready_lamps: Array[StandardMaterial3D] = []

func _ready() -> void:
	var dark := finish(BROKEN_SHALE.lightened(.16), .39)
	dark.albedo_texture = PanelTexture
	dark.uv1_triplanar = true
	dark.uv1_scale = Vector3.ONE * .37
	var structural := finish(FRAME, .68)
	var bronze := finish(BRONZE, .74)
	var insulator := finish(Color("16191e"), .15)
	var light := finish(Color("a7d0df"), .27, 1.35)
	var hot := finish(HEAT, .26, 2.05)
	var teal := finish(COOLANT, .28, 1.55)
	build_superstructure(dark, structural, bronze, light, teal)
	build_bulkhead(dark, structural, bronze, insulator, hot)
	area_light(Vector3(-18.4, 6.6, 2.95), Color("bfd2d9"), 10.5, 1.40)
	area_light(Vector3(-4.75, 15.83, 1.9), COOLANT, 8.6, 1.55)
	area_light(Vector3(6.25, 16.8, 2.8), Color("ffbd85"), 12.5, 1.20)
	area_light(Vector3(20.1, 3.6, 2.1), Color("b6c8d4"), 7.5, 1.25)
	present_hatch(0.0, 0.0)

func area_light(at: Vector3, color: Color, reach: float, energy: float) -> void:
	var light := OmniLight3D.new()
	light.position = at
	light.omni_range = reach
	light.light_energy = energy
	light.light_color = color
	add_child(light)

func build_superstructure(dark: Material, structural: Material, bronze: Material, lamp: Material, teal: Material) -> void:
	# All shell members use the two gate planes and the same rear and cutaway faces.
	var span := Vector2(ENTRY_X, EXIT_X)
	var width := span.y - span.x
	var center := (span.x + span.y) * .5
	# The playable deck ends at z=-2.4. Close the service trench behind it under every column.
	part(self, Vector3(width + .80, .62, 2.77), Vector3(center, -.30, -.30), structural, .04)
	part(self, Vector3(width + .80, .19, .33), Vector3(center, .065, BACK + .49), bronze, .04)
	part(self, Vector3(width + .8, ROOF + .45, .52), Vector3(center, ROOF * .5, BACK), dark, .08)
	build_ceiling(span, ROOF, 8, dark, structural, bronze, lamp)
	for x in [ENTRY_X, EXIT_X]:
		build_portal_return(x, dark, structural, bronze, lamp)
	build_passage(Vector2(ENTRY_X - 13, ENTRY_X), false, dark, structural, bronze, lamp)
	build_passage(Vector2(EXIT_X - 5.0, EXIT_X + 19.0), true, dark, structural, bronze, lamp)
	build_perch_cradle(structural, bronze, lamp)
	build_east_seal(dark, structural, bronze, lamp)
	mount_purge_route(structural, bronze)
	var pitch := width / 8.0
	for i in range(1, 8):
		var x := span.x + i * pitch
		part(self, Vector3(.54, ROOF, .70), Vector3(x, ROOF * .5, BACK + .40), structural, .064)
		part(self, Vector3(.81, .82, .84), Vector3(x, .41, BACK + .42), bronze, .09)
		# Knees transfer the soffit beams into the rear columns.
		var knee := part(self, Vector3(.51, .46, 3.28), Vector3(x, ROOF - 1.22, .30), structural, .066)
		knee.rotation.x = -.62
		part(self, Vector3(.67, .61, .83), Vector3(x, ROOF - 2.18, BACK + .44), bronze, .07)
	# A continuous exhaust plenum gives the upper wall a readable horizontal datum.
	part(self, Vector3(width, 1.62, .64), Vector3(center, ROOF - 4.1, BACK + .37), structural, .12)
	for i in 8:
		var x := ENTRY_X + (i + .5) * pitch
		part(self, Vector3(pitch - .95, 1.30, .19), Vector3(x, ROOF - 4.1, BACK + .76), dark, .085)
		for row in 3:
			part(self, Vector3(pitch - 1.40, .10, .23), Vector3(x, ROOF - 4.44 + row * .34, BACK + .85), structural, .022)
	for x in [-25.3, -16.3, -8.3, 10.6, 16.6]:
		build_service_bay(x, dark, structural, bronze, lamp if x > 0.0 else teal)
	for x in [-10.8, 6.0]:
		part(self, Vector3(1.03, 4.4, 1.22), Vector3(x, 2.59, .16), structural, .14)
		for i in 7:
			part(self, Vector3(1.13, .115, 1.27), Vector3(x, .95 + i * .49, .17), bronze, .025)

func build_ceiling(span: Vector2, height: float, bays: int, panels: Material, frame: Material, bronze: Material, lamp: Material) -> void:
	var width := span.y - span.x
	var pitch := width / float(bays)
	var center := (span.x + span.y) * .5
	part(self, Vector3(width + .34, .26, FRONT - BACK + .15), Vector3(center, height + .37, (FRONT + BACK) * .5), frame, .04)
	for bay in bays:
		var x := span.x + (float(bay) + .5) * pitch
		part(self, Vector3(pitch - .065, .43, FRONT - BACK), Vector3(x, height + .10, (FRONT + BACK) * .5), panels, .07)
		part(self, Vector3(.29, .36, 6.56), Vector3(x - pitch * .5, height - .19, 2.11), frame, .055)
		part(self, Vector3(1.52, .23, .56), Vector3(x, height - .24, 3.32), frame, .045)
		part(self, Vector3(1.20, .055, .31), Vector3(x, height - .37, 3.32), lamp, .014)
	for z in [-.82, 2.72, 5.46]:
		part(self, Vector3(width, .57, .34), Vector3(center, height - .25, z), frame, .064)
	part(self, Vector3(width - .24, .10, .085), Vector3(center, height - .24, 5.66), bronze, .022)

func build_service_bay(x: float, panel: Material, frame: Material, bronze: Material, indicator: Material) -> void:
	part(self, Vector3(5.12, 8.65, .29), Vector3(x, 5.47, -.92), panel, .16)
	for offset in [-2.45, 2.45]:
		part(self, Vector3(.22, 8.65, .28), Vector3(x + offset, 5.47, -.68), frame, .042)
	part(self, Vector3(4.66, 1.58, .27), Vector3(x, 5.14, -.68), frame, .085)
	part(self, Vector3(4.43, 1.24, .13), Vector3(x, 5.14, -.52), panel, .060)
	for row in 3:
		part(self, Vector3(4.12, .13, .17), Vector3(x, 4.82 + row * .32, -.44), bronze, .028)
	part(self, Vector3(2.81, .27, .23), Vector3(x, 9.29, -.67), frame, .045)
	part(self, Vector3(2.18, .075, .071), Vector3(x, 9.29, -.52), indicator, .018)

func build_portal_return(x: float, lining: Material, frame: Material, bronze: Material, lamp: Material) -> void:
	var depth := FRONT - BACK
	var mid_z := (BACK + FRONT) * .5
	var height := ROOF - PORTAL_HEIGHT
	part(self, Vector3(.74, height + .36, depth + .22), Vector3(x, PORTAL_HEIGHT + height * .5 + .12, mid_z), lining, .06)
	for z in [BACK, FRONT]:
		part(self, Vector3(.85, ROOF + .40, .45), Vector3(x, ROOF * .5, z), frame, .07)
		part(self, Vector3(1.02, .65, .65), Vector3(x, .29, z), bronze, .072)
	for y in [PORTAL_HEIGHT, PORTAL_HEIGHT + .52, ROOF - .12]:
		part(self, Vector3(.94, .31, depth + .48), Vector3(x, y, mid_z), frame, .06)
	for z in [.30, 3.83]:
		part(self, Vector3(.96, .075, 1.05), Vector3(x, PORTAL_HEIGHT - .16, z), lamp, .02)

func build_passage(span: Vector2, extend_floor: bool, lining: Material, frame: Material, bronze: Material, lamp: Material) -> void:
	var width := span.y - span.x
	var x := (span.x + span.y) * .5
	var depth := FRONT - BACK
	var mid_z := (FRONT + BACK) * .5
	# Fit the approach canopy over the existing hall lining, carrying it into the portal.
	part(self, Vector3(width + .36, .52, depth + .16), Vector3(x, PORTAL_HEIGHT + .25, mid_z), lining, .07)
	part(self, Vector3(width + .50, .42, .35), Vector3(x, PORTAL_HEIGHT + .15, FRONT), frame, .05)
	part(self, Vector3(width + .40, PORTAL_HEIGHT + .46, .56), Vector3(x, PORTAL_HEIGHT * .5, BACK), lining, .08)
	if extend_floor:
		var reference := get_parent().get_parent().get_node("TERRAIN/ArmorFloor11") as Node3D
		var template := preload("res://assets/neon_factory/foundry/retaining_deck.tscn")
		for i in 3:
			var next := template.instantiate() as StaticBody3D
			next.collision_layer = 0
			next.collision_mask = 0
			add_child(next)
			next.global_position = reference.global_position + Vector3.RIGHT * (7.0 + i * 6)
	for i in ceili(width / 4.0):
		var at := span.x + (i + .5) * width / ceili(width / 4.0)
		part(self, Vector3(.29, .26, depth), Vector3(at, PORTAL_HEIGHT - .12, mid_z), frame, .045)
		part(self, Vector3(.42, PORTAL_HEIGHT, .57), Vector3(at, PORTAL_HEIGHT * .5, BACK + .34), frame, .065)
		part(self, Vector3(.32, .08, 1.12), Vector3(at, PORTAL_HEIGHT - .28, 2.32), lamp, .018)
		part(self, Vector3(.54, .53, .70), Vector3(at, .27, BACK + .40), bronze, .055)

func build_perch_cradle(frame: Material, bronze: Material, lamp: Material) -> void:
	var perch := get_parent().get_parent().get_node("TERRAIN/WardenLavaPerch") as Node3D
	var at := to_local(perch.global_position)
	for offset in [-2.35, 2.35]:
		var x: float = at.x + offset
		part(self, Vector3(.94, 3.23, .52), Vector3(x, at.y - 1.69, BACK + .42), frame, .095)
		part(self, Vector3(.58, .54, 3.49), Vector3(x, at.y - .49, .63), frame, .075)
		var strut := part(self, Vector3(.40, .40, 3.90), Vector3(x, at.y - 1.57, .71), bronze, .07)
		strut.rotation.x = -.65
		part(self, Vector3(.65, .12, .12), Vector3(x, at.y - .43, 2.40), lamp, .025)

func build_east_seal(panel: Material, frame: Material, bronze: Material, lamp: Material) -> void:
	var barrier := get_parent().get_parent().get_node("ExitBarrier") as Node3D
	var x := to_local(barrier.global_position).x
	part(self, Vector3(.74, PORTAL_HEIGHT - 3.40, 4.26), Vector3(x, (PORTAL_HEIGHT + 3.40) * .5, -global_position.z), panel, .07)
	part(self, Vector3(.94, .27, 4.54), Vector3(x, 3.55, -global_position.z), frame, .045)
	for z in [-2.16, 2.16]:
		part(self, Vector3(.69, 3.58, .32), Vector3(x, 1.79, z - global_position.z), frame, .045)
	var seal := barrier.get_node("Seal") as Node3D
	part(seal, Vector3(.39, 3.40, 3.96), Vector3(0, 1.70, 0), panel, .11)
	for y in [.35, 1.17, 2.23, 3.14]:
		part(seal, Vector3(.46, .15, 3.96), Vector3(0, y, 0), frame, .04)
	for depth in [-1.60, 1.60]:
		part(seal, Vector3(.12, 2.81, .21), Vector3(-.22, 1.70, depth), bronze, .035)
	part(seal, Vector3(.095, .19, .88), Vector3(-.25, 2.64, 0), lamp, .027)

func mount_purge_route(structural: Material, bronze: Material) -> void:
	var route := get_parent().get_parent().get_node_or_null("TERRAIN/WardenPurgeRoute")
	if not route:
		return
	for deck: Node3D in route.get_children():
		var mounting := to_local(deck.global_position)
		var collider := deck.get_node("Collider") as CollisionShape3D
		var tread := collider.shape as BoxShape3D
		var support_offset := tread.size.x * absf(deck.scale.x) * .32
		part(self, Vector3(support_offset * 2.0 + .72, .51, .37), Vector3(mounting.x, mounting.y - .48, -.96), structural, .078)
		for side in [-1.0, 1.0]:
			var x: float = mounting.x + side * support_offset
			part(self, Vector3(.33, .33, 2.74), Vector3(x, mounting.y - .38, .27), structural, .064)
			part(self, Vector3(.52, 1.12, .37), Vector3(x, mounting.y - .91, -.97), bronze, .082)
			var bracket := part(self, Vector3(.29, .25, 2.55), Vector3(x, mounting.y - .86, .24), bronze, .053)
			bracket.rotation.x = -.42
	var grip := get_parent().get_parent().get_node_or_null("TERRAIN/WardenKickColumn") as Node3D
	if grip:
		var mounting := to_local(grip.global_position)
		part(self, Vector3(1.35, 4.26, .32), Vector3(mounting.x, mounting.y, -.88), structural, .095)
		for height in [-1.38, 1.38]:
			part(self, Vector3(1.02, .47, 1.42), Vector3(mounting.x, mounting.y + height, -.18), bronze, .082)

func build_bulkhead(dark: Material, structural: Material, bronze: Material, refractory: Material, hot: Material) -> void:
	var edges := PackedVector2Array([
		Vector2(-2.52, .16), Vector2(2.52, .16), Vector2(3.54, 1.19), Vector2(3.54, 5.55),
		Vector2(2.51, 6.58), Vector2(-2.51, 6.58), Vector2(-3.54, 5.55), Vector2(-3.54, 1.19),
	])
	part(self, Vector3(8.9, 7.6, .34), Vector3(0, 3.64, -.51), refractory, .25)
	part(self, Vector3(4.4, .13, 1.84), Vector3(0, .08, .24), dark, .06)
	for edge in edges.size():
		var a := edges[edge]
		var b := edges[(edge + 1) % edges.size()]
		var mid := (a + b) * .5
		var beam := part(self, Vector3(a.distance_to(b) + .27, .53, .64), Vector3(mid.x, mid.y, .18), structural, .085)
		beam.rotation.z = (b - a).angle()
		var inlay := part(self, Vector3(a.distance_to(b) - .11, .061, .081), Vector3(mid.x, mid.y, .52), bronze, .02)
		inlay.rotation.z = beam.rotation.z
	for i in 6:
		part(self, Vector3(.10, 3.5 + (i % 2) * .45, .075), Vector3(-1.25 + i * .5, 2.40, -.24), hot, .024)
	door_left = shutter(-1.0, dark, bronze)
	door_right = shutter(1.0, dark, bronze)
	for i in 5:
		part(self, Vector3(.45, .35, .28), Vector3(-1.52 + i * .76, 6.92, .23), structural, .049)
		var lens := finish(HEAT, .14)
		ready_lamps.append(lens)
		part(self, Vector3(.32, .16, .06), Vector3(-1.52 + i * .76, 6.92, .40), lens, .03)
	kiln_light = OmniLight3D.new()
	kiln_light.position = Vector3(0, 3.0, .85)
	kiln_light.light_color = HEAT
	kiln_light.omni_range = 10.2
	add_child(kiln_light)

func shutter(side: float, steel: Material, bronze: Material) -> Node3D:
	var door := Node3D.new()
	add_child(door)
	part(door, Vector3(3.44, 6.08, .47), Vector3(side * 1.71, 3.38, -.19), steel, .19)
	for y in [1.62, 3.35, 5.09]:
		part(door, Vector3(2.86, .34, .18), Vector3(side * 1.80, y, .17), bronze, .06)
	part(door, Vector3(.13, 5.20, .10), Vector3(side * .33, 3.36, .13), bronze, .04)
	return door

func present_hatch(power: float, travel: float) -> void:
	door_left.position.x = -3.14 * travel
	door_right.position.x = 3.14 * travel
	for i in ready_lamps.size():
		var energized := smoothstep(float(i) / 5.0, float(i + 1) / 5.0, power)
		ready_lamps[i].albedo_color = Color("2c2118").lerp(HEAT, energized)
		ready_lamps[i].emission_enabled = energized > 0.01
		ready_lamps[i].emission_energy_multiplier = energized * 3.1
	kiln_light.light_energy = 0.28 + power * 1.05 + travel * 1.8

func part(parent: Node3D, size: Vector3, at: Vector3, material: Material, bevel: float) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = Bevel.from_box(box, bevel)
	instance.position = at
	instance.material_override = material
	parent.add_child(instance)
	return instance

static func finish(color: Color, metallic: float, emissive := 0.0) -> StandardMaterial3D:
	var surface := StandardMaterial3D.new()
	surface.albedo_color = color
	surface.metallic = metallic
	surface.roughness = .51
	surface.emission = color
	surface.emission_enabled = emissive > 0.0
	surface.emission_energy_multiplier = emissive
	return surface
