extends Node3D

const COMPLETE := 3
const TERMINAL := preload("res://assets/neon_factory/gate_relay_terminal.tscn")
const STATIONS := ["TERRAIN/MidpointCheckpoint", "TERRAIN/ForgeHallCheckpoint"]

var active: int
var terminals: Array[Node3D] = []
var prompts: Array[Label3D] = []
var door_prompt: Label3D
var lit: StandardMaterial3D
var service_return := true

func install(stage: Node3D, tint: Color, allow_service_return := true) -> void:
	name = "GateRelays"
	service_return = allow_service_return
	stage.add_child(self)
	lit = RiftProjectile.light_paint(Color("68ffb3"), 1.45)
	for index in STATIONS.size():
		var terminal := TERMINAL.instantiate() as Node3D
		var station := stage.get_node(STATIONS[index]) as Node3D
		var position_marker := stage.get_node_or_null("MARKERS/GateRelay" + str(index + 1)) as Marker3D
		var ground := position_marker if position_marker else station
		add_child(terminal)
		terminal.global_position = ground.global_position
		var socket := terminal.get_node("Signal") as MeshInstance3D
		socket.material_override = RiftProjectile.light_paint(tint, 1.25)
		var title := make_label(terminal, Vector3(0, 2.26, -0.5), 0.0054)
		title.text = "GATE RELAY " + ("A" if index == 0 else "B")
		title.show()
		var prompt := make_label(terminal, Vector3(0, 1.97, -0.49), 0.0047)
		terminals.append(terminal)
		prompts.append(prompt)
	var portal := stage.get_node("Gate") as Node3D
	door_prompt = make_label(self, Vector3.ZERO, 0.006)
	door_prompt.no_depth_test = true
	door_prompt.global_position = portal.global_position + Vector3(-2.65, 2.85, 0.85)

func make_label(parent: Node3D, at: Vector3, size: float) -> Label3D:
	var label := Label3D.new()
	label.font_size = 54
	label.font = preload("res://assets/ui/fonts/BarlowCondensed-ExtraBoldItalic.ttf")
	label.pixel_size = size
	label.outline_size = 12
	label.outline_modulate = Color("081222")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = at
	label.hide()
	parent.add_child(label)
	return label

func count() -> int:
	return int((active & 1) != 0) + int((active & 2) != 0)

func complete() -> bool:
	return active == COMPLETE

func set_active(flags: int) -> void:
	var next := flags & COMPLETE
	if active == next:
		return
	for index in terminals.size():
		var bit := 1 << index
		if (active & bit) == (next & bit):
			continue
		var socket := terminals[index].get_node("Signal") as MeshInstance3D
		if next & bit:
			socket.set_meta("off_material", socket.material_override)
			socket.material_override = lit
		else:
			socket.material_override = socket.get_meta("off_material")
	active = next

func is_near(operator: RiftPlayer, terminal: Node3D) -> bool:
	var offset := operator.global_position - terminal.global_position
	var feet := offset.y - operator.standing_capsule.height * 0.5
	return absf(offset.x) <= 1.58 and absf(feet) <= 0.85 and absf(offset.z) < 0.85

func update_prompt(operator: RiftPlayer, at_gate: bool) -> void:
	var interact := ""
	for index in terminals.size():
		var near := is_near(operator, terminals[index])
		var active_relay := (active & (1 << index)) != 0
		var prompt := prompts[index]
		prompt.visible = near and not active_relay
		if prompt.visible:
			interact = interact if not interact.is_empty() else interaction_binding()
			prompt.text = "%s  ·  ACTIVATE" % interact
	door_prompt.visible = at_gate and not complete()
	if door_prompt.visible:
		var missing := "FIND BOTH RELAYS" if count() == 0 else ("FIND RELAY B" if active == 1 else "FIND RELAY A")
		if service_return:
			interact = interact if not interact.is_empty() else interaction_binding()
			missing = "%s  ·  RETURN TO MISSING RELAY" % interact
		door_prompt.text = "DOOR LOCKED  ·  GATE RELAYS %d/2\n%s" % [count(), missing]

func interaction_binding() -> String:
	return "%s / %s" % [RiftSettings.binding_label("field_interact", "key"), RiftSettings.binding_label("field_interact", "pad")]

# Returns true when the switch or the gate's service return used the input.
func interact(operator: RiftPlayer, at_gate: bool) -> bool:
	if complete() or operator.health <= 0.0 or operator.controls_suspended:
		return false
	for index in terminals.size():
		var bit := 1 << index
		if (active & bit) == 0 and is_near(operator, terminals[index]):
			set_active(active | bit)
			RiftAudio.play_effect(&"checkpoint")
			return true
	if at_gate and service_return:
		var missing := 0 if (active & 1) == 0 else 1
		operator.cancel_charge()
		operator.velocity = Vector3.ZERO
		operator.global_position = terminals[missing].global_position + Vector3.UP * (operator.standing_capsule.height * 0.5 + 0.08)
		return true
	return false
