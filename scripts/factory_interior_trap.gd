@tool
extends Area3D

const VFX := preload("res://scripts/factory_trap_vfx.gd")
enum Kind { DRILL, LASER, PRESS }
const HARDWARE := [
	preload("res://assets/neon_factory/interiors/drill_trap.glb"),
	preload("res://assets/neon_factory/interiors/laser_trap.glb"),
	preload("res://assets/neon_factory/interiors/press_trap.glb"),
]
const PERIOD := 4.8
const WARNING := 2.45
const ACTIVATE := 3.40
const RETRACT := 4.27

@export var kind: Kind
@export var offset := 0.0

var hazard: Node3D
var collar: MeshInstance3D
var indicator: Label3D
var rotor: Node3D
var clock := 0.0
var struck: Dictionary = {}
var active_last_tick := false
var phase_time: Callable
var last_display := -1

func _ready() -> void:
	add_to_group(&"factory_interior_trap")
	clock = offset
	var width := float([1.20, 0.48, 2.6][kind])
	var height := float([0.84, 2.40, 1.64][kind])
	var zone := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, height, 1.5)
	zone.shape = box
	zone.position.y = height * 0.5
	add_child(zone)
	add_child(HARDWARE[kind].instantiate())
	collar = part(self, Vector3(width * 0.73, 0.035, 0.055), Vector3(0, 0.157, 0.81), Color("343c4a"))
	indicator = Label3D.new()
	indicator.position = Vector3(0, 0.37, 0.92)
	indicator.pixel_size = 0.0045
	indicator.font_size = 28
	indicator.outline_size = 8
	add_child(indicator)
	if kind == Kind.DRILL:
		hazard = VFX.make_spikes()
		hazard.scale = Vector3(0.90, 1.55, 0.90)
		rotor = hazard.find_child("DrillRotor", true, false) as Node3D
	elif kind == Kind.LASER:
		hazard = preload("res://scripts/factory_laser_column.gd").new()
	else:
		hazard = Node3D.new()
		part(hazard, Vector3(2.58, 0.88, 1.68), Vector3.ZERO, Color("515969"))
		part(hazard, Vector3(2.44, 0.20, 0.09), Vector3(0, -0.26, 0.87), Color("f3a22b"), 0.48)
	add_child(hazard)
	update_display(false, false)
	set_physics_process(not Engine.is_editor_hint())

func part(parent: Node3D, dimensions: Vector3, coordinates: Vector3, tint: Color, emission := 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	return RiftProjectile.part(parent, mesh, RiftProjectile.light_paint(tint, emission), coordinates, Vector3.ONE)

func _physics_process(delta: float) -> void:
	clock = fposmod(float(phase_time.call()) + offset if phase_time.is_valid() else clock + delta, PERIOD)
	var active := clock >= ACTIVATE and clock < RETRACT
	var warning := clock >= WARNING and clock < ACTIVATE
	if active and rotor:
		rotor.rotate_z(delta * 27)
	if active and not active_last_tick:
		VFX.throw_sparks(self, Color("ff5560"), 0.90)
	active_last_tick = active
	update_display(active, warning)
	if not active:
		struck.clear()
		return
	for body in get_overlapping_bodies():
		if body is RiftPlayer and body.health > 0 and not struck.has(body.get_instance_id()):
			struck[body.get_instance_id()] = true
			body.take_projectile_damage(14.0 if kind != Kind.PRESS else 22.0)

func update_display(active: bool, warning: bool) -> void:
	var state := 2 if active else (1 if warning else 0)
	if last_display == state:
		return
	last_display = state
	var tint := Color("ff526b") if active else (Color("ffc251") if warning else Color("6abbc8"))
	collar.material_override = RiftProjectile.light_paint(tint, 1.5 if active or warning else 0.26)
	indicator.modulate = tint
	var title: String = ["DRILL", "LASER", "PRESS"][kind]
	indicator.text = title + ("  /  ACTIVE" if active else ("  /  CLEAR ZONE" if warning else ""))
	if kind == Kind.LASER:
		hazard.show_phase(state)
	elif kind == Kind.PRESS:
		hazard.position.y = 1.18 if active else (2.35 if warning else 2.83)
	else:
		hazard.visible = active
