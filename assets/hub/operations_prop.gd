@tool
extends Node3D

const Chamfer := preload("res://scripts/factory_chamfer.gd")
const Face := preload("res://assets/ui/fonts/BarlowCondensed-ExtraBoldItalic.ttf")
const IconDirectory := "res://assets/ui/riftcore_kit/"

@export_enum("Terminal", "Deploy", "Window", "Deck", "Banner") var kind := 0:
	set(value):
		kind = value
		refresh()
@export var caption := "TERMINAL":
	set(value):
		caption = value
		refresh()
@export var accent := Color("48e2ff"):
	set(value):
		accent = value
		refresh()
@export var icon := "icon_gear":
	set(value):
		icon = value
		refresh()
@export_enum("Console", "Trader", "Forge", "Storage", "Loadout") var layout := 0:
	set(value):
		layout = value
		refresh()

var geometry: Node3D
var queued := false
var alloy: StandardMaterial3D
var dark: StandardMaterial3D
var steel: StandardMaterial3D
var lit: StandardMaterial3D

func _ready() -> void:
	refresh()

func refresh() -> void:
	if not is_inside_tree() or queued:
		return
	queued = true
	build.call_deferred()

func build() -> void:
	queued = false
	if not is_inside_tree():
		return
	if geometry:
		remove_child(geometry)
		geometry.queue_free()
	geometry = Node3D.new()
	geometry.name = "Geometry"
	add_child(geometry)
	alloy = finish(Color("263550"), 0.0, 0.69)
	dark = finish(Color("11192c"), 0.0, 0.44)
	steel = finish(Color("4c5e7a"), 0.0, 0.73)
	lit = finish(accent, 1.45, 0.12)
	match kind:
		0: terminal()
		1: deploy()
		2: window_frame()
		3: deck()
		4: banner()

func finish(color: Color, emission: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.4
	material.metallic = metallic
	material.emission_enabled = emission > 0.0
	material.emission = color
	material.emission_energy_multiplier = emission
	return material

func part(mesh: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.mesh = mesh
	item.position = at
	item.material_override = material
	geometry.add_child(item)
	return item

func plate(at: Vector3, dimensions: Vector3, material: Material, bevel := 0.06) -> MeshInstance3D:
	var source := BoxMesh.new()
	source.size = dimensions
	return part(Chamfer.from_box(source, bevel), at, material)

func strut(start: Vector3, end: Vector3, width: float, material: Material) -> void:
	var difference := end - start
	var beam := plate((start + end) * 0.5, Vector3(width, difference.length(), width), material)
	beam.quaternion = Quaternion(Vector3.UP, difference.normalized())

func cylinder(at: Vector3, top: float, bottom: float, height: float, material: Material, sides := 12) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = sides
	part(mesh, at, material)

func sign_text(at: Vector3, value: String, text_size: int) -> void:
	var label := Label3D.new()
	label.text = value
	label.font = Face
	label.font_size = text_size
	label.pixel_size = 0.005
	label.modulate = accent.lerp(Color.WHITE, 0.44)
	label.outline_size = 8
	label.position = at
	geometry.add_child(label)

func badge(at: Vector3, name: String, size: float) -> void:
	var sprite := Sprite3D.new()
	sprite.texture = load(IconDirectory + name + ".png") as Texture2D
	sprite.pixel_size = size / sprite.texture.get_width()
	sprite.position = at
	sprite.modulate = accent.lerp(Color.WHITE, 0.24)
	geometry.add_child(sprite)

func terminal() -> void:
	plate(Vector3(0, 0.10, 0), Vector3(2.98, 0.2, 1.16), dark)
	plate(Vector3(0, 1.04, -0.37), Vector3(2.77, 2.04, 0.33), dark)
	plate(Vector3(0, 0.97, -0.17), Vector3(2.2, 1.66, 0.10), alloy)
	for side in [-1.0, 1.0]:
		plate(Vector3(side * 1.28, 1.0, 0), Vector3(0.35, 1.85, 0.63), alloy, 0.09)
		plate(Vector3(side * 1.28, 1.49, 0.335), Vector3(0.12, 0.46, 0.035), lit, 0.01)
		strut(Vector3(side * 1.35, 1.6, 0), Vector3(side * 0.96, 2.12, 0), 0.31, steel)
		plate(Vector3(side * 1.31, 0.19, 0.15), Vector3(0.44, 0.29, 0.7), steel)
	plate(Vector3(0, 2.01, 0.19), Vector3(2.91, 0.51, 0.52), steel, 0.13)
	plate(Vector3(0, 2.02, 0.476), Vector3(2.55, 0.33, 0.055), dark, 0.02)
	plate(Vector3(0, 1.83, 0.49), Vector3(2.35, 0.029, 0.025), lit, 0.01)
	badge(Vector3(-1.04, 2.02, 0.525), icon, 0.24)
	sign_text(Vector3(0.13, 2.02, 0.52), caption, 36)
	match layout:
		1:
			for row in range(3):
				for shelf_item in range(5):
					plate(Vector3(-0.87 + shelf_item * 0.19, 0.53 + row * 0.31, 0.15), Vector3(0.12, 0.21, 0.18), steel if shelf_item % 2 == 0 else alloy)
				plate(Vector3(-0.51, 0.41 + row * 0.31, 0.2), Vector3(1.01, 0.06, 0.47), dark)
			screen(0.55, 1.14, 0.81)
		2:
			var anchor := Vector3(-0.73, 0.64, 0.36)
			var elbow := Vector3(-0.52, 1.47, 0.37)
			var tool := Vector3(0.16, 1.24, 0.4)
			strut(anchor, elbow, 0.19, steel)
			strut(elbow, tool, 0.16, lit)
			plate(tool, Vector3(0.24, 0.20, 0.28), dark)
			plate(Vector3(0, 0.66, 0.39), Vector3(1.03, 0.14, 0.65), steel)
			screen(0.71, 1.07, 0.66)
		3:
			for at in [Vector3(-0.63, 0.39, 0.37), Vector3(-0.6, 0.9, 0.22), Vector3(0.65, 0.32, 0.42)]:
				plate(at, Vector3(0.91, 0.48, 0.67), steel)
				plate(at + Vector3(0, 0.14, 0.352), Vector3(0.47, 0.065, 0.03), lit, 0.01)
			screen(0.6, 1.16, 0.85)
		4:
			screen(-0.57, 1.11, 0.83)
			screen(0.59, 1.11, 0.83)
			plate(Vector3(0, 0.64, 0.42), Vector3(2.1, 0.15, 0.64), steel)
		_:
			screen(0, 1.13, 1.39)
			plate(Vector3(0, 0.62, 0.46), Vector3(1.4, 0.15, 0.58), steel)
	for position_x in [-1.2, 1.2]:
		plate(Vector3(position_x, 0.28, 0.49), Vector3(0.19, 0.07, 0.028), lit, 0.01)

func screen(x: float, y: float, width: float) -> void:
	plate(Vector3(x, y, 0.15), Vector3(width, 0.53, 0.17), steel)
	plate(Vector3(x, y, 0.248), Vector3(width - 0.10, 0.42, 0.035), dark, 0.02)
	badge(Vector3(x, y, 0.276), icon, 0.31)
	for row in range(3):
		plate(Vector3(x - width * 0.32, y - 0.13 + row * 0.065, 0.278), Vector3(width * 0.12, 0.016, 0.012), lit, 0.002)

func deploy() -> void:
	cylinder(Vector3(0, 0.075, 0), 1.49, 1.64, 0.15, steel, 12)
	cylinder(Vector3(0, 0.15, 0), 1.41, 1.41, 0.035, lit, 32)
	cylinder(Vector3(0, 0.185, 0), 1.27, 1.35, 0.095, dark, 12)
	cylinder(Vector3(0, 0.24, 0), 0.95, 0.95, 0.025, alloy, 24)
	var ring := TorusMesh.new()
	ring.inner_radius = 1.03
	ring.outer_radius = 1.10
	part(ring, Vector3(0, 0.247, 0), lit)
	for side in [-1.0, 1.0]:
		plate(Vector3(side * 1.02, 0.13, 1.04), Vector3(0.35, 0.12, 0.28), lit)
	sign_text(Vector3(0, 0.17, 1.58), caption, 41)

func window_frame() -> void:
	for side in [-1.0, 1.0]:
		plate(Vector3(side * 2.25, 2.25, 0), Vector3(0.26, 4.5, 0.48), alloy)
		plate(Vector3(side * 2.25, 2.69, 0.255), Vector3(0.08, 1.05, 0.035), lit, 0.015)
		strut(Vector3(side * 2.23, 3.46, 0), Vector3(side * 1.54, 4.12, 0), 0.24, steel)
	plate(Vector3(0, 4.13, 0), Vector3(4.56, 0.48, 0.72), alloy, 0.12)
	plate(Vector3(0, 4.02, 0.38), Vector3(2.67, 0.05, 0.05), lit)
	plate(Vector3(0, 0.67, 0), Vector3(4.49, 0.11, 0.20), steel)
	for x in [-1.5, -0.5, 0.5, 1.5]:
		plate(Vector3(x, 0.42, 0), Vector3(0.065, 0.54, 0.14), alloy)

func deck() -> void:
	plate(Vector3(0, -0.235, 0), Vector3(4.48, 0.44, 4.55), dark, 0.12)
	for column in [-1, 0, 1]:
		for row in [-1, 0, 1]:
			plate(Vector3(column * 1.47, -0.065, row * 1.49), Vector3(1.43, 0.12, 1.45), alloy, 0.038)
		plate(Vector3(column * 1.46, -0.23, 2.30), Vector3(1.35, 0.23, 0.17), steel)
		plate(Vector3(column * 1.46, -0.23, 2.40), Vector3(0.83, 0.06, 0.035), lit)
	for edge in [-1, 1]:
		strut(Vector3(edge * 2.09, -0.42, 2.1), Vector3(edge * 1.13, -1.14, 2.1), 0.18, alloy)

func banner() -> void:
	plate(Vector3.ZERO, Vector3(4.6, 0.87, 0.26), steel, 0.15)
	plate(Vector3(0, 0.02, 0.16), Vector3(4.29, 0.61, 0.08), dark)
	var mark := Sprite3D.new()
	mark.texture = preload("res://assets/ui/riftcore-wordmark.svg")
	mark.pixel_size = 3.14 / mark.texture.get_width()
	mark.position = Vector3(0, 0.13, 0.22)
	geometry.add_child(mark)
	sign_text(Vector3(0, -0.23, 0.22), caption, 35)
	plate(Vector3(0, -0.40, 0.20), Vector3(2.93, 0.045, 0.06), lit, 0.01)
