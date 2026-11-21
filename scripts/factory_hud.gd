extends Control

const UI := preload("res://scripts/rift_ui.gd")
const EquipmentIcons := preload("res://scripts/equipment_icons.gd")
const EquipmentDisplay := preload("res://scripts/equipment_display.gd")
const Materials := preload("res://scripts/fabrication_catalog.gd")
const Profile := preload("res://scripts/rogue_profile.gd")
const CURRENCY := preload("res://assets/ui/bolt.svg")
const SHARD := preload("res://assets/ui/core-shard.svg")
const PORTRAIT := preload("res://assets/ui/rx07_menu.png")
const CYAN := UI.CYAN
const WHITE := Color("f1f8ff")
const INK := Color("091727f5")
const PANEL_WIDTH := 354.0
const OBJECTIVE_WIDTH := 348.0
const EDGE := 20.0
const SUIT_TOP := 200.0
const SUIT_BOTTOM := 241.0
const PARTY_TOP := 253.0
const WALLET_HEIGHT := 44.0
const MINIMAP_HEIGHT := 159.0
const PORTRAIT_FRAME := Rect2(32, 34, 80, 143)
const PICKUP_HEAD_CLEARANCE := 56.0
const HEART := preload("res://assets/ui/riftcore_kit/icon_heart.png")
const SHIELD := preload("res://assets/ui/riftcore_kit/icon_shield.png")
const HUD_SCALE := 0.75
const BOOST_NAMES := {"attack": "ATK", "defense": "DEF", "speed": "SPD"}

var health := 1.0
var energy := 1.0
var health_capacity := 80.0
var energy_capacity := 75.0
var displayed_health_capacity := 80.0
var displayed_energy_capacity := 75.0
var credits := 0
var core_shards := 0
var experience := 0
var animated_xp := 0.0
var xp_tween: Tween
var notice: Label
var notice_tween: Tween
var quick_row: HBoxContainer
var loot_popups: VBoxContainer
var portrait: EquipmentDisplay
var local_operator: Node3D:
	set(value):
		if local_operator == value:
			return
		local_operator = value
		if is_instance_valid(portrait):
			portrait.sync_operator(local_operator as RiftPlayer)
		if is_instance_valid(loot_popups):
			for popup in loot_popups.get_children():
				loot_popups.remove_child(popup)
				popup.queue_free()
var remaining := 0
var run_tenths := 0
var status_lines := PackedStringArray()
var act := 1
var coop := false
var coop_objective: Control
var coop_party: Control
var minimap: Control
var reached_exit := false
var weapon := "STANDARD FRAME"
var suit_tint := Color("55e7ff")
var lives := 3
var failed := false
var boss_visible := false
var boss_health := 0.0
var boss_max_health := 1.0
var boss_mechanic := ""
var boss_core_exposed := false
var boss_name := "FORGE TITAN"
var boss_tint := Color("ff8c36")
var boss_sector := 1
var boss_act := 2
const BOSS_SIGILS := ["◆", "✿", "❄", "◈", "⌘", "≋", "⬢", "⊙", "▦", "✧"]
var gate_relay_count := -1
var exit_task := "REACH THE FACTORY EXIT"

func add_field_lessons(sector: int, mission_act: int, can_teach: Callable) -> void:
	if sector != 1 or mission_act != 1:
		return
	var lessons := preload("res://scripts/foundry_field_lessons.gd").new()
	lessons.hud = self
	lessons.available = can_teach
	lessons.name = "FoundryFieldLessons"
	add_child(lessons)

func show_quick_slots(profile) -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	add_child(row)
	quick_row = row
	row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	row.offset_left = -105
	row.offset_right = 105
	row.offset_top = -67
	row.offset_bottom = -19
	row.pivot_offset = Vector2(105, 48)
	RiftSettings.hud_scale_changed.connect(place_quick_slots)
	place_quick_slots()
	var tile_normal := UI.hud_frame(CYAN, Vector2.ZERO)
	var tile_filled := UI.hud_frame(CYAN, Vector2.ZERO, true)
	for index in 4:
		var tile := Control.new()
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.custom_minimum_size = Vector2(48, 48)
		row.add_child(tile)
		var key := Label.new()
		key.text = ["↑", "←", "→", "↓"][index]
		key.add_theme_font_override("font", UI.DISPLAY)
		key.add_theme_color_override("font_color", CYAN)
		key.add_theme_font_size_override("font_size", 21)
		key.position = Vector2(7, 0)
		key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(key)
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(icon)
		icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		icon.offset_left = -14
		icon.offset_right = 14
		icon.offset_top = -14
		icon.offset_bottom = 14
		var quantity := Label.new()
		quantity.add_theme_font_override("font", UI.DISPLAY)
		quantity.add_theme_color_override("font_color", UI.WHITE)
		quantity.add_theme_font_size_override("font_size", 13)
		quantity.position = Vector2(19, 29)
		quantity.size = Vector2(24, 16)
		quantity.add_theme_color_override("font_outline_color", Color("06111e"))
		quantity.add_theme_constant_override("outline_size", 4)
		quantity.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		quantity.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(quantity)
		var refresh := func():
			if is_instance_valid(icon):
				var current: Dictionary = profile.quick_slots[index]
				var remaining := int(current.get("count", 0))
				var item: Dictionary = profile.stock.get(current.get("id", ""), {})
				icon.texture = EquipmentIcons.supply_icon(item) if remaining > 0 and not item.is_empty() else null
				quantity.text = str(remaining) if remaining > 0 else "–"
				key.modulate = Color.WHITE if remaining > 0 else Color("9eb2c7")
				tile.queue_redraw()
		tile.draw.connect(func():
			var frame := tile_filled if icon.texture else tile_normal
			tile.draw_style_box(frame, Rect2(Vector2.ZERO, tile.size))
			tile.draw_line(Vector2(8, 4), Vector2(18, 4), CYAN if icon.texture else Color("375873"), 1.5))
		var refresh_key := func():
			key.text = ["↑", "←", "→", "↓"][index] if not Input.get_connected_joypads().is_empty() else str(index + 1)
		refresh.call()
		refresh_key.call()
		profile.quick_changed.connect(refresh)
		var update_device := func(_device: int, _connected: bool): refresh_key.call()
		Input.joy_connection_changed.connect(update_device)
		tile.tree_exiting.connect(func():
			profile.quick_changed.disconnect(refresh)
			Input.joy_connection_changed.disconnect(update_device)
		, CONNECT_ONE_SHOT)

func place_quick_slots() -> void:
	quick_row.scale = Vector2.ONE * RiftSettings.hud_scale

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(update_right_column)
	RiftSettings.hud_scale_changed.connect(update_right_column)
	if DisplayServer.get_name() != "headless":
		portrait = EquipmentDisplay.new()
		portrait.name = "IdlePortrait"
		portrait.hud_portrait = true
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(portrait)
		portrait.set_process(false)
		portrait.sync_operator(local_operator as RiftPlayer)
		RiftSettings.hud_scale_changed.connect(place_portrait)
		place_portrait()
	notice = UI.hud_readout(self, 151, 386, CYAN, 29)
	loot_popups = VBoxContainer.new()
	loot_popups.mouse_filter = Control.MOUSE_FILTER_IGNORE
	loot_popups.add_theme_constant_override("separation", 3)
	add_child(loot_popups)
	loot_popups.name = "PickupPopups"
	loot_popups.hide()
	loot_popups.child_order_changed.connect(sync_pickup_stack)
	set_process(false)

func place_portrait() -> void:
	var factor := HUD_SCALE * RiftSettings.hud_scale
	portrait.position = (PORTRAIT_FRAME.position + Vector2.ONE) * factor
	portrait.size = (PORTRAIT_FRAME.size - Vector2(2, 2)) * factor

func pickup_stack_height() -> float:
	if not is_instance_valid(loot_popups) or not loot_popups.is_visible_in_tree():
		return 0.0
	return PICKUP_HEAD_CLEARANCE + loot_popups.size.y + 8.0

func sync_pickup_stack() -> void:
	var active := loot_popups.get_child_count() > 0
	loot_popups.visible = active
	set_process(active)

func _process(_delta: float) -> void:
	loot_popups.size = loot_popups.get_combined_minimum_size()
	loot_popups.position = UI.operator_popup_position(loot_popups, local_operator, PICKUP_HEAD_CLEARANCE)

func place_party() -> void:
	var factor := HUD_SCALE * RiftSettings.hud_scale
	coop_party.position = Vector2(EDGE, PARTY_TOP) * factor
	coop_party.scale = Vector2.ONE * factor
	queue_redraw()

func draw_boss_readout(hud_size: Vector2, right_start: float, lower_top: float) -> void:
	var center_left := EDGE + PANEL_WIDTH + 18.0
	var center_right := right_start - 18.0
	var available := center_right - center_left
	var width := minf(560.0, available)
	var at := Vector2(center_left + (available - width) * 0.5, EDGE)
	if available < 340.0:
		width = minf(490.0, hud_size.x - EDGE * 2.0)
		at = Vector2((hud_size.x - width) * 0.5, lower_top)
	var tint := boss_tint.lightened(.25) if boss_act == 1 else boss_tint.lightened(.1)
	plate(Rect2(at, Vector2(width, 84)), 13, tint)
	draw_rect(Rect2(at + Vector2(13, 51), Vector2(width - 26, 1)), tint.darkened(.55))
	caption(at + Vector2(18, 23), BOSS_SIGILS[clampi(boss_sector - 1, 0, BOSS_SIGILS.size() - 1)], 18, tint)
	caption(at + Vector2(42, 21), "SECTOR %02d  /  %s" % [boss_sector, "MINIBOSS" if boss_act == 1 else "GUARDIAN"], 13, tint)
	var values := "%d / %d" % [roundi(boss_health), roundi(boss_max_health)]
	var value_width := text_width(values, 18)
	caption(at + Vector2(width - value_width - 16, 44), values, 18)
	var name_font := fit_font(boss_name, 26, width - value_width - 62.0)
	caption(at + Vector2(18, 46), boss_name, name_font)
	var fraction := clampf(boss_health / maxf(1.0, boss_max_health), 0.0, 1.0)
	var meter := Rect2(at + Vector2(16, 59), Vector2(width - 35, 13))
	segmented_meter(meter, fraction, tint, 12 if boss_act == 2 else 8)
	if boss_mechanic.is_empty():
		return
	for threshold: float in [0.64, 0.30]:
		var x := meter.position.x + meter.size.x * threshold
		draw_line(Vector2(x, meter.position.y - 1), Vector2(x, meter.end.y + 1), WHITE, 1.6, true)
	var status_at := at + Vector2(0, 91)
	var status_tint := Color("8dffe5") if boss_core_exposed else Color("ffbd78")
	var lines := boss_mechanic.split("\n", false)
	plate(Rect2(status_at, Vector2(width, 13.0 + 19.0 * lines.size())), 9, status_tint)
	for index in lines.size():
		var font_size := fit_font(lines[index], 18 if index == 0 else 15, width - 29.0)
		var line_width := text_width(lines[index], font_size)
		caption(status_at + Vector2((width - line_width) * 0.5, 20 + index * 19), lines[index], font_size,
			status_tint if index == 0 else WHITE)

func update_boss_mechanic(boss: Combatant) -> void:
	var status: String = boss.encounter_status() if is_instance_valid(boss) and boss.has_method("encounter_status") else ""
	var open: bool = not status.is_empty() and boss.exposed
	if status != boss_mechanic or open != boss_core_exposed:
		boss_mechanic = status
		boss_core_exposed = open
		queue_redraw()

func set_experience(total: int) -> void:
	var old_level := RiftPlayer.level_for_experience(experience)
	experience = total
	if xp_tween and xp_tween.is_valid():
		xp_tween.kill()
	xp_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	xp_tween.tween_method(func(value: float):
		animated_xp = value
		queue_redraw()
	, animated_xp, float(total), 0.55)
	xp_tween.parallel().tween_property(self, "displayed_health_capacity", health_capacity, 0.55)
	xp_tween.parallel().tween_property(self, "displayed_energy_capacity", energy_capacity, 0.55)
	if RiftPlayer.level_for_experience(total) > old_level:
		RiftAudio.play_effect(&"level_up")
		announce("LEVEL UP!", Color("c9a0ff"))
		RiftAudio.play_effect(&"voice_level_up")

func announce(message: String, tint: Color, font_size := 36) -> void:
	if notice_tween and notice_tween.is_valid():
		notice_tween.kill()
	notice.text = message
	notice.add_theme_font_size_override("font_size", font_size)
	notice.add_theme_color_override("font_color", tint.lightened(.1))
	notice.add_theme_stylebox_override("normal", UI.hud_frame(tint, Vector2(16, 8), true))
	notice.offset_top = 180 if boss_visible else 151
	notice.offset_bottom = notice.offset_top
	notice.show()
	notice.pivot_offset = notice.size * 0.5
	notice.scale = Vector2.ONE * 0.72
	notice.modulate.a = 0.0
	notice_tween = create_tween()
	notice_tween.tween_property(notice, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	notice_tween.parallel().tween_property(notice, "modulate:a", 1.0, 0.16)
	notice_tween.tween_interval(1.2)
	notice_tween.tween_property(notice, "modulate:a", 0.0, 0.32)
	notice_tween.tween_callback(notice.hide)

func set_gate_relays(count: int) -> void:
	if gate_relay_count != count:
		gate_relay_count = count
		update_right_column()

func set_run_time(seconds: float) -> void:
	var next := floori(seconds * 10.0)
	if next != run_tenths:
		run_tenths = next
		if is_instance_valid(portrait) and portrait.is_visible_in_tree():
			portrait.sync_operator(local_operator as RiftPlayer)
		queue_redraw()

func show_loot(materials: Dictionary, blueprint: String, supply: String, bolts := 0, extra_life := false) -> void:
	if bolts > 0:
		add_loot_popup("+%d Bolts" % bolts, Color("ffda83"))
	if Profile.GEAR.has(blueprint):
		add_loot_popup(Profile.GEAR[blueprint].name + " Blueprint", Color("ffda83"))
	if Profile.stock.has(supply):
		add_loot_popup("+1 " + Profile.stock[supply].name, Color("75ffd2"))
	if extra_life:
		add_loot_popup("+1 Life", Color("75ffd2"))
	for id in materials:
		add_loot_popup("+%d %s" % [materials[id], Materials.label(id)], Color("ff8ada"))

func add_loot_popup(message: String, tint: Color) -> void:
	if loot_popups.get_child_count() >= 5:
		var oldest := loot_popups.get_child(0)
		loot_popups.remove_child(oldest)
		oldest.queue_free()
	var popup := UI.profile_label(loot_popups, message, 20, tint)
	popup.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.add_theme_stylebox_override("normal", UI.hud_frame(tint, Vector2(12, 4)))
	var fade := popup.create_tween()
	fade.tween_interval(1.6)
	fade.tween_property(popup, "modulate:a", 0.0, 0.32)
	fade.tween_callback(popup.queue_free)

func set_status_effects(supplies: Dictionary, debuff := 0, remaining := 0.0) -> void:
	var lines := PackedStringArray()
	if debuff > 0 and debuff < RiftPlayer.BOSS_DEBUFFS.size() and remaining > 0.0:
		lines.append("!  %s   ·   %ds" % [RiftPlayer.BOSS_DEBUFFS[debuff], ceili(remaining)])
	for stat in BOOST_NAMES:
		var effect: Vector2 = supplies.get(stat, Vector2.ZERO)
		if effect.y > 0.0:
			lines.append("%s +%d%%   ·   %ds" % [BOOST_NAMES[stat], roundi(effect.x * 100.0), ceili(effect.y)])
	if lines != status_lines:
		status_lines = lines
		queue_redraw()

func plate(rect: Rect2, cut := 9.0, edge := CYAN) -> void:
	var x := rect.position.x
	var y := rect.position.y
	var r := rect.end.x
	var b := rect.end.y
	var outline := PackedVector2Array([
		Vector2(x + cut, y), Vector2(r - cut, y), Vector2(r, y + cut),
		Vector2(r, b - cut), Vector2(r - cut, b), Vector2(x + cut, b),
		Vector2(x, b - cut), Vector2(x, y + cut)
	])
	draw_colored_polygon(outline, INK)
	outline.append(outline[0])
	draw_polyline(outline, Color(edge, 0.16), 4.2, true)
	draw_polyline(outline, Color(edge.lerp(Color("1a3b5c"), .32), .95), 1.65, true)
	draw_line(Vector2(x + cut + 4, y + 3), Vector2(x + cut + minf(rect.size.x * .31, 76.0), y + 3), edge, 2, true)
	draw_line(Vector2(r - cut - 24, b - 3), Vector2(r - cut - 2, b - 3), Color(edge, .54), 1.4, true)

func text_width(value: String, font_size: int) -> float:
	return UI.DISPLAY.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

func fit_font(value: String, preferred: int, available: float) -> int:
	var font_size := preferred
	while font_size > 11 and text_width(value, font_size) > available:
		font_size -= 1
	return font_size

func caption(at: Vector2, value: String, font_size := 18, color := WHITE) -> void:
	draw_string(UI.DISPLAY, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func segmented_meter(rect: Rect2, ratio: float, tint: Color, count: int) -> void:
	var step := rect.size.x / count
	for index in count:
		var pt := rect.position + Vector2(index * step, rect.size.y)
		var slant := Vector2(minf(rect.size.y * .48, 5.0), -rect.size.y)
		var span := Vector2(step - 3.0, 0)
		draw_colored_polygon(PackedVector2Array([pt, pt + span, pt + span + slant, pt + slant]), Color("1c324a"))
		var amount := clampf(ratio * count - index, 0.0, 1.0)
		if amount > 0.0:
			span *= amount
			draw_colored_polygon(PackedVector2Array([pt, pt + span, pt + span + slant, pt + slant]), tint)
			draw_line(pt + slant, pt + span + slant, tint.lightened(.38), 1.15, true)

func gauge(y: float, label: String, ratio: float, tint: Color, values := "") -> void:
	caption(Vector2(119, y + 13), label, 16, UI.MUTED)
	if not values.is_empty():
		caption(Vector2(358 - text_width(values, 17), y + 13), values, 17)
	segmented_meter(Rect2(118, y + 18, 237, 8), ratio, tint, 10)

func task(at: Vector2, value: String, done: bool) -> void:
	var color := Color("8dffe5") if done else WHITE
	draw_rect(Rect2(at + Vector2(0, -13), Vector2(13, 13)), Color(color, .64), false, 1.4)
	if done:
		draw_polyline(PackedVector2Array([at + Vector2(2, -6), at + Vector2(5, -3), at + Vector2(11, -10)]), color, 1.8, true)
	caption(at + Vector2(23, 0), value, fit_font(value, 17, OBJECTIVE_WIDTH - 58.0), color)

func draw_operator() -> void:
	plate(Rect2(EDGE, EDGE, PANEL_WIDTH, SUIT_TOP - EDGE - 9.0), 13)
	draw_rect(PORTRAIT_FRAME, Color("102338"))
	if not is_instance_valid(portrait):
		var source_size := PORTRAIT.get_size()
		draw_texture_rect_region(PORTRAIT, PORTRAIT_FRAME.grow(-2),
			Rect2(source_size * Vector2(0.415, 0.008), source_size * Vector2(0.17, 0.27)))
	draw_rect(PORTRAIT_FRAME, Color("386e8d"), false, 1.0)
	caption(Vector2(119, 48), "RX-07", 23)
	var current_level := RiftPlayer.level_for_experience(experience)
	var level := "OPERATOR LV. %02d" % current_level
	caption(Vector2(359 - text_width(level, 18), 47), level, 18, CYAN)
	draw_line(Vector2(119, 54), Vector2(358, 54), Color("315979"))
	gauge(57, "HEALTH", health, Color("7cf287"), "%d / %d" % [roundi(health * health_capacity), roundi(health_capacity)])
	gauge(87, "ENERGY", energy, Color("4cdcfb"), "%d / %d" % [roundi(energy * energy_capacity), roundi(energy_capacity)])
	var shown_level := RiftPlayer.level_for_experience(animated_xp)
	var threshold := RiftPlayer.experience_threshold(shown_level)
	var next_threshold := RiftPlayer.experience_threshold(shown_level + 1)
	gauge(117, "OPERATOR XP", (animated_xp - threshold) / float(next_threshold - threshold), Color("b693ff"))
	var life_tint := Color("ff8999") if lives == 0 else Color("9affbc") if lives > 1 else Color("ffd481")
	draw_line(Vector2(119, 152), Vector2(358, 152), Color("315979"))
	draw_texture_rect(HEART, Rect2(120, 158, 17, 17), false, life_tint)
	caption(Vector2(145, 173), "OPERATOR LIVES", 17, UI.MUTED)
	var life_count := "%02d" % lives
	caption(Vector2(358 - text_width(life_count, 22), 173), life_count, 22, life_tint)

	plate(Rect2(EDGE, SUIT_TOP, 296, SUIT_BOTTOM - SUIT_TOP), 9, suit_tint)
	draw_texture_rect(SHIELD, Rect2(32, SUIT_TOP + 7.0, 25, 25), false, suit_tint)
	var mode := "SABER" if local_operator is RiftPlayer and local_operator.saber_equipped else "BUSTER"
	var loadout := "%s  /  %s" % [weapon, mode]
	caption(Vector2(66, SUIT_TOP + 17.0), loadout, fit_font(loadout, 17, 234.0), suit_tint)
	var device := "pad" if not Input.get_connected_joypads().is_empty() else "key"
	var previous := RiftSettings.binding_label("previous_suit", device)
	var next := RiftSettings.binding_label("swap_weapon", device)
	var controls := "%s  SWITCH     %s / %s  SUIT" % [RiftSettings.binding_label("melee", device), previous, next]
	caption(Vector2(66, SUIT_TOP + 33.0), controls, fit_font(controls, 13, 234.0), UI.MUTED)

func draw_objective(right: float) -> float:
	var x := right - OBJECTIVE_WIDTH
	var height := 121.0 if gate_relay_count >= 0 else 96.0
	plate(Rect2(x, EDGE, OBJECTIVE_WIDTH, height), 13)
	caption(Vector2(x + 17, 46), "//  ACT %s   /   OBJECTIVE" % ("II" if act == 2 else "I"), 22, CYAN)
	draw_line(Vector2(x + 16, 53), Vector2(right - 16, 53), Color("315979"))
	task(Vector2(x + 17, 76), exit_task, reached_exit)
	task(Vector2(x + 17, 99), "OPTIONAL: SECURITY  %d LEFT" % remaining, remaining == 0)
	if gate_relay_count >= 0:
		task(Vector2(x + 17, 123), "GATE RELAYS   %d / 2" % gate_relay_count, gate_relay_count == 2)
	return EDGE + height

func install_minimap(map: Control) -> void:
	minimap = map
	minimap.name = "Minimap"
	add_child(minimap)
	update_right_column()

func right_column(factor: float) -> Rect2:
	if coop and is_instance_valid(coop_objective):
		var objective := coop_objective.get_global_rect()
		return Rect2(objective.position.x / factor, objective.end.y / factor + 8.0, objective.size.x / factor, WALLET_HEIGHT)
	var x := size.x / factor - EDGE - OBJECTIVE_WIDTH
	var top := EDGE + (121.0 if gate_relay_count >= 0 else 96.0) + 8.0
	return Rect2(x, top, OBJECTIVE_WIDTH, WALLET_HEIGHT)

func update_right_column() -> void:
	if is_instance_valid(minimap):
		var factor := HUD_SCALE * RiftSettings.hud_scale
		var wallet := right_column(factor)
		minimap.position = Vector2(wallet.position.x, wallet.end.y + 8.0) * factor
		minimap.size = Vector2(wallet.size.x, MINIMAP_HEIGHT)
		minimap.scale = Vector2.ONE * factor
	queue_redraw()

func draw_resources(wallet: Rect2) -> void:
	plate(wallet, 9)
	var width := wallet.size.x / 3.0
	var time := "%02d:%02d.%d" % [run_tenths / 600, run_tenths / 10 % 60, run_tenths % 10]
	var entries := [
		["BOLTS", "%04d" % credits, Color("ffd481"), CURRENCY],
		["SHARDS", UI.shard_amount(core_shards, 4), Color("d7b0ff"), SHARD],
		["RUN TIME", time, WHITE, null],
	]
	for index in entries.size():
		var at := wallet.position + Vector2(index * width, 0.0)
		var entry: Array = entries[index]
		var inset := 13.0
		if entry[3] != null:
			draw_texture_rect(entry[3], Rect2(at + Vector2(11, 13), Vector2(18, 18)), false)
			inset = 36.0
		caption(at + Vector2(inset, 16), entry[0], 13, UI.MUTED)
		caption(at + Vector2(inset, 35), entry[1], fit_font(entry[1], 19, width - inset - 8.0), entry[2])
		if index > 0:
			draw_line(at + Vector2(0, 9), at + Vector2(0, 36), Color("284861"))

func _draw() -> void:
	var hud_scale := HUD_SCALE * RiftSettings.hud_scale
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * hud_scale)
	var hud_size := size / hud_scale
	draw_operator()
	if not coop:
		draw_objective(hud_size.x - EDGE)
	var wallet := right_column(hud_scale)
	draw_resources(wallet)

	var status_y := PARTY_TOP
	if coop and is_instance_valid(coop_party):
		status_y += coop_party.size.y + 11.0
	for line in status_lines:
		var tint := Color("ff918b") if line.begins_with("!") else UI.VIOLET
		plate(Rect2(EDGE, status_y, 222, 30), 8, tint)
		caption(Vector2(34, status_y + 21), line, fit_font(line, 18, 192.0), tint)
		status_y += 36.0
	if boss_visible:
		draw_boss_readout(hud_size, wallet.position.x, maxf(status_y, wallet.end.y + 8.0) + 16.0)
	if failed:
		var width := 340.0
		var at := Vector2((hud_size.x - width) * 0.5, hud_size.y * 0.72)
		var message := "RUN OVER   /   BANKING CREDITS" if lives <= 0 else "SYSTEM FAILURE   /   RESPAWNING"
		plate(Rect2(at, Vector2(width, 42)), 10, Color("ff627d"))
		caption(at + Vector2((width - text_width(message, 18)) * .5, 27), message, 18)
