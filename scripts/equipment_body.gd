extends Control

const UI := preload("res://scripts/rift_ui.gd")
const ICONS := preload("res://scripts/equipment_icons.gd")
const PROFILE := preload("res://scripts/rogue_profile.gd")
const AVATAR := preload("res://scenes/actors/riftcore_player.tscn")

const SOCKETS := {
	"frame": {"joint": Vector2(0.455, 0.30), "row": 0.41, "left": true},
	"core": {"joint": Vector2(0.506, 0.329), "row": 0.38, "left": false},
	"utility": {"joint": Vector2(0.447, 0.748), "row": 0.75, "left": true},
	"visor": {"joint": Vector2(0.50, 0.19), "row": 0.13, "left": true},
	"arm": {"joint": Vector2(0.63, 0.48), "row": 0.66, "left": false},
}
var buttons := {}
var profile
var selected := "frame"
var preview_actor: RiftPlayer

func install(data, active: String, action: Callable, workshop := false) -> void:
	profile = data
	selected = active
	custom_minimum_size = Vector2(386, 260)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var screen := SubViewportContainer.new()
	screen.stretch = true
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var view := SubViewport.new()
	view.own_world_3d = true
	view.transparent_bg = true
	view.gui_disable_input = true
	view.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	screen.add_child(view)
	var actor := AVATAR.instantiate() as RiftPlayer
	preview_actor = actor
	view.add_child(actor)
	actor.position.y = 0.89
	actor.set_physics_process(false)
	actor.collision_layer = 0
	actor.collision_mask = 0
	actor.model_root.rotation.y = 0
	actor.play_character_animation("idle", true)
	var silhouette := ShaderMaterial.new()
	silhouette.shader = preload("res://assets/ui/equipment_silhouette.gdshader")
	for mesh in actor.model_root.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = silhouette
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.35
	view.add_child(camera)
	camera.position = Vector3(0, 0.88, 4.0)
	camera.make_current()
	var order := ["visor", "frame", "core", "arm", "utility"]
	for slot in order:
		var id: String = profile.equipped_for(slot) if profile and not workshop else ""
		var name: String = PROFILE.GEAR_SLOTS[slot]
		var detail := "Empty" if id.is_empty() else String(PROFILE.GEAR[id].name)
		if workshop:
			var count := 0
			for upgrade in profile.all_upgrades():
				if String(upgrade.get("slot", PROFILE.UPGRADE_SLOTS.get(upgrade.id, ""))) == slot and profile.rank(upgrade.id) > 0:
					count += 1
			detail = "%d installed" % count
		var button := UI.button(self, name + "\n" + detail, action.bind(slot) if action.is_valid() else Callable(), slot == selected)
		if not action.is_valid():
			button.add_theme_stylebox_override("disabled", button.get_theme_stylebox("normal"))
			button.add_theme_color_override("font_disabled_color", UI.WHITE)
		button.icon = ICONS.icon(slot if id.is_empty() else id, slot)
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 24)
		button.add_theme_constant_override("h_separation", 7)
		button.add_theme_font_size_override("font_size", 14)
		button.tooltip_text = name if id.is_empty() else String(PROFILE.GEAR[id].perk)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		buttons[slot] = button
		if action.is_valid() and slot == selected:
			button.grab_focus()
	resized.connect(place_sockets)
	if action.is_valid():
		for side in [["visor", "frame", "utility"], ["core", "arm"]]:
			for index in side.size():
				var button: Button = buttons[side[index]]
				if index > 0:
					button.focus_neighbor_top = button.get_path_to(buttons[side[index - 1]])
				if index < side.size() - 1:
					button.focus_neighbor_bottom = button.get_path_to(buttons[side[index + 1]])
		buttons.visor.focus_neighbor_right = buttons.visor.get_path_to(buttons.core)
		buttons.frame.focus_neighbor_right = buttons.frame.get_path_to(buttons.core)
		buttons.utility.focus_neighbor_right = buttons.utility.get_path_to(buttons.arm)
		buttons.core.focus_neighbor_left = buttons.core.get_path_to(buttons.frame)
		buttons.arm.focus_neighbor_left = buttons.arm.get_path_to(buttons.utility)
	place_sockets.call_deferred()

func place_sockets() -> void:
	for slot in buttons:
		var button: Button = buttons[slot]
		var socket: Dictionary = SOCKETS[slot]
		var wide := minf(size.x * 0.35, 168.0)
		button.custom_minimum_size.x = 0.0
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.size = Vector2(wide, 50.0)
		button.position = Vector2(9.0 if socket.left else size.x - wide - 9.0, size.y * float(socket.row) - button.size.y * 0.5)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("091827"))
	var grid := Color("112b40")
	for x in range(0, int(size.x), 25):
		draw_line(Vector2(x, 0), Vector2(x, size.y), grid)
	for y in range(0, int(size.y), 25):
		draw_line(Vector2(0, y), Vector2(size.x, y), grid)
	if buttons.is_empty():
		return
	for slot in buttons:
		var socket: Dictionary = SOCKETS[slot]
		var button: Button = buttons[slot]
		var joint: Vector2 = socket.joint * size
		var edge := button.position + Vector2(button.size.x if socket.left else 0.0, button.size.y * 0.5)
		var color: Color = ICONS.COLORS[slot]
		if selected != slot:
			color = color.darkened(0.34)
		draw_polyline(PackedVector2Array([edge, Vector2(joint.x, edge.y), joint]), color, 1.3, true)
