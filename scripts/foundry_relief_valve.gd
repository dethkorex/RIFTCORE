extends Node3D

const VALVE_BODY := preload("res://assets/neon_factory/foundry/purge_valve_body.tscn")
const READY_TINT := Color("2ccce3")

var prompt: Label3D
var wheel: MeshInstance3D
var lamp: MeshInstance3D
var ready_to_turn := false

func _ready() -> void:
	var panel := Node3D.new()
	panel.position.z = -1.15
	add_child(panel)
	panel.add_child(VALVE_BODY.instantiate())
	var steel := RiftProjectile.light_paint(Color("3d2731"), 0.0)
	var ring := TorusMesh.new()
	ring.inner_radius = .24
	ring.outer_radius = .37
	wheel = RiftProjectile.part(panel, ring, steel, Vector3(0, 0, .25), Vector3.ONE)
	wheel.rotation.x = PI * .5
	for index in 3:
		var angle := index * TAU / 3.0
		var handle := BoxMesh.new()
		var spoke := RiftProjectile.part(wheel, handle, steel, Vector3(sin(angle), 0, cos(angle)) * .14, Vector3(.072, .06, .26))
		spoke.rotation.y = angle
	lamp = RiftProjectile.part(panel, RiftProjectile.cached_mesh("Orb"), steel, Vector3(0, 0, .41), Vector3.ONE * .105)
	prompt = Label3D.new()
	prompt.font = preload("res://assets/ui/fonts/BarlowCondensed-ExtraBoldItalic.ttf")
	prompt.font_size = 60
	prompt.pixel_size = .0051
	prompt.outline_size = 14
	prompt.outline_modulate = Color("060e18")
	prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prompt.position = Vector3(0, .88, .13)
	panel.add_child(prompt)
	show_target(false)

func operator_can_reach(operator: RiftPlayer) -> bool:
	var offset := operator.global_position - global_position
	return operator.health > 0.0 and not operator.controls_suspended and absf(offset.x) <= 1.45 and absf(offset.y) <= .92 and absf(offset.z) <= 1.55

func present(enabled: bool, turn_progress: float) -> void:
	if enabled != ready_to_turn:
		ready_to_turn = enabled
		show_target(enabled)
	var turn := clampf(turn_progress, 0.0, 1.0) * 2.05
	wheel.basis = Basis(Vector3.RIGHT, PI * .5) * Basis(Vector3.UP, turn)

func show_target(enabled: bool) -> void:
	var paint := RiftProjectile.light_paint(READY_TINT if enabled else Color("967550"), .85 if enabled else .08)
	var key := RiftSettings.binding_label("field_interact", "key")
	var pad := RiftSettings.binding_label("field_interact", "pad")
	prompt.text = "%s / %s  ·  TURN VALVE" % [key, pad] if enabled else "PURGE VALVE"
	prompt.modulate = Color("b6f9ff") if enabled else Color("a1b5c4")
	wheel.material_override = paint
	lamp.material_override = paint
