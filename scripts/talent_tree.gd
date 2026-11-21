extends VBoxContainer

const UI := preload("res://scripts/rift_ui.gd")
const Profile := preload("res://scripts/rogue_profile.gd")
const Icons := preload("res://scripts/equipment_icons.gd")
const SHARD := preload("res://assets/ui/core-shard.svg")
const COLORS := {"Survivability": Color("49efa3"), "Damage": Color("ffab55"), "Scavenger": Color("35e2ff")}
const CATEGORY_ICONS := {"Survivability": "frame", "Damage": "arm", "Scavenger": "visor"}
const EMBLEMS := {"Survivability": "aegis", "Damage": "pulse_lens", "Scavenger": "talent_case"}
const TILE_SIZE := Vector2(51, 43)

var profile
var selection: Button
var nodes: Dictionary = {}
var tooltip_style: Theme
var portrait: TextureRect
var portrait_frame: PanelContainer
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
	add_theme_constant_override("separation", 6)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	tooltip_style = Theme.new()
	tooltip_style.set_stylebox("panel", "TooltipPanel", UI.frame(Color("07182b"), UI.CYAN, 2))
	tooltip_style.set_font("font", "TooltipLabel", UI.DISPLAY)
	tooltip_style.set_color("font_color", "TooltipLabel", UI.WHITE)
	build_header()
	var board := PanelContainer.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.add_theme_stylebox_override("panel", UI.profile_frame(Color("071421"), Color("367495"), Vector2(12, 11)))
	add_child(board)
	var body := UI.column(board, 10)
	var lanes := HBoxContainer.new()
	lanes.add_theme_constant_override("separation", 12)
	lanes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(lanes)
	build_inspector(body, buy, status)
	for branch in Profile.TALENT_BRANCHES:
		build_branch(lanes, branch)
	if not nodes.has(focus_id):
		focus_id = Profile.UPGRADES[0].id
	var initial: Button = nodes[focus_id]
	inspect(initial)
	initial.grab_focus()

func build_header() -> void:
	var banner := PanelContainer.new()
	banner.add_theme_stylebox_override("panel", UI.profile_frame(Color("0a2030"), Color("3b809e"), Vector2(13, 5)))
	add_child(banner)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	banner.add_child(row)
	var icon := TextureRect.new()
	icon.texture = Icons.icon("quick_energy", "quick_energy")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(28, 28)
	row.add_child(icon)
	UI.profile_label(row, "CORE ASCENSION", 27, UI.CYAN)
	add_stripes(row, UI.CYAN)
	var hint := UI.label(row, "Install a talent in each earlier tier to unlock the next tier of that branch.", 16, UI.MUTED)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var level := add_chip(row, "PLAYER LV. %d" % profile.player_level(), null, Color("5483a3"), 17, 29)
	level.add_theme_color_override("font_color", Color("ffd079"))

func build_branch(parent: HBoxContainer, branch: String) -> void:
	var tint: Color = COLORS[branch]
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UI.profile_frame(Color("081520").lerp(tint, .045), tint.darkened(.18), Vector2(10, 8)))
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(frame)
	var wiring := Control.new()
	wiring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(wiring)
	var lane := UI.column(frame, 0)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	lane.add_child(header)
	var mast := add_chip(header, branch.to_upper(), Icons.icon(EMBLEMS[branch], CATEGORY_ICONS[branch]), tint, 24, 35)
	var mast_panel := mast.get_parent().get_parent() as PanelContainer
	mast_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_stripes(header, tint)
	var levels: Array[Array] = []
	var open: Array[bool] = []
	var tier_tags: Array[Label] = []
	for tier in Profile.TALENT_TIER_COUNT:
		var locked: bool = not profile.talent_gate(branch, tier).is_empty()
		open.append(not locked)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 0)
		row.custom_minimum_size.y = TILE_SIZE.y + 6
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		lane.add_child(row)
		var capstone := tier == Profile.TALENT_TIER_COUNT - 1
		var band := VBoxContainer.new()
		band.alignment = BoxContainer.ALIGNMENT_CENTER
		band.custom_minimum_size.x = 60
		row.add_child(band)
		var edge := tint.darkened(0.24) if locked else tint
		var tag := add_chip(band, "TIER %d" % (tier + 1), null, edge, 13, 20)
		var tag_panel := tag.get_parent().get_parent() as PanelContainer
		tag_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
		tier_tags.append(tag)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var choices := HBoxContainer.new()
		choices.alignment = BoxContainer.ALIGNMENT_CENTER
		choices.add_theme_constant_override("separation", 39 if tier == 1 else 20)
		choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(choices)
		var tiles: Array[Button] = []
		for item in Profile.UPGRADES:
			if item.branch == branch and item.tier == tier:
				var tile := add_talent(choices, item, Color("ffcf75") if capstone and not locked else tint, locked)
				if not tiles.is_empty():
					var previous: Button = tiles.back()
					tile.focus_neighbor_left = tile.get_path_to(previous)
					previous.focus_neighbor_right = previous.get_path_to(tile)
				tiles.append(tile)
				tile.item_rect_changed.connect(wiring.queue_redraw)
		levels.append(tiles)
	wiring.draw.connect(func(): draw_paths(wiring, levels, open, tier_tags, tint))
	wiring.resized.connect(wiring.queue_redraw)

func draw_paths(layer: Control, levels: Array[Array], opened: Array[bool], tags: Array[Label], tint: Color) -> void:
	var size := layer.size
	var at := layer.global_position
	var rail_x := 4.0
	var start_y := tags[0].get_global_rect().get_center().y - at.y
	var end_y := tags[tags.size() - 1].get_global_rect().get_center().y - at.y
	layer.draw_colored_polygon(PackedVector2Array([
		Vector2(size.x - 5, 45), Vector2(size.x - 5, size.y - 2),
		Vector2(size.x * .41, size.y - 2),
	]), Color(tint, .045))
	layer.draw_line(Vector2(2, 37), Vector2(size.x - 2, 37), Color(tint, .42), 1.0, true)
	layer.draw_line(Vector2(rail_x, start_y), Vector2(rail_x, end_y), Color(tint, .48), 1.5, true)
	layer.draw_line(Vector2(3, size.y - 2), Vector2(size.x - 4, size.y - 2), Color(tint, .27), 1.0, true)
	layer.draw_line(Vector2(size.x - 43, size.y - 3), Vector2(size.x - 7, size.y - 3), tint, 2.0, true)
	for tier in tags.size():
		var dot := Vector2(rail_x, tags[tier].get_global_rect().get_center().y - at.y)
		layer.draw_circle(dot, 5.0, Color(tint, .19), true, -1.0, true)
		layer.draw_circle(dot, 3.2, tint if opened[tier] else tint.darkened(.26), true, -1.0, true)
		layer.draw_circle(dot, 1.7, Color("ecffff"), true, -1.0, true)
	for tier in range(1, levels.size()):
		var from: Array = levels[tier - 1]
		var to: Array = levels[tier]
		if from.is_empty() or to.is_empty():
			continue
		var upper: Rect2 = from[0].get_global_rect()
		var lower: Rect2 = to[0].get_global_rect()
		var y := (upper.end.y + lower.position.y) * .5 - at.y
		var start: float = minf(from.front().get_global_rect().get_center().x, to.front().get_global_rect().get_center().x) - at.x
		var end: float = maxf(from.back().get_global_rect().get_center().x, to.back().get_global_rect().get_center().x) - at.x
		var stroke := Color(tint, .74) if opened[tier] else Color("536d8a")
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
	, false, TILE_SIZE.y, false)
	nodes[id] = tile
	tile.set_meta(&"talent_id", id)
	tile.set_meta(&"talent", item)
	tile.custom_minimum_size = TILE_SIZE
	tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tile.icon = Icons.icon(item.icon, CATEGORY_ICONS[item.branch])
	tile.expand_icon = true
	tile.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tile.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	tile.add_theme_constant_override("icon_max_width", 25)
	tile.theme = tooltip_style
	tile.add_theme_color_override("icon_normal_color", Color("a4b7cc") if locked else Color.WHITE)
	tile.tooltip_text = tooltip(item)
	var idle := UI.profile_frame(Color("0b1e2c"), Color("63829f") if locked else tint.darkened(.16), Vector2(4, 0))
	var active := UI.profile_frame(Color("12314a"), UI.CYAN, Vector2(4, 0), true)
	var marked := UI.profile_frame(Color("133653"), Color("a2f6ff"), Vector2(4, 0), true)
	for skin in [idle, active, marked]:
		skin.content_margin_top = 2
		skin.content_margin_bottom = 11
	UI.set_button_states(tile, idle, active, marked)
	tile.toggle_mode = true
	var counter := UI.label(tile, "%d/%d" % [installed, item.prices.size()], 12, tint if installed > 0 else UI.WHITE)
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

func build_inspector(parent: VBoxContainer, buy: Callable, status: String) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.profile_frame(Color("0c2031"), Color("518aa8"), Vector2(12, 7)))
	parent.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	portrait_frame = PanelContainer.new()
	portrait_frame.custom_minimum_size = Vector2(68, 68)
	portrait_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(portrait_frame)
	portrait = TextureRect.new()
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_frame.add_child(portrait)
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
	actions.custom_minimum_size.x = 349
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	var rail := HBoxContainer.new()
	rail.add_theme_constant_override("separation", 7)
	actions.add_child(rail)
	price = add_chip(rail, "", SHARD, UI.VIOLET, 17, 38)
	var cost_panel := price.get_parent().get_parent() as PanelContainer
	cost_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	price_icon = price.get_parent().get_child(0)
	purchase = UI.button(rail, "Install", func(): buy.call(selection.get_meta(&"talent_id")), true, 38, false)
	purchase.custom_minimum_size.x = 127
	var idle := UI.profile_frame(Color("0d3042"), UI.CYAN, Vector2(9, 3), true)
	var active := UI.profile_frame(Color("164358"), Color("a2f6ff"), Vector2(9, 3), true)
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
	portrait_frame.add_theme_stylebox_override("panel", UI.profile_frame(Color("061723"), tint, Vector2(9, 9), true))
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

static func add_stripes(parent: HBoxContainer, tint: Color) -> void:
	var marks := Control.new()
	marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marks.custom_minimum_size.x = 38
	parent.add_child(marks)
	marks.draw.connect(func():
		for index in 3:
			var top := Vector2(13 + index * 8, marks.size.y * .5 - 7)
			marks.draw_colored_polygon(PackedVector2Array([
				top, top + Vector2(5, 0), top + Vector2(-7, 14), top + Vector2(-12, 14),
			]), Color(tint, .40 + index * .23))
	)
	marks.resized.connect(marks.queue_redraw)

static func add_chip(parent: Control, text: String, icon: Texture2D, edge: Color, font_size: int, height: float) -> Label:
	var frame := PanelContainer.new()
	parent.add_child(frame)
	frame.custom_minimum_size.y = height
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var skin := UI.profile_frame(Color("071421").lerp(edge, .075), edge, Vector2(7, 2))
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
