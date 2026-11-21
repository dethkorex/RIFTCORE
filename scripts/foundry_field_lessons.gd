extends PanelContainer

const UI := preload("res://scripts/rift_ui.gd")
const PORTRAIT := preload("res://assets/ui/nova_portrait.png")
const SKIP_KEY := "foundry_field_tips_skipped"
# Bounds follow the actual forks and hazards. Passing a room never queues stale advice.
const LESSONS := [
	["intake", -12, 19, "Jump with {jump}. Tap {dash} midair if the far lip is just out of reach."],
	["combat", 19, 43, "{melee} draws your saber. Tap {shoot} to cut, or hold for sparks and release a wave. Hold {guard} to block from the front."],
	["fork", 43, 70, "See the broken gantry? There's a blueprint up top and a Patch Kit below. We need two relays to reach the Warden."],
	["cave", 70, 112, "Hold toward a cave wall as you fall, then press {jump} to kick off. A cable runs under the old locker. There must be a way down."],
	["slag", 113, 150, "Hear that rumble? Switch back to your buster with {melee} if needed. Three quick shots break a rolling boulder."],
	["pump", 202, 247, "The lower pump is still running. Step on its pressure plate. The inspection ladder is on the far side of the sluice."],
]

var hud: Control
var available: Callable
var body: Label
var remaining := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UI.theme()
	add_theme_stylebox_override("panel", UI.hud_frame(UI.VIOLET, Vector2(12, 6), true))
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	anchor_left = .22
	anchor_right = .78
	offset_left = 0
	offset_right = 0
	offset_top = -175
	offset_bottom = -84
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	var face := TextureRect.new()
	face.texture = PORTRAIT
	face.custom_minimum_size = Vector2(56, 56)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(face)
	var column := UI.column(row, 1)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.label(column, "NOVA   /   FIELD COMMS", 17, UI.VIOLET)
	body = UI.label(column, "", 21, UI.WHITE)
	var skip := UI.button(row, "Skip Act I tips", skip_tips, false, 28)
	skip.focus_mode = Control.FOCUS_NONE
	skip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hide()

func skip_tips() -> void:
	RiftSettings.claim_story_beat(SKIP_KEY)
	hide()
	set_process(false)

func _process(delta: float) -> void:
	if not RiftSettings.show_hub_tips or SKIP_KEY in RiftSettings.seen_story_beats:
		hide()
		return
	var operator := hud.local_operator as RiftPlayer
	if not is_instance_valid(operator) or not operator.is_physics_processing() or operator.controls_suspended or not operator.is_visible_in_tree() or operator.health <= 0 or not available.call():
		hide()
		return
	if remaining > 0.0:
		remaining -= delta
		visible = remaining > 0.0
		return
	for lesson: Array in LESSONS:
		if operator.position.x < lesson[1] or operator.position.x >= lesson[2]:
			continue
		var key := "foundry_field_" + String(lesson[0])
		if key in RiftSettings.seen_story_beats:
			return
		var device := "key" if Input.get_connected_joypads().is_empty() else "pad"
		var message := String(lesson[3])
		for action in ["jump", "dash", "shoot", "melee", "guard"]:
			if message.contains("{" + action + "}"):
				message = message.replace("{" + action + "}", RiftSettings.binding_label(action, device))
		body.text = message
		remaining = clampf(message.length() / 15.0, 5.5, 9.0)
		RiftSettings.claim_story_beat(key)
		show()
		return
