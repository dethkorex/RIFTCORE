extends Control

const UI := preload("res://scripts/rift_ui.gd")
const EquipmentIcons := preload("res://scripts/equipment_icons.gd")
const Materials := preload("res://scripts/fabrication_catalog.gd")
const Profile := preload("res://scripts/rogue_profile.gd")
const CURRENCY := preload("res://assets/ui/bolt.svg")
const SHARD := preload("res://assets/ui/core-shard.svg")
const PORTRAIT := preload("res://assets/ui/rx07_menu.png")
const CYAN := Color("00caff")
const WHITE := Color("f1f8ff")
const INK := Color(0.018, 0.046, 0.13, 0.96)
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
var loot_popups: VBoxContainer
var remaining := 0
var run_tenths := 0
var status_lines := PackedStringArray()
var act := 1
var coop := false
var coop_objective: Control
var coop_party: Control
var reserve_lives := 0
var reached_exit := false
var weapon := "STANDARD FRAME"
var suit_tint := Color("55e7ff")
var lives := 3
var failed := false
var boss_visible := false
var boss_health := 0.0
var boss_max_health := 1.0
var boss_name := "FORGE TITAN"
var boss_tint := Color("ff8c36")
var boss_sector := 1
var boss_act := 2
const BOSS_SIGILS := ["◆", "✿", "❄", "◈", "⌘", "≋", "⬢", "⊙", "▦", "✧"]
var exit_task := "REACH THE FACTORY EXIT"

func show_quick_slots(profile) -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 5)
	add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	row.offset_left = -103
	row.offset_right = 103
	row.offset_top = -64
	row.offset_bottom = -16
	for index in 4:
		var tile := Control.new()
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.custom_minimum_size = Vector2(48, 48)
		row.add_child(tile)
		tile.draw.connect(func():
			tile.draw_style_box(UI.frame(Color("08142af2"), UI.CYAN, 2), Rect2(Vector2.ZERO, tile.size))
			tile.draw_line(Vector2(4, 4), Vector2(20, 4), UI.CYAN.lightened(.3), 2.0))
		var key := Label.new()
		key.text = ["↑", "←", "→", "↓"][index]
		key.add_theme_font_override("font", UI.DISPLAY)
		key.add_theme_color_override("font_color", CYAN)
		key.add_theme_font_size_override("font_size", 21)
		key.position = Vector2(5, 1)
		key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(key)
		var icon := TextureRect.new()
		icon.position = Vector2(14, 11)
		icon.size = Vector2(29, 28)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(icon)
		var quantity := Label.new()
		quantity.theme = UI.theme()
		quantity.add_theme_font_size_override("font_size", 13)
		quantity.position = Vector2(20, 31)
		quantity.size = Vector2(24, 16)
		quantity.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		quantity.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(quantity)
		var refresh := func():
			if is_instance_valid(icon):
				var current: Dictionary = profile.quick_slots[index]
				var remaining := int(current.get("count", 0))
				var item: Dictionary = profile.stock.get(current.get("id", ""), {})
				icon.texture = EquipmentIcons.supply_icon(item) if remaining > 0 and not item.is_empty() else null
				quantity.text = "×%d" % remaining if remaining > 0 else "–"
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

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	RiftSettings.hud_scale_changed.connect(queue_redraw)
	notice = Label.new()
	add_child(notice)
	notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	notice.offset_left = -400
	notice.offset_right = 400
	notice.offset_top = 120
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.add_theme_font_override("font", UI.DISPLAY)
	notice.add_theme_constant_override("outline_size", 8)
	notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notice.hide()
	loot_popups = VBoxContainer.new()
	loot_popups.mouse_filter = Control.MOUSE_FILTER_IGNORE
	loot_popups.add_theme_constant_override("separation", 3)
	add_child(loot_popups)
	loot_popups.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	loot_popups.offset_left = -230
	loot_popups.offset_right = 230
	loot_popups.offset_top = 186

func place_party() -> void:
	var factor := HUD_SCALE * RiftSettings.hud_scale
	coop_party.position = Vector2(18, 218) * factor
	coop_party.scale = Vector2.ONE * factor
	queue_redraw()

func draw_boss_readout(hud_size: Vector2) -> void:
	var width := clampf(hud_size.x - 560.0, 294.0, 590.0)
	var top := 12.0 if hud_size.x >= 1120.0 else 132.0
	var at := Vector2((hud_size.x - width) * .5, top)
	var values := "%d / %d" % [roundi(boss_health), roundi(boss_max_health)]
	var tint := boss_tint.lightened(.19) if boss_act == 1 else boss_tint
	plate(Rect2(at, Vector2(width, 87)), 15 if boss_act == 2 else 9, tint)
	plate(Rect2(at + Vector2(12, 11), Vector2(48, 43)), 11, tint)
	caption(at + Vector2(22, 43), BOSS_SIGILS[clampi(boss_sector - 1, 0, BOSS_SIGILS.size() - 1)], 27, tint)
	var value_font := 20
	var value_width := UI.DISPLAY.get_string_size(values, HORIZONTAL_ALIGNMENT_LEFT, -1, value_font).x
	caption(at + Vector2(width - value_width - 17, 43), values, value_font)
	caption(at + Vector2(72, 25), "SECTOR %02d   /   %s" % [boss_sector, "MINIBOSS" if boss_act == 1 else "GUARDIAN"], 13, tint)
	var name_font := 27
	var available := width - value_width - 93.0
	while name_font > 13 and UI.DISPLAY.get_string_size(boss_name, HORIZONTAL_ALIGNMENT_LEFT, -1, name_font).x > available:
		name_font -= 1
	caption(at + Vector2(72, 47), boss_name, name_font)
	var fill := clampf(boss_health / maxf(1.0, boss_max_health), 0.0, 1.0)
	var meter := Rect2(at + Vector2(14, 60), Vector2(width - 28, 17))
	draw_rect(meter, tint.darkened(.82))
	var segments := 12 if boss_act == 2 else 8
	for index in segments:
		var span := meter.size.x / segments
		var part := clampf(fill * segments - index, 0.0, 1.0)
		var segment := Rect2(meter.position + Vector2(span * index, 0), Vector2((span - 2.0) * part, meter.size.y))
		draw_rect(segment, tint.lerp(Color.WHITE, .14 + (index % 2) * .14))

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
	notice.add_theme_color_override("font_color", tint)
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

func set_run_time(seconds: float) -> void:
	var next := floori(seconds * 10.0)
	if next != run_tenths:
		run_tenths = next
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
	var popup := Label.new()
	popup.text = message
	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.add_theme_font_override("font", UI.DISPLAY)
	popup.add_theme_font_size_override("font_size", 24)
	popup.add_theme_color_override("font_color", tint)
	popup.add_theme_color_override("font_outline_color", Color("020817"))
	popup.add_theme_constant_override("outline_size", 7)
	loot_popups.add_child(popup)
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
	draw_polyline(outline, Color("103f7a"), 7.0)
	draw_polyline(outline, edge, 2.5)
	draw_line(Vector2(x + cut + 3, y + 3), Vector2(r - cut - 3, y + 3), WHITE, 1.0)

func caption(at: Vector2, value: String, font_size := 18, color := WHITE) -> void:
	var face := UI.DISPLAY
	draw_string(face, at + Vector2(1, 2), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("020817"))
	draw_string(face, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func gauge(y: float, label: String, ratio: float, tint: Color, values := "") -> void:
	caption(Vector2(117, y + 13), label, 15, WHITE)
	if not values.is_empty():
		var width := UI.DISPLAY.get_string_size(values, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		caption(Vector2(361 - width, y + 13), values, 16, WHITE)
	for i in 10:
		var amount := clampf(ratio * 10.0 - i, 0.0, 1.0)
		var start := Vector2(116 + i * 24.4, y + 25)
		var slant := Vector2(4, -7)
		var span := Vector2(21.8, 0)
		draw_colored_polygon(PackedVector2Array([start, start + span, start + span + slant, start + slant]), Color("1e3354"))
		if amount > 0.0:
			span *= amount
			draw_colored_polygon(PackedVector2Array([start, start + span, start + span + slant, start + slant]), tint)

func task(at: Vector2, value: String, done: bool) -> void:
	var color := CYAN if done else WHITE
	draw_rect(Rect2(at + Vector2(0, -13), Vector2(14, 14)), color, false, 2.0)
	if done:
		draw_polyline(PackedVector2Array([at + Vector2(3, -6), at + Vector2(6, -3), at + Vector2(12, -10)]), CYAN, 2.0)
	caption(at + Vector2(23, 0), value, 16, color)

func _draw() -> void:
	var hud_scale := HUD_SCALE * RiftSettings.hud_scale
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * hud_scale)
	var hud_size := size / hud_scale
	plate(Rect2(20, 22, 355, 142), 12)
	var source_size := PORTRAIT.get_size()
	draw_texture_rect_region(PORTRAIT, Rect2(28, 31, 77, 104),
		Rect2(source_size * Vector2(0.415, 0.008), source_size * Vector2(0.17, 0.27)))
	caption(Vector2(117, 48), "RX-07", 21)
	var current_level := RiftPlayer.level_for_experience(experience)
	caption(Vector2(218, 48), "OPERATOR LV. %02d" % current_level, 17, CYAN)
	draw_line(Vector2(117, 54), Vector2(361, 54), Color("315979"))
	gauge(57, "HEALTH", health, Color("6df536"), "%d / %d" % [roundi(health * health_capacity), roundi(health_capacity)])
	gauge(89, "ENERGY", energy, Color("04dafa"), "%d / %d" % [roundi(energy * energy_capacity), roundi(energy_capacity)])
	var shown_level := RiftPlayer.level_for_experience(animated_xp)
	var threshold := RiftPlayer.experience_threshold(shown_level)
	var next_threshold := RiftPlayer.experience_threshold(shown_level + 1)
	gauge(121, "OPERATOR XP", (animated_xp - threshold) / (next_threshold - threshold), Color("ab72ff"))
	var right := hud_size.x - 20.0
	if not coop:
		var x := right - 348.0
		plate(Rect2(x, 21, 348, 105), 14)
		for y in range(56, 120, 5):
			draw_line(Vector2(x + 5, y), Vector2(right - 5, y), Color("102752"), 1.0)
		caption(Vector2(x + 18, 49), "ACT %s  /  OBJECTIVE" % ("II" if act == 2 else "I"), 22)
		draw_line(Vector2(x + 12, 55), Vector2(right - 12, 55), CYAN, 1.0)
		task(Vector2(x + 20, 80), exit_task, reached_exit)
		task(Vector2(x + 20, 106), "OPTIONAL: SECURITY   %d LEFT" % remaining, remaining == 0)
	var counters := Vector2(right - 222, 139)
	if coop and is_instance_valid(coop_objective):
		counters.y = maxf(counters.y, coop_objective.get_rect().end.y / hud_scale + 12.0)
	plate(Rect2(counters, Vector2(222, 65)), 11)
	draw_texture_rect(CURRENCY, Rect2(counters + Vector2(13, 5), Vector2(24, 24)), false)
	caption(counters + Vector2(47, 25), "BOLTS  %04d" % credits, 19)
	draw_line(counters + Vector2(13, 34), counters + Vector2(208, 34), Color("346681"))
	draw_texture_rect(SHARD, Rect2(counters + Vector2(13, 37), Vector2(24, 24)), false)
	caption(counters + Vector2(47, 55), "%04d CORE SHARDS" % core_shards, 17)
	plate(Rect2(counters + Vector2(0, 71), Vector2(222, 33)), 9)
	var life_text := "RX   LIVES   %02d" % lives
	if reserve_lives > 0:
		life_text += "  +%d" % reserve_lives
	caption(counters + Vector2(15, 94), life_text, 17)
	plate(Rect2(counters + Vector2(0, 111), Vector2(222, 33)), 9)
	var time_text := "%02d:%02d.%d" % [run_tenths / 600, run_tenths / 10 % 60, run_tenths % 10]
	caption(counters + Vector2(15, 134), "TIME     " + time_text, 17)
	if boss_visible:
		draw_boss_readout(hud_size)
	if failed:
		plate(Rect2(hud_size.x * 0.5 - 168, hud_size.y * 0.72, 336, 44), 10, Color("ff536c"))
		caption(Vector2(hud_size.x * 0.5 - 151, hud_size.y * 0.72 + 28), "RUN OVER   /   BANKING CREDITS" if lives <= 0 else "SYSTEM FAILURE   /   RESPAWNING", 17)

	plate(Rect2(18, 164, 280, 43), 9, suit_tint)
	var visor := PackedVector2Array([Vector2(33, 174), Vector2(40, 171), Vector2(48, 171),
		Vector2(55, 174), Vector2(54, 189), Vector2(44, 200), Vector2(34, 189), Vector2(33, 174)])
	draw_polyline(visor, suit_tint, 2.0, true)
	draw_line(Vector2(36, 182), Vector2(52, 182), suit_tint, 2.0, true)
	caption(Vector2(64, 182), weapon, 16, suit_tint)
	var device := "pad" if not Input.get_connected_joypads().is_empty() else "key"
	var previous := RiftSettings.binding_label("previous_suit", device)
	var next := RiftSettings.binding_label("swap_weapon", device)
	caption(Vector2(64, 199), "%s  ‹  PREV     NEXT  ›  %s" % [previous, next], 12, Color("a8c6db"))
	var status_y := 218.0
	if coop and is_instance_valid(coop_party):
		status_y += coop_party.size.y + 12.0
	for line in status_lines:
		plate(Rect2(20, status_y, 222, 33), 9, UI.VIOLET)
		caption(Vector2(35, status_y + 24), line, 22)
		status_y += 39.0
