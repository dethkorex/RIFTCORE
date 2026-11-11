class_name RouteMapView
extends Control

var selected := 1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()

func _draw() -> void:
	var cyan := Color("38ddff")
	var dim := Color(0.25, 0.45, 0.62, 0.75)
	var purple := Color("b55cff")
	var nodes := [Vector2(35,135), Vector2(125,80), Vector2(125,190), Vector2(230,135), Vector2(335,70), Vector2(335,200), Vector2(455,135)]
	var edges := [[0,1],[0,2],[1,3],[2,3],[3,4],[3,5],[4,6],[5,6]]
	for edge in edges:
		draw_line(nodes[edge[0]], nodes[edge[1]], cyan if edge[0] <= selected else dim, 3.0)
	for i in range(nodes.size()):
		var color := purple if i == nodes.size() - 1 else (cyan if i <= selected else dim)
		draw_circle(nodes[i], 22.0 if i == selected else 17.0, Color(0.02,0.06,0.14,1))
		draw_arc(nodes[i], 22.0 if i == selected else 17.0, 0, TAU, 6, color, 3.0)
		var glyph: String = ["S", "X", "+", "U", "E", "?", "B"][i]
		draw_string(ThemeDB.fallback_font, nodes[i] + Vector2(-6,6), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		selected = clampi(selected + 1, 0, 5)
		queue_redraw()
