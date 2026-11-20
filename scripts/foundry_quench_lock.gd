extends Node3D

const VFX := preload("res://scripts/factory_trap_vfx.gd")
const PRESS := preload("res://assets/neon_factory/foundry/quench_press.tscn")
const CHAMFER := preload("res://scripts/factory_chamfer.gd")
const FONT := preload("res://assets/ui/fonts/BarlowCondensed-ExtraBoldItalic.ttf")
enum State { READY, ARMED, CLAMPED }

var state := State.READY
var lamp: MeshInstance3D
var rails: Array[MeshInstance3D] = []
var piston: Node3D
var label: Label3D

func _ready() -> void:
	add_child(PRESS.instantiate())
	var steel := RiftProjectile.light_paint(Color("302a31"), 0)
	var copper := RiftProjectile.light_paint(Color("8d5541"), 0)
	box(self, Vector3(1.44, 2.15, 0.52), Vector3(0, 1.08, -1.78), steel, 0.105)
	box(self, Vector3(1.60, 0.26, 0.58), Vector3(0, 2.13, -1.72), copper, 0.07)
	box(self, Vector3(1.37, 0.21, 0.68), Vector3(0, 0.15, -1.64), copper, 0.055)
	box(self, Vector3(0.66, 1.64, 0.16), Vector3(0, 1.14, -1.46), steel, 0.052)
	box(self, Vector3(0.78, 0.045, 2.9), Vector3(0, 0.028, 0.20), steel)
	for side in [-1.0, 1.0]:
		rails.append(box(self, Vector3(0.13, 0.028, 2.66), Vector3(side * 0.29, 0.07, 0.22), steel))
	piston = Node3D.new()
	add_child(piston)
	piston.position.z = -1.42
	box(piston, Vector3(0.34, 0.57, 0.22), Vector3(0, 0.04, 0), copper)
	for side in [-1.0, 1.0]:
		var jaw := box(piston, Vector3(.24, .55, .36), Vector3(side * .26, -.11, .06), copper, .05)
		jaw.rotation.z = side * .31
	lamp = box(piston, Vector3(0.41, 0.20, 0.14), Vector3(0, -0.02, 0.14), steel)
	label = Label3D.new()
	label.font = FONT
	label.font_size = 60
	label.pixel_size = 0.005
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 14
	label.outline_modulate = Color("060e18")
	label.position = Vector3(0, 2.49, -1.35)
	add_child(label)
	show_target(state)

func box(parent: Node3D, dimensions: Vector3, at: Vector3, paint: Material, bevel := 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	return RiftProjectile.part(parent, CHAMFER.from_box(mesh, bevel) if bevel > 0.0 else mesh, paint, at, Vector3.ONE)

func set_state(next: State) -> void:
	if next == state:
		return
	state = next
	show_target(state)
	if state == State.CLAMPED:
		VFX.impact(piston, 2.5)
		RiftAudio.foundry_sound(&"fire_jet", global_position)

func show_target(display_state: State) -> void:
	var tint: Color = [Color("65dcff"), Color("ffb246"), Color("91ffe7")][display_state]
	var paint := RiftProjectile.light_paint(tint, 0.6 if display_state == State.READY else 2.2)
	lamp.material_override = paint
	for rail in rails:
		rail.material_override = paint
	piston.position.y = 0.46 if display_state == State.CLAMPED else 1.02
	label.modulate = tint
	label.text = ["QUENCH LOCK", "▼  CHARGE TARGET", "DRILL CAUGHT"][display_state]
