@tool
extends Node3D

const Chamfer := preload("res://scripts/factory_chamfer.gd")
const PALETTES := {
	"foundry": ["2d2824", "a26d4b", "160e0c", "ff8d36"], "jungle": ["313d2d", "678b48", "162319", "b5ed55"],
	"cryo": ["536d85", "abcfdf", "26394d", "83edff"], "pressure": ["264449", "619993", "132c35", "54ede8"],
	"archive": ["614935", "b99a63", "302422", "ffd17f"], "flight": ["323f64", "8394b4", "181f38", "76c8ff"],
	"lab": ["415042", "97a17b", "172b1d", "dcf36d"], "orbital": ["342f63", "8c86ad", "16182c", "aa89ff"],
	"scrap": ["47342a", "a66b43", "2c2320", "ff9c56"], "rift": ["3a203e", "946294", "281020", "ff70eb"],
}
@export_enum("foundry", "jungle", "cryo", "pressure", "archive", "flight", "lab", "orbital", "scrap", "rift") var style := "foundry"
@export var sealed := false
@export var boss_entry := false
@export var width := 3.75
@export var height := 4.22
@export var trim_texture: Texture2D

var shell: Material
var trim: Material
var recess: Material
var signal_light: Material

func _ready() -> void:
	var colors: Array = PALETTES[style]
	shell = finish(colors[0], 0.46)
	if trim_texture:
		var surface := ShaderMaterial.new()
		surface.shader = preload("res://assets/campaign/sector_surface.gdshader")
		surface.set_shader_parameter("terrain_albedo", trim_texture)
		surface.set_shader_parameter("texture_scale", .42)
		surface.set_shader_parameter("reflected_light", .24)
		surface.set_shader_parameter("roughness", .56)
		surface.set_shader_parameter("metal", .30)
		shell = surface
	trim = finish(colors[1], 0.50)
	recess = finish(colors[2], 0.25)
	signal_light = finish(colors[3], 0.12)
	signal_light.emission_enabled = true
	signal_light.emission = Color(colors[3])
	signal_light.emission_energy_multiplier = 1.8
	if sealed:
		build_shutter()
	else:
		build_frame()
		if boss_entry:
			build_lock_frame()

func finish(hex: String, metal: float, image: Texture2D = null) -> StandardMaterial3D:
	var surface := StandardMaterial3D.new()
	surface.albedo_color = Color(hex)
	surface.roughness = 0.56
	surface.metallic = metal
	if image:
		surface.albedo_texture = image
		surface.uv1_triplanar = true
		surface.uv1_scale = Vector3.ONE * 0.8
	return surface

func slab(label: String, at: Vector3, dimensions: Vector3, surface: Material, bevel := 0.047) -> MeshInstance3D:
	var source := BoxMesh.new()
	source.size = dimensions
	var piece := MeshInstance3D.new()
	piece.name = label
	piece.mesh = Chamfer.from_box(source, bevel)
	piece.material_override = surface
	piece.position = at
	add_child(piece, true)
	return piece

func bar(label: String, start: Vector3, end: Vector3, gauge: float, depth: float, surface: Material) -> void:
	var length := start.distance_to(end)
	var piece := slab(label, (start + end) * 0.5, Vector3(gauge, length + 0.04, depth), surface, gauge * 0.18)
	piece.rotation.z = atan2(start.x - end.x, end.y - start.y)

func build_frame() -> void:
	var half := width * 0.5
	var leg := width * 0.108
	var crown := height * 0.105
	var x := half - leg * 0.52
	for side in [-1, 1]:
		slab("Jamb", Vector3(side * x, height * 0.48, 0), Vector3(leg, height * 0.96, 0.64), shell)
		slab("Foot cap", Vector3(side * x, height * 0.05, 0), Vector3(leg * 1.14, height * 0.10, 0.83), trim)
		slab("Head cap", Vector3(side * x, height - crown * 0.63, 0), Vector3(leg * 1.11, crown * 1.26, 0.82), trim)
		for face in [-1, 1]:
			var z: float = face * 0.347
			bar("Corner brace", Vector3(side * x, height * 0.77, z), Vector3(side * x * 0.69, height - crown * 0.5, z), leg * 0.62, 0.21, shell)
			bar("Jamb signal", Vector3(side * x, height * 0.27, z), Vector3(side * x, height * 0.69, z), 0.052, 0.035, signal_light)
		for step in range(3):
			slab("Fastener collar", Vector3(side * x, height * (0.19 + 0.21 * step), 0), Vector3(leg * 1.12, .095, .73), trim)
		signature(Vector3(side * x, height * 0.51, 0.08), side)
	slab("Lintel", Vector3(0, height - crown * 0.49, 0), Vector3(width * 0.97, crown, 0.71), shell)
	for z in [-0.37, 0.37]:
		slab("Lintel signal", Vector3(0, height - crown * 0.69, z), Vector3(width * 0.43, 0.050, 0.045), signal_light)

func build_lock_frame() -> void:
	# The motor stays above the swept opening. All depth hardware is visual.
	var crown := height - .19
	slab("Blast lock cassette", Vector3(0,crown,0), Vector3(width * 0.78,.55,1.15), recess, .18)
	for side in [-1,1]:
		var x := float(side) * width * .39
		slab("Load-bearing corner armor", Vector3(x,crown-.13,0), Vector3(.59,.65,1.27), trim, .13)
		var a := Vector3(x,crown-.05,.63)
		var b := Vector3(x*.60,crown-.05,.63)
		bar("Lock status rail", a, b, .067, .051, signal_light)
		slab("Jamb actuator", Vector3(side*width*.438,height*.55,0), Vector3(.32,height*.55,.95), shell, .092)

func build_shutter() -> void:
	var panel_w := width * 0.495
	slab("Pressure backing", Vector3(0,height * 0.49,0), Vector3(width * 0.965,height * 0.98,0.41), recess)
	for side in [-1, 1]:
		var x: float = panel_w * 0.5 * side
		slab("Armored leaf", Vector3(x,height * 0.49,0.03), Vector3(panel_w * 0.97,height * 0.96,0.56), shell, .093)
		for row in range(3):
			var y := height * (0.22 + 0.28 * row)
			slab("Recessed panel", Vector3(x,y,0.315), Vector3(panel_w * 0.80,height * 0.204,0.105), recess)
			var armor := slab("Raised armor bevel", Vector3(x,y - .030,0.378),
				Vector3(panel_w * 0.67,height * 0.143,0.075), shell if trim_texture else trim, .092)
			if boss_entry:
				armor.rotation.z = side * 0.095
			for face in [-1, 1]:
				slab("Interlock tooth", Vector3(x,y,float(face)*.28), Vector3(panel_w*.73,.083,.17), trim, .032)
			slab("Lock indicator", Vector3(side * .13,y,0.386), Vector3(.068,height * 0.083,0.036), signal_light)
		signature(Vector3(x,height * 0.51,0.39), side)
		slab("Edge lock", Vector3(side * (width * 0.48),height * 0.46,0.02), Vector3(.18,height * 0.59,.59), trim)
	for edge in [-1, 1]:
		slab("Door clearance stripe", Vector3(0,height*.80,float(edge)*.273),
			Vector3(width*.90,.062,.073), signal_light, .014)

func signature(at: Vector3, side: int) -> void:
	match style:
		"foundry", "scrap":
			var angle := 0.56 * side if style == "foundry" else -0.40 * side
			var count := 4 if style == "foundry" else 3
			for index in count:
				var rung := slab("Heat fin" if style == "foundry" else "Welded splint",
					at + Vector3(0, (index - 1.5) * 0.19, 0.39), Vector3(.26,.105,.16), trim, .024)
				rung.rotation.z = angle
		"jungle":
			var root := at + Vector3(0, -.46, .36)
			var fork := at + Vector3(side * 0.12, .17, .39)
			bar("Root braid", root, fork, .21, .18, trim)
			bar("New growth", fork, at + Vector3(-side*.16,.54,.43), .14,.12, shell)
			bar("Growth seam", fork, at + Vector3(side*.18,.54,.45), .042,.047, signal_light)
		"cryo":
			for index in 3:
				var tooth := slab("Cryo crystal", at + Vector3(0, -.20 + index*.23, .35), Vector3(.18,.33,.21), trim, .062)
				tooth.rotation.z = (index - 1) * side * .31
		"pressure", "lab":
			var coil := TorusMesh.new()
			coil.inner_radius = .13
			coil.outer_radius = .22
			coil.rings = 16
			coil.ring_segments = 8
			var ring := MeshInstance3D.new()
			ring.name = "Inspection ring" if style == "pressure" else "Sample clamp"
			ring.mesh = coil
			ring.position = at + Vector3(0,0,.38)
			ring.rotation.x = PI * 0.5
			ring.material_override = trim
			add_child(ring, true)
			slab("Sealed indicator", ring.position + Vector3(0, 0, .11), Vector3(.16,.16,.055), signal_light, .034)
			if style == "lab":
				bar("Sample tube", at + Vector3(0,-.53,.41),at + Vector3(0,.54,.41), .079,.09,signal_light)
		"archive", "orbital", "rift":
			var tally := 3 if style == "rift" else (2 if style == "archive" else 4)
			for index in tally:
				var inset := slab("Phase inset", at + Vector3(0,(index - (tally - 1) * .5)*.19,.32),
					Vector3(0.19, 0.13, 0.10), signal_light, .042)
				inset.rotation.z = side * (0.43 if style == "archive" else 0.79)
		"flight":
			for index in 3:
				bar("Runway chevron", at + Vector3(-.15,index*.19-.26,.33),
					at + Vector3(.15,index*.19-.12,.33), .062, .08, signal_light)
