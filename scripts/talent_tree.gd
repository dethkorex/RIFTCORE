extends VBoxContainer

const UI := preload("res://scripts/rift_ui.gd")
const Profile := preload("res://scripts/rogue_profile.gd")
const Icons := preload("res://scripts/equipment_icons.gd")
const BOLT := preload("res://assets/ui/bolt.svg")
const SHARD := preload("res://assets/ui/core-shard.svg")
const COLORS := {"Survivability": Color("64ffcc"), "Damage": Color("ff9873"), "Scavenger": Color("53ddff")}
const CATEGORY_ICONS := {"Survivability": "frame", "Damage": "arm", "Scavenger": "visor"}
const EMBLEMS := {"Survivability": "aegis", "Damage": "pulse_lens", "Scavenger": "talent_case"}
const TILE_SIZE := 42.0

var profile
var selection: Button
var nodes: Dictionary = {}
var tooltip_style: Theme
var portrait: TextureRect
var heading: Label
var rank_caption: Label
var tier_caption: Label
var current_effect: Label
var next_effect: Label
var requirements: Label
var feedback: Label
var price: Label
var price_icon: TextureRect
var purchase: Button

func build(operator_profile, focus_id: String, status: String, buy: Callable) -> void:
	profile = operator_profile
	add_theme_constant_override("separation", 8)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	tooltip_style = Theme.new()
	tooltip_style.set_stylebox("panel", "TooltipPanel", UI.frame(Color("07182b"), UI.CYAN, 2))
	tooltip_style.set_font("font", "TooltipLabel", UI.DISPLAY)
	tooltip_style.set_color("font_color", "TooltipLabel", UI.WHITE)
	var lanes := HBoxContainer.new()
	lanes.add_theme_constant_override("separation", 9)
	lanes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(lanes)
	build_inspector(buy, status)
	for branch in Profile.TALENT_BRANCHES:
		build_branch(lanes, branch)
	if not nodes.has(focus_id):
		focus_id = Profile.UPGRADES[0].id
	var initial: Button = nodes[focus_id]
	inspect(initial)
	initial.grab_focus()

func build_branch(parent: HBoxContainer, branch: String) -> void:
	var tint: Color = COLORS[branch]
	var frame := UI.equipment_card(tint)
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(frame)
	var wiring := Control.new()
	wiring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(wiring)
	var lane := UI.column(frame, 3)
	var mast := add_chip(lane, branch.to_upper(), Icons.icon(EMBLEMS[branch], CATEGORY_ICONS[branch]), tint, 24, 38)
	mast.add_theme_color_override("font_color", UI.WHITE)
	var levels: Array[Array] = []
	var open: Array[bool] = []
	for tier in Profile.TALENT_TIER_COUNT:
		var locked: bool = not profile.talent_gate(branch, tier).is_empty()
		open.append(not locked)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 0)
		row.custom_minimum_size.y = 48
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		lane.add_child(row)
		var capstone := tier == Profile.TALENT_TIER_COUNT - 1
		var band := VBoxContainer.new()
		band.alignment = BoxContainer.ALIGNMENT_CENTER
		band.custom_minimum_size.x = 51
		row.add_child(band)
		var edge := tint.darkened(0.48) if locked else (Color("ffcf75") if capstone else tint)
		var tag := add_chip(band, "TIER %d" % (tier + 1), null, edge, 13, 20)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var choices := HBoxContainer.new()
		choices.alignment = BoxContainer.ALIGNMENT_CENTER
		choices.add_theme_constant_override("separation", 42 if tier == 1 else 18)
		choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(choices)
		var tiles: Array[Button] = []
		for item in Profile.UPGRADES:
			if item.branch == branch and item.tier == tier:
				var tile := add_talent(choices, item, edge, locked)
				if not tiles.is_empty():
					var previous: Button = tiles.back()
					tile.focus_neighbor_left = tile.get_path_to(previous)
					previous.focus_neighbor_right = previous.get_path_to(tile)
				tiles.append(tile)
				tile.item_rect_changed.connect(wiring.queue_redraw)
		levels.append(tiles)
	wiring.draw.connect(func(): draw_paths(wiring, levels, open, tint))

func draw_paths(layer: Control, levels: Array[Array], opened: Array[bool], tint: Color) -> void:
	var size := layer.size
	layer.draw_line(Vector2(1, 40), Vector2(size.x - 1, 40), Color(tint, .30), 1.0, true)
	layer.draw_line(Vector2(9, 55), Vector2(9, size.y - 10), Color(tint, .27), 1.0, true)
	layer.draw_line(Vector2(size.x * .29, size.y - 2), Vector2(size.x * .71, size.y - 2), Color(tint, .48), 2.0, true)
	for tier in range(1, levels.size()):
		var from: Array = levels[tier - 1]
		var to: Array = levels[tier]
		if from.is_empty() or to.is_empty():
			continue
		var upper: Rect2 = from[0].get_global_rect()
		var lower: Rect2 = to[0].get_global_rect()
		var at := layer.global_position
		var y := (upper.end.y + lower.position.y) * .5 - at.y
		var start: float = minf(from.front().get_global_rect().get_center().x, to.front().get_global_rect().get_center().x) - at.x
		var end: float = maxf(from.back().get_global_rect().get_center().x, to.back().get_global_rect().get_center().x) - at.x
		var stroke := Color(tint, .74) if opened[tier] else Color("435678")
		if opened[tier]:
			layer.draw_line(Vector2(start, y), Vector2(end, y), Color(tint, .15), 5.0, true)
		layer.draw_line(Vector2(start, y), Vector2(end, y), stroke, 1.4, true)
		for source in from:
			var rect: Rect2 = source.get_global_rect()
			var x := rect.get_center().x - at.x
			layer.draw_line(Vector2(x, rect.end.y - at.y), Vector2(x, y), stroke, 1.4, true)
		for target in to:
			var rect: Rect2 = target.get_global_rect()
			var x := rect.get_center().x - at.x
			var port := Vector2(x, rect.position.y - at.y - 1)
			layer.draw_line(Vector2(x, y), port, stroke, 1.4, true)
			layer.draw_circle(port, 2.6, stroke, true, -1.0, true)
			layer.draw_circle(port, 1.3, Color("dbffff") if opened[tier] else Color("8493b2"), true, -1.0, true)

func add_talent(parent: HBoxContainer, item: Dictionary, tint: Color, locked: bool) -> Button:
	var id: String = item.id
	var installed: int = profile.rank(id)
	var tile := UI.button(parent, "", func():
		inspect(nodes[id])
		if not purchase.disabled:
			purchase.grab_focus()
	, false, TILE_SIZE, false)
	nodes[id] = tile
	tile.set_meta(&"talent_id", id)
	tile.set_meta(&"talent", item)
	tile.custom_minimum_size = Vector2(TILE_SIZE, TILE_SIZE)
	tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tile.icon = Icons.icon(item.icon, CATEGORY_ICONS[item.branch])
	tile.expand_icon = true
	tile.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tile.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	tile.add_theme_constant_override("icon_max_width", 25)
	tile.theme = tooltip_style
	tile.add_theme_color_override("icon_normal_color", Color("687c9c") if locked else Color.WHITE)
	tile.tooltip_text = tooltip(item)
	var capstone: bool = item.tier == Profile.TALENT_TIER_COUNT - 1
	var idle := UI.tile_frame("item_slot_legendary" if capstone and not locked else "item_slot_common")
	idle.modulate_color = Color("5a698b") if locked else tint.lerp(Color.WHITE, .32)
	idle.content_margin_top = 2
	idle.content_margin_bottom = 12
	var active := idle.duplicate() as StyleBoxTexture
	active.modulate_color = Color(1.75, 1.20, 2.10)
	var marked := active.duplicate() as StyleBoxTexture
	marked.modulate_color = Color(1.90, 1.38, 2.30)
	UI.set_button_states(tile, idle, active, marked)
	tile.toggle_mode = true
	var counter := UI.label(tile, "%d/%d" % [installed, item.prices.size()], 12, tint if installed > 0 else UI.MUTED)
	counter.autowrap_mode = TextServer.AUTOWRAP_OFF
	counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	counter.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	counter.offset_top = -15
	counter.offset_bottom = -1
	tile.focus_entered.connect(func(): inspect(tile))
	tile.mouse_entered.connect(tile.grab_focus)
	return tile

func tooltip(item: Dictionary) -> String:
	var rank: int = profile.rank(item.id)
	var lines := PackedStringArray(["%s  ·  %s  ·  Tier %d" % [item.name, item.branch, item.tier + 1]])
	if rank > 0:
		lines.append("Rank %s active  ·  %s" % [Profile.TALENT_RANKS[rank - 1], Profile.talent_effect(item, rank - 1)])
	if rank < item.prices.size():
		lines.append("Rank %s  ·  %s" % [Profile.TALENT_RANKS[rank], Profile.talent_effect(item, rank)])
		lines.append("%s Core Shards  ·  Player Lv. %d" % [UI.shard_amount(Profile.talent_price(item, rank)), item.levels[rank]])
		var gate: String = profile.talent_gate(item.branch, item.tier)
		if not gate.is_empty():
			lines.append(gate)
	else:
		lines.append("Fully ranked")
	return "\n".join(lines)

func build_inspector(buy: Callable, status: String) -> void:
	var panel := UI.equipment_card(UI.CYAN)
	panel.custom_minimum_size.y = 87
	add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var badge := PanelContainer.new()
	var slot := UI.tile_frame("item_slot_rare")
	badge.add_theme_stylebox_override("panel", slot)
	badge.custom_minimum_size = Vector2(66, 66)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(badge)
	portrait = TextureRect.new()
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	badge.add_child(portrait)
	var info := UI.column(row, 2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	var headline := HBoxContainer.new()
	headline.add_theme_constant_override("separation", 8)
	info.add_child(headline)
	heading = UI.label(headline, "", 25)
	heading.autowrap_mode = TextServer.AUTOWRAP_OFF
	rank_caption = UI.label(headline, "", 17)
	rank_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rank_caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	tier_caption = UI.label(info, "", 13, UI.CYAN)
	current_effect = UI.label(info, "", 15, UI.CYAN)
	next_effect = UI.label(info, "", 15)
	row.add_child(VSeparator.new())
	var actions := UI.column(row, 4)
	actions.custom_minimum_size.x = 321
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	var rail := HBoxContainer.new()
	rail.add_theme_constant_override("separation", 7)
	actions.add_child(rail)
	price = add_chip(rail, "", SHARD, UI.VIOLET, 16, 35)
	var cost_panel := price.get_parent().get_parent() as PanelContainer
	cost_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	price_icon = price.get_parent().get_child(0)
	purchase = UI.button(rail, "Install", func(): buy.call(selection.get_meta(&"talent_id")), true, 35, false)
	purchase.custom_minimum_size.x = 112
	var idle := UI.frame(Color("12465d"), UI.CYAN, 2)
	idle.shadow_color = Color(UI.CYAN, 0.52)
	idle.shadow_size = 5
	var active := UI.frame(Color("382559"), UI.VIOLET, 2)
	active.shadow_color = Color(UI.VIOLET, 0.52)
	active.shadow_size = 5
	UI.set_button_states(purchase, idle, active, active)
	requirements = UI.label(actions, "", 13, UI.MUTED)
	requirements.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	feedback = UI.label(actions, status, 13, UI.VIOLET)
	feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	feedback.visible = not status.is_empty()

func inspect(tile: Button) -> void:
	if selection and selection != tile:
		selection.set_pressed_no_signal(false)
		feedback.hide()
	selection = tile
	tile.set_pressed_no_signal(true)
	purchase.focus_neighbor_top = purchase.get_path_to(tile)
	purchase.focus_neighbor_left = purchase.get_path_to(tile)
	var item: Dictionary = tile.get_meta(&"talent")
	var tint: Color = COLORS[item.branch]
	var installed: int = profile.rank(item.id)
	var maximum: int = item.prices.size()
	var maxed := installed == maximum
	tier_caption.text = "%s  /  TIER %d%s" % [item.branch.to_upper(), item.tier + 1, "  /  CAPSTONE" if item.tier == Profile.TALENT_TIER_COUNT - 1 else ""]
	tier_caption.add_theme_color_override("font_color", tint)
	portrait.texture = tile.icon
	heading.text = item.name
	rank_caption.text = "%d/%d" % [installed, maximum]
	rank_caption.add_theme_color_override("font_color", tint)
	current_effect.visible = installed > 0
	current_effect.text = "Active  ·  " + Profile.talent_effect(item, installed - 1) if installed > 0 else ""
	next_effect.visible = not maxed
	next_effect.text = "Rank %s  ·  %s" % [Profile.TALENT_RANKS[installed], Profile.talent_effect(item, installed)] if not maxed else ""
	var gate: String = profile.talent_gate(item.branch, item.tier)
	var blocked: String = profile.talent_lock(item)
	var cost := Profile.talent_price(item, installed) if not maxed else 0
	if not maxed and profile.core_shards < cost:
		gate += "  ·  " if not gate.is_empty() else ""
		gate += "Need %s more Core Shards" % UI.shard_amount(cost - profile.core_shards)
	requirements.text = gate
	requirements.visible = not gate.is_empty() and not maxed
	price.text = "%s SHARDS  ·  LV. %d" % [UI.shard_amount(cost), item.levels[installed]] if not maxed else "ALL RANKS INSTALLED"
	price_icon.visible = not maxed
	purchase.text = "Rank III" if maxed else ("Install" if installed == 0 else "Upgrade")
	if not maxed and not Input.get_connected_joypads().is_empty():
		purchase.text = ("%s  ·  " % ("Cross" if RiftSettings.controller_style == 1 else "A")) + purchase.text
	purchase.disabled = not blocked.is_empty()

static func add_chip(parent: Control, text: String, icon: Texture2D, edge: Color, font_size: int, height: float) -> Label:
	var frame := PanelContainer.new()
	parent.add_child(frame)
	frame.custom_minimum_size.y = height
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var skin := UI.frame(Color(edge.darkened(.88), .90), edge, 2)
	skin.content_margin_left = 8
	skin.content_margin_right = 8
	skin.content_margin_top = 2
	skin.content_margin_bottom = 2
	frame.add_theme_stylebox_override("panel", skin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	frame.add_child(row)
	if icon:
		var badge := TextureRect.new()
		badge.texture = icon
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		badge.custom_minimum_size = Vector2.ONE * (height - 5)
		row.add_child(badge)
	var label := UI.label(row, text, font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label
