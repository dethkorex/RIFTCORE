@tool
extends Node3D

const SURFACE := preload("res://assets/campaign/sector_surface.gdshader")
const CHAMFER := preload("res://scripts/factory_chamfer.gd")
const PANEL_TRIM := preload("res://scripts/sector_material_trim.gd")
const PALETTES := [
	["312d2c","a46643","ff8330"], ["34322a","687844","bece65"],
	["274054","7aabc1","b4e6ff"], ["192e36","426e79","74eddd"],
	["493831","a78257","ffd187"], ["202e40","667f9a","89d7f3"],
	["493f53","898aa5","e6b0fc"], ["26283e","68687e","bb9bff"],
	["372e28","986b4d","ff990f"], ["25182e","714482","f49bfd"]
]

@export_range(1, 10) var sector := 1
@export var surface: Texture2D
@export var shaft := false
static var kits: Dictionary = {}
var meshes: Dictionary = {}
var ice_coating := false
static var shadow_meshes: Dictionary[bool, BoxMesh] = {}

func _ready() -> void:
	if surface == null:
		return
	ice_coating = get_parent().is_in_group(&"ice_deck")
	var key := Vector3i(sector, int(shaft), int(ice_coating))
	if not kits.has(key):
		kits[key] = make_kit()
	var geometry := MeshInstance3D.new()
	geometry.name = "Sector geometry"
	geometry.mesh = kits[key]
	geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(geometry, true)

	# The structural slab casts the shadow for all its small fascia details.
	if not shadow_meshes.has(shaft):
		var slab := BoxMesh.new()
		slab.size = Vector3(0.79, 4.25, 3.97) if shaft else Vector3(5.98, 0.84, 4.78)
		shadow_meshes[shaft] = slab
	var caster := MeshInstance3D.new()
	caster.name = "Structural shadow"
	caster.mesh = shadow_meshes[shaft]
	caster.position.y = 0.0 if shaft else -0.42
	caster.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	add_child(caster)

func make_kit() -> ArrayMesh:
	var colors: Array = PALETTES[sector - 1]
	var chassis := finish(Color(colors[0]), .39)
	var trim := finish(Color(colors[1]), .52)
	var lamp := finish(Color(colors[2]), .19, .35 if sector == 3 else .90)
	var tread := ShaderMaterial.new()
	tread.shader = SURFACE
	tread.set_shader_parameter("terrain_albedo", surface)
	tread.set_shader_parameter("texture_scale", .47)
	tread.set_shader_parameter("reflected_light", .19)
	tread.set_shader_parameter("surface_tint", Color("d0c4bb").lerp(Color(colors[1]), .15))
	tread.set_shader_parameter("roughness", .68)
	tread.set_shader_parameter("grain_mix", .46 if sector in [2, 3, 5, 10] else .56)
	tread.set_shader_parameter("chassis_color", Color(colors[0]))
	if ice_coating:
		tread.set_shader_parameter("surface_tint", Color("9bd7ff"))
		tread.set_shader_parameter("metal", .38)
		tread.set_shader_parameter("roughness", .18)
		tread.set_shader_parameter("brightness", 1.5)
	if sector == 3 and not shaft:
		tread = preload("res://assets/campaign/frozen_reactor/kit/ice.tres") if ice_coating else preload("res://assets/campaign/frozen_reactor/kit/snow.tres")
	if shaft:
		build_shaft(tread, chassis, trim, lamp)
	else:
		build_deck(tread, chassis, trim, lamp, PANEL_TRIM.make(sector))
	var assembled := ArrayMesh.new()
	for material: Material in meshes:
		var batch: SurfaceTool = meshes[material]
		batch.index()
		batch.set_material(material)
		batch.commit(assembled)
	meshes.clear()
	return assembled

func build_shaft(surface_mat: Material, chassis: Material, trim: Material, lamp: Material) -> void:
	box(Vector3.ZERO, Vector3(.78,4.25,3.97), surface_mat, .087)
	for y in [-1.46,0.0,1.46]:
		box(Vector3(0,y,0), Vector3(.79,.20,3.98), chassis, .046)
		var slope := .35 if sector in [1, 6, 9] else -.32 if sector in [2, 3, 10] else 0.0
		for z in [-1.981,1.981]:
			box(Vector3(0,y,z), Vector3(.53,.52,.097), trim, .048, slope)
			for index in [-1,1]:
				box(Vector3(index*.071,y,z*1.044), Vector3(.036,.19,.04), lamp, .009, slope)

func build_deck(tread: Material, chassis: Material, trim: Material, lamp: Material, fascia: Material) -> void:
	box(Vector3(0,-0.49,0), Vector3(5.98,.60,4.78), chassis, .13)
	box(Vector3(0,-0.741,0), Vector3(5.84,.188,4.60), trim, .069)
	for i in 3:
		var x := (i - 1) * 1.97
		box(Vector3(x,-.097,0), Vector3(1.94,.194,4.72), tread, .064)
		for face in [-1, 1]:
			var z := float(face) * 2.372
			box(Vector3(x,-.473,z), Vector3(1.76,.39,.116), fascia, .049)
			add_fascia(x, z, face, trim, lamp)
			for side in [-1,1]:
				box(Vector3(x + side*.875,-.324,z*.999), Vector3(.14,.53,.142), trim, .040)
	for crossbeam in [-1.75,0.0,1.75]:
		box(Vector3(crossbeam,-.801,0), Vector3(.24,.069,4.51), chassis, .023)
	for stringer in [-1.36,1.36]:
		box(Vector3(0,-.799,stringer), Vector3(5.5,.075,.19), trim, .023)
	for face in [-1, 1]:
		for i in 6:
			var x := (i - 2.5) * .97
			var angle: float = [-.46, .31, -.22, .0, -.57, .46, .0, .26, -.62, .54][sector - 1] * (1 if i % 2 == 0 else -1)
			var accent_width := .92 if sector in [1, 4, 5, 8] else .52
			box(Vector3(x, -.686, face * 2.31), Vector3(accent_width,.11,.13), trim, .036, angle)

func add_fascia(x: float, z: float, face: int, trim: Material, light: Material) -> void:
	var at := Vector3(x,-.406,z + face * .05)
	match sector:
		1, 4, 8:
			var fins := 5 if sector == 1 else (3 if sector == 4 else 7)
			for i in fins:
				var dx := (float(i) - (fins - 1) * .5) * (1.18 / fins)
				box(at + Vector3(dx,.005,.0), Vector3(.084,.195,.097), trim, .022, -.26 if sector == 1 else 0.0)
			box(at + Vector3(0,-.109,0), Vector3(1.50,.037,.045), light, .012)
		2, 3, 10:
			for i in 4:
				var size := .13 + (i % 3) * .055
				box(at + Vector3((i-1.5)*.33,0,face*.018), Vector3(.106,size,.091), light if i % 3 == 1 else trim, .036, (i-1.5)*.33)
		5, 7:
			box(at, Vector3(1.19,.227,.083), trim, .047)
			for i in [-1,0,1]:
				box(at + Vector3(i*.29,.022,face*.06), Vector3(.16,.074,.032), light, .022, PI/4 if sector == 5 else 0.0)
		6, 9:
			for i in [-1,0,1]:
				box(at + Vector3(i*.33,0,0), Vector3(.23,.16,.075), light if i == 0 else trim, .031, -.44 if sector == 9 else .44)

func box(at: Vector3, size: Vector3, mat: Material, bevel: float, angle := 0.0) -> void:
	if not meshes.has(mat):
		var buffer := SurfaceTool.new()
		buffer.begin(Mesh.PRIMITIVE_TRIANGLES)
		meshes[mat] = buffer
	var shape := BoxMesh.new()
	shape.size = size
	meshes[mat].append_from(CHAMFER.from_box(shape, bevel), 0, Transform3D(Basis(Vector3.BACK, angle), at))

func finish(color: Color, metal: float, energy := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = .57
	material.metallic = metal
	if energy > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = energy
	return material
