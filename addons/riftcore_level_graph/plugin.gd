@tool
extends EditorPlugin

const LevelGraph := preload("res://addons/riftcore_level_graph/level_graph.gd")

var panel: LevelGraph
var pending_anchor := ""

func _enter_tree() -> void:
	panel = LevelGraph.new()
	panel.open_scene_requested.connect(open_scene)
	panel.anchor_requested.connect(open_anchor)
	panel.add_selection_requested.connect(add_selected_anchor)
	scene_changed.connect(select_pending_anchor)
	add_control_to_bottom_panel(panel, "Level Graph")

func _exit_tree() -> void:
	scene_changed.disconnect(select_pending_anchor)
	remove_control_from_bottom_panel(panel)
	panel.queue_free()

func open_scene(path: String) -> void:
	pending_anchor = ""
	EditorInterface.open_scene_from_path(path)
	EditorInterface.set_main_screen_editor("3D")

func open_anchor(path: String, anchor: String) -> void:
	var root := EditorInterface.get_edited_scene_root()
	pending_anchor = anchor
	if root != null and root.scene_file_path == path:
		select_pending_anchor(root)
	else:
		EditorInterface.open_scene_from_path(path)

func select_pending_anchor(root: Node) -> void:
	if pending_anchor.is_empty() or root == null or root.scene_file_path != panel.scene_path:
		return
	var node := root.get_node_or_null(NodePath(pending_anchor))
	pending_anchor = ""
	if node == null:
		panel.notice.text = "That scene anchor is missing. Use Check routes to find other missing links."
		return
	EditorInterface.set_main_screen_editor("3D")
	EditorInterface.get_selection().clear()
	EditorInterface.edit_node(node)
	panel.notice.text = "%s selected in 3D. Hover over the viewport and press F to frame it." % node.name

func add_selected_anchor() -> void:
	var root := EditorInterface.get_edited_scene_root()
	if root == null or root.scene_file_path != panel.scene_path:
		panel.notice.text = "Open this act, then select a node in its Scene tree."
		return
	var selected := EditorInterface.get_selection().get_selected_nodes()
	if selected.size() != 1 or selected[0] == root or not selected[0] is Node3D:
		panel.notice.text = "Select one room, platform, or marker in the Scene tree."
		return
	panel.add_anchor(str(root.get_path_to(selected[0])), str(selected[0].name).capitalize())
