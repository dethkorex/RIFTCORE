extends CanvasLayer

signal selected(id: String)

const UI := preload("res://scripts/rift_ui.gd")
const TERMINAL := NodePath("TERRAIN/FieldModuleTerminal")
const MODULES := {
	"deflector": ["Saber Deflector", "Time a saber swing to send enemy shots back and recover 5 energy."],
	"prism": ["Buster Prism", "A charged standard Buster shot splits into two fragments on its first hit."],
	"conduit": ["Charge Conduit", "Charged suit weapons use 25% less energy."],
	"slipstream": ["Slipstream Capacitor", "Evade one projectile in the opening instant of a dash and recover 4 energy."],
}
const EARLY_OPTIONS := ["deflector", "prism", "slipstream"]
const WARDEN_OPTIONS := ["deflector", "prism", "conduit"]

static func at_terminal(stage: Node3D, operator: RiftPlayer) -> bool:
	var terminal := stage.get_node_or_null(TERMINAL) as Node3D
	if terminal == null or operator.health <= 0.0 or not operator.run_module.is_empty():
		return false
	var offset := operator.global_position - terminal.global_position
	var feet := offset.y - operator.standing_capsule.height * 0.5
	return absf(offset.x) <= 1.65 and absf(feet) <= 0.85 and absf(offset.z) < 0.85

static func update_prompt(stage: Node3D, operator: RiftPlayer) -> void:
	var prompt := stage.get_node_or_null("TERRAIN/FieldModuleTerminal/Prompt") as Label3D
	if prompt == null:
		return
	prompt.visible = at_terminal(stage, operator)
	if prompt.visible:
		prompt.text = "%s / %s  ·  FIELD MODULE" % [RiftSettings.binding_label("field_interact", "key"),
			RiftSettings.binding_label("field_interact", "pad")]

func choose(early := false) -> void:
	layer = 42
	add_to_group(&"interactive_dialogue")
	var cover := ColorRect.new()
	cover.color = Color("050b19de")
	add_child(cover)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	cover.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.theme = UI.theme()
	panel.custom_minimum_size.x = 480
	panel.add_theme_stylebox_override("panel", UI.hud_frame(UI.CYAN, Vector2(20, 17), true))
	center.add_child(panel)
	var rows := UI.column(panel, 10)
	UI.label(rows, "Foundry Field Modules" if early else "Kiln Warden reclaimed", 30, UI.CYAN)
	UI.label(rows, "Choose one module for this run.", 17, UI.MUTED)
	var options := EARLY_OPTIONS if early else WARDEN_OPTIONS
	for id in options:
		var data: Array = MODULES[id]
		var button := UI.button(rows, data[0], func(): selected.emit(id), false, 36, false)
		UI.profile_button(button)
		button.size_flags_horizontal = Control.SIZE_FILL
		UI.label(rows, data[1], 16, UI.MUTED)
		if id == options[0]:
			button.grab_focus()
	if early:
		UI.button(rows, "Decide later", func(): selected.emit(""), false, 32, false)
