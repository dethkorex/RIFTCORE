extends Control

const UI := preload("res://scripts/rift_ui.gd")
const GEOMETRY_CACHE := &"mission_map_geometry"
const TRACE := Color("4697b4")

var stage_source: Callable
var party_source: Callable
var names_source: Callable
var operator: Callable
var expanded := false
var refresh_left := 0.0
var map_data: Dictionary
var frame := UI.hud_frame(UI.CYAN, Vector2.ZERO)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true

func _process(delta: float) -> void:
	if not is_visible_in_tree() or not stage_source.is_valid():
		return
	refresh_left -= delta
	if refresh_left > 0.0:
		return
	refresh_left = 0.1
	var stage := stage_source.call() as Node3D
	if not is_instance_valid(stage):
		map_data = {}
		queue_redraw()
		return
	if not stage.has_meta(GEOMETRY_CACHE):
		stage.set_meta(GEOMETRY_CACHE, capture(stage))
	map_data = stage.get_meta(GEOMETRY_CACHE)
	queue_redraw()

static func capture(stage: Node3D) -> Dictionary:
	var lines := PackedVector2Array()
	var terrain := stage.get_node_or_null("TERRAIN")
	if terrain:
		for collider in terrain.find_children("*", "CollisionShape3D", true, false):
			var body := collider.get_parent() as PhysicsBody3D
			if (body is StaticBody3D or body is AnimatableBody3D) and (body.collision_layer & 1) != 0 \
					and not collider.disabled and collider.shape is BoxShape3D:
				var half: Vector3 = collider.shape.size * 0.5
				var bounds: AABB = collider.global_transform * AABB(-half, half * 2.0)
				add_box(lines, bounds)
		for hull in terrain.find_children("*", "CSGShape3D", true, false):
			if not hull.use_collision or (hull.collision_layer & 1) == 0:
				continue
			if hull is CSGBox3D:
				var half: Vector3 = hull.size * 0.5
				add_box(lines, hull.global_transform * AABB(-half, half * 2.0))
			elif hull is CSGPolygon3D:
				for i in hull.polygon.size():
					var a: Vector2 = hull.polygon[i]
					var b: Vector2 = hull.polygon[(i + 1) % hull.polygon.size()]
					lines.append(project(hull.to_global(Vector3(a.x, a.y, 0.0))))
					lines.append(project(hull.to_global(Vector3(b.x, b.y, 0.0))))
	var spawn := stage.get_node_or_null("MARKERS/PlayerSpawn") as Node3D
	var exit := stage.get_node_or_null("MARKERS/RoomExit") as Node3D
	var start := project(spawn.global_position) if spawn else Vector2.ZERO
	var end := project(exit.global_position) if exit else start + Vector2(60, 0)
	var world := Rect2(start, Vector2.ZERO).expand(end)
	for point in lines:
		world = world.expand(point)
	return {"lines": lines, "bounds": world.grow(3.0), "exit": end}

static func add_box(lines: PackedVector2Array, bounds: AABB) -> void:
	if bounds.end.z < -0.4 or bounds.position.z > 0.4:
		return
	var left := project(Vector3(bounds.position.x, bounds.end.y, 0.0))
	var right := left + Vector2(bounds.size.x, 0.0)
	lines.append(left)
	lines.append(right)
	if bounds.size.y > 1.2:
		lines.append(left)
		lines.append(left + Vector2(0, bounds.size.y))
		lines.append(right)
		lines.append(right + Vector2(0, bounds.size.y))

static func project(at: Vector3) -> Vector2:
	return Vector2(at.x, -at.y)

func _draw() -> void:
	var local := operator.call() as RiftPlayer if operator.is_valid() else null
	if map_data.is_empty() or not is_instance_valid(local) or size.x < 140 or size.y < 56:
		return
	draw_style_box(frame, Rect2(Vector2.ZERO, size))
	draw_string(UI.DISPLAY, Vector2(10, 19), "//  SECTOR MAP", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, UI.CYAN)
	var area := Rect2(Vector2(9, 26), size - Vector2(18, 34))
	for x in range(0, int(area.size.x), 18):
		draw_line(area.position + Vector2(x, 0), area.position + Vector2(x, area.size.y), Color("163346"))
	for y in range(0, int(area.size.y), 18):
		draw_line(area.position + Vector2(0, y), area.position + Vector2(area.size.x, y), Color("163346"))
	var world: Rect2 = map_data.bounds
	if not expanded:
		var view_size := Vector2(78, 78 * area.size.y / area.size.x)
		world = Rect2(project(local.global_position) - view_size * 0.5, view_size)
	var zoom := minf(area.size.x / world.size.x, area.size.y / world.size.y)
	var center := area.get_center() - world.get_center() * zoom
	var lines: PackedVector2Array = map_data.lines
	var visible_lines := PackedVector2Array()
	for index in range(0, lines.size(), 2):
		var a := center + lines[index] * zoom
		var b := center + lines[index + 1] * zoom
		if Rect2(a.min(b), (a - b).abs()).grow(1.0).intersects(area):
			visible_lines.append(a.clamp(area.position, area.end))
			visible_lines.append(b.clamp(area.position, area.end))
	if not visible_lines.is_empty():
		draw_multiline(visible_lines, TRACE, 1.15, true)
	var exit := center + Vector2(map_data.exit) * zoom
	if area.has_point(exit):
		draw_line(exit - Vector2(0, 5), exit + Vector2(0, 5), UI.VIOLET, 2, true)
		draw_line(exit - Vector2(4, 5), exit + Vector2(4, 5), UI.VIOLET, 2, true)
	var party: Array = party_source.call() if party_source.is_valid() else [local]
	var labels: Array = names_source.call() if expanded and names_source.is_valid() else []
	for index in party.size():
		var member := party[index] as RiftPlayer
		if not is_instance_valid(member):
			continue
		var target := center + project(member.global_position) * zoom
		var display := target.clamp(area.position + Vector2(5, 5), area.end - Vector2(5, 5))
		var color: Color = UI.PARTY_COLORS[index % UI.PARTY_COLORS.size()]
		if member == local:
			color = UI.WHITE
		elif member.health <= 0.0:
			color = Color("ff818b")
		draw_circle(display, 9.0, Color(color, 0.19), true, -1, true)
		draw_circle(display, 4.0, color, true, -1, true)
		if expanded:
			var caption := "YOU" if member == local else (String(labels[index]) if index < labels.size() else "ALLY %d" % (index + 1))
			var label_at := Vector2(minf(display.x + 7, area.end.x - 70), clampf(display.y - 8, area.position.y + 14, area.end.y))
			draw_string(UI.DISPLAY, label_at, caption, HORIZONTAL_ALIGNMENT_LEFT, 94, 14, color)
