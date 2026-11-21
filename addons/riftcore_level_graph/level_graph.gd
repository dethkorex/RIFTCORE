@tool
extends VBoxContainer

signal open_scene_requested(path: String)
signal anchor_requested(path: String, anchor: String)
signal add_selection_requested

const Catalog := preload("res://scripts/sector_catalog.gd")
const MAPS := "res://addons/riftcore_level_graph/maps/"
const TYPES := {
	"Start": Color("79e9d1"),
	"Route": Color("86afff"),
	"Hazard": Color("ff9964"),
	"Reward": Color("edbe75"),
	"Relay": Color("ec9bf4"),
	"Checkpoint": Color("8de6ae"),
	"Arena": Color("ff8d9c"),
	"Exit": Color("79e9d1"),
}

var scene_path := ""
var acts: Array[String] = []
var documents: Dictionary = {}
var changed: Dictionary = {}
var document: Dictionary
var cards: Dictionary[String, GraphNode] = {}
var active_card := ""
var graph: GraphEdit
var notice: Label
var save_button: Button
var details: HBoxContainer
var title_field: LineEdit
var kind_field: OptionButton
var notes_field: LineEdit
var anchor_label: Label

func _ready() -> void:
	custom_minimum_size.y = 310
	var toolbar := HBoxContainer.new()
	add_child(toolbar)
	var level_picker := OptionButton.new()
	toolbar.add_child(level_picker)
	for sector in Catalog.SECTORS:
		for act in [1, 2]:
			var path: String = sector.level if act == 1 else "res://scenes/levels/%s_act_2.tscn" % sector.id
			acts.append(path)
			level_picker.add_item("%s  /  Act %s" % [sector.title, "I" if act == 1 else "II"])
	level_picker.item_selected.connect(func(index: int): view_act(acts[index]))
	level_picker.select(0)
	button(toolbar, "Open act", func(): open_scene_requested.emit(scene_path))
	button(toolbar, "Add selected", func(): add_selection_requested.emit())
	button(toolbar, "Fit graph", fit_graph)
	button(toolbar, "Check routes", check_routes)
	save_button = button(toolbar, "Save graph", save_graph)

	graph = GraphEdit.new()
	graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph.zoom_min = 0.25
	graph.show_minimap_button = true
	graph.right_disconnects = true
	graph.connection_request.connect(connect_rooms)
	graph.disconnection_request.connect(disconnect_rooms)
	graph.delete_nodes_request.connect(remove_rooms)
	graph.node_selected.connect(edit_card)
	graph.node_deselected.connect(func(card: Node):
		if str(card.name) == active_card:
			active_card = ""
			details.hide()
	)
	add_child(graph)

	details = HBoxContainer.new()
	add_child(details)
	title_field = LineEdit.new()
	title_field.placeholder_text = "Card title"
	title_field.custom_minimum_size.x = 160
	title_field.text_changed.connect(func(value: String): update_card("title", value))
	details.add_child(title_field)
	kind_field = OptionButton.new()
	for kind in TYPES:
		kind_field.add_item(kind)
	kind_field.item_selected.connect(func(index: int): update_card("type", kind_field.get_item_text(index)))
	details.add_child(kind_field)
	notes_field = LineEdit.new()
	notes_field.placeholder_text = "Traversal, hazard, or reward note"
	notes_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	notes_field.text_changed.connect(func(value: String): update_card("notes", value))
	details.add_child(notes_field)
	anchor_label = Label.new()
	anchor_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	anchor_label.custom_minimum_size.x = 142
	details.add_child(anchor_label)
	button(details, "Show in 3D", func(): anchor_requested.emit(scene_path, document.rooms[active_card].path))
	details.hide()

	notice = Label.new()
	notice.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(notice)
	view_act(acts.front())

func button(parent: Control, label: String, action: Callable) -> Button:
	var control := Button.new()
	control.text = label
	control.pressed.connect(action)
	parent.add_child(control)
	return control

func map_path() -> String:
	return MAPS + scene_path.get_file().get_basename() + ".json"

func view_act(path: String) -> void:
	scene_path = path
	notice.text = "Drag between ports to connect routes. Select a card to edit it."
	if not documents.has(path):
		var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(map_path())) if FileAccess.file_exists(map_path()) else null
		if saved is Dictionary and saved.get("rooms") is Dictionary and saved.get("routes") is Array:
			documents[path] = saved
		else:
			documents[path] = {"rooms": {}, "routes": []}
			notice.text = "Open the act and use Add selected to map its first room or marker."
	active_card = ""
	details.hide()
	graph.clear_connections()
	for card in cards.values():
		graph.remove_child(card)
		card.queue_free()
	cards.clear()
	document = documents[path]
	for id in document.rooms:
		create_card(id)
	for route in document.routes:
		if cards.has(route[0]) and cards.has(route[1]):
			graph.connect_node(route[0], 0, route[1], 0)
	save_button.disabled = not changed.has(scene_path)
	graph.zoom = 1.0 if cards.is_empty() else 0.55
	graph.scroll_offset = Vector2(-18, 0)

func create_card(id: String) -> void:
	var room: Dictionary = document.rooms[id]
	var card := GraphNode.new()
	card.name = id
	card.title = room.title
	card.custom_minimum_size.x = 210
	var description := Label.new()
	description.name = "Description"
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(172, 50)
	card.add_child(description)
	var at: Array = room.position
	card.position_offset = Vector2(at[0], at[1])
	paint_card(card, room)
	graph.add_child(card)
	cards[id] = card
	card.position_offset_changed.connect(func():
		var offset := card.position_offset
		room.position = [offset.x, offset.y]
		mark_changed()
	)

func paint_card(card: GraphNode, room: Dictionary) -> void:
	var color: Color = TYPES.get(room.type, TYPES["Route"])
	var description := card.get_node("Description") as Label
	description.text = "%s\n%s" % [room.type, room.notes]
	card.get_titlebar_hbox().modulate = color
	card.set_slot(0, true, 0, color, true, 0, color)

func edit_card(card: Node) -> void:
	active_card = str(card.name)
	var room: Dictionary = document.rooms[active_card]
	title_field.text = room.title
	kind_field.select(maxi(0, TYPES.keys().find(room.type)))
	notes_field.text = room.notes
	anchor_label.text = room.path.get_file()
	anchor_label.tooltip_text = room.path
	details.show()

func update_card(key: String, value: String) -> void:
	if active_card.is_empty():
		return
	var room: Dictionary = document.rooms[active_card]
	room[key] = value
	var card: GraphNode = cards[active_card]
	card.title = room.title
	paint_card(card, room)
	mark_changed()

func add_anchor(path: String, label: String) -> void:
	for id in document.rooms:
		if document.rooms[id].path == path:
			graph.set_selected(cards[id])
			edit_card(cards[id])
			return
	var id := "room_%d" % Time.get_ticks_usec()
	var at := (graph.scroll_offset + Vector2(44, 70 + cards.size() % 4 * 84)) / graph.zoom
	document.rooms[id] = {"title": label, "path": path, "type": "Route", "notes": "", "position": [at.x, at.y]}
	create_card(id)
	graph.set_selected(cards[id])
	edit_card(cards[id])
	mark_changed()

func connect_rooms(from: StringName, _from_port: int, to: StringName, _to_port: int) -> void:
	if from == to or graph.is_node_connected(from, 0, to, 0):
		return
	if graph.connect_node(from, 0, to, 0) == OK:
		document.routes.append([str(from), str(to)])
		mark_changed()

func disconnect_rooms(from: StringName, _from_port: int, to: StringName, _to_port: int) -> void:
	graph.disconnect_node(from, 0, to, 0)
	document.routes.erase([str(from), str(to)])
	mark_changed()

func remove_rooms(ids: Array[StringName]) -> void:
	var routes: Array = document.routes.duplicate()
	for route in routes:
		if StringName(route[0]) in ids or StringName(route[1]) in ids:
			disconnect_rooms(route[0], 0, route[1], 0)
	for id in ids:
		var key := str(id)
		if cards.has(key):
			cards[key].queue_free()
			cards.erase(key)
			document.rooms.erase(key)
	active_card = ""
	details.hide()
	mark_changed()

func fit_graph() -> void:
	if cards.is_empty():
		graph.zoom = 1.0
		graph.scroll_offset = Vector2.ZERO
		return
	var bounds := Rect2(cards.values()[0].position_offset, Vector2.ZERO)
	for card in cards.values():
		bounds = bounds.expand(card.position_offset)
		bounds = bounds.expand(card.position_offset + card.size)
	var usable := (graph.size - Vector2(44, 44)).max(Vector2(140, 90))
	graph.zoom = clampf(minf(usable.x / maxf(bounds.size.x, 1.0), usable.y / maxf(bounds.size.y, 1.0)), graph.zoom_min, 1.0)
	graph.scroll_offset = bounds.position * graph.zoom - Vector2(20, 20)

func mark_changed() -> void:
	changed[scene_path] = true
	save_button.disabled = false

func save_graph() -> void:
	var file := FileAccess.open(map_path(), FileAccess.WRITE)
	if file == null:
		notice.text = "Could not save this graph. Check the project folder permissions."
		return
	file.store_string(JSON.stringify(document, "\t") + "\n")
	file.close()
	changed.erase(scene_path)
	save_button.disabled = true
	notice.text = "Saved %d cards and %d connections." % [cards.size(), document.routes.size()]

func route_problems(anchors: Dictionary) -> PackedStringArray:
	var problems := PackedStringArray()
	var starts: Array[String] = []
	var exits: Array[String] = []
	for id in document.rooms:
		var room: Dictionary = document.rooms[id]
		if not anchors.has(room.path):
			problems.append("Missing anchor for %s" % room.title)
		if room.type == "Start":
			starts.append(id)
		elif room.type == "Exit":
			exits.append(id)
	if starts.is_empty():
		problems.append("Mark a Start card")
	if exits.is_empty():
		problems.append("Mark an Exit card")
	var outgoing := {}
	var incoming := {}
	for edge in document.routes:
		if not document.rooms.has(edge[0]) or not document.rooms.has(edge[1]):
			problems.append("Connection points to a missing card")
			continue
		if not outgoing.has(edge[0]):
			outgoing[edge[0]] = []
		outgoing[edge[0]].append(edge[1])
		if not incoming.has(edge[1]):
			incoming[edge[1]] = []
		incoming[edge[1]].append(edge[0])
	var reachable := reachable_from(starts, outgoing)
	var can_exit := reachable_from(exits, incoming)
	for id in document.rooms:
		var title: String = document.rooms[id].title
		if not starts.is_empty() and not reachable.has(id):
			problems.append("No route from Start to %s" % title)
		elif not exits.is_empty() and not can_exit.has(id):
			problems.append("No route from %s to an Exit" % title)
	return problems

func reachable_from(origins: Array[String], links: Dictionary) -> Dictionary:
	var frontier := origins.duplicate()
	var reachable := {}
	while not frontier.is_empty():
		var current: String = frontier.pop_front()
		if not reachable.has(current):
			reachable[current] = true
			frontier.append_array(links.get(current, []))
	return reachable

func check_routes() -> void:
	var current := EditorInterface.get_edited_scene_root()
	var preview: Node
	if current == null or current.scene_file_path != scene_path:
		var scene := load(scene_path) as PackedScene
		if scene == null:
			notice.text = "Could not load this act's scene."
			return
		preview = scene.instantiate()
		current = preview
	var anchors := {}
	for room in document.rooms.values():
		if current.has_node(NodePath(room.path)):
			anchors[room.path] = true
	if preview:
		preview.free()
	var problems := route_problems(anchors)
	var message := "\n".join(problems)
	if problems.is_empty():
		message = "All anchors exist and every card connects from Start to an Exit. Playtest traversal and traps in the game."
	var report := AcceptDialog.new()
	report.title = "Route Check"
	report.dialog_text = message
	add_child(report)
	report.confirmed.connect(report.queue_free)
	report.canceled.connect(report.queue_free)
	report.popup_centered()
