@tool
extends Node3D

enum Mark { PLUS, LIGHTNING, XP, NONE, MATERIAL, BLUEPRINT }

@export var tint := Color("52ff80")
@export var mark := Mark.PLUS
const RADIUS := 0.265
var facing_camera: Node3D

func _ready() -> void:
	var globe := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = RADIUS
	sphere.height = RADIUS * 2.0
	sphere.radial_segments = 24
	sphere.rings = 12
	globe.mesh = sphere
	var finish := ShaderMaterial.new()
	finish.shader = preload("res://assets/pickups/orb_finish.gdshader")
	finish.set_shader_parameter("tint", tint)
	finish.set_shader_parameter("mark", mark)
	globe.material_override = finish
	globe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(globe)
	facing_camera = Node3D.new()
	add_child(facing_camera)
	add_orbit()
	match mark:
		Mark.PLUS:
			add_text("+", Color.WHITE, 0.00385)
		Mark.LIGHTNING:
			add_lightning()
		Mark.XP:
			add_text("XP", Color.BLACK, 0.00205)
		Mark.MATERIAL:
			add_text("MAT", Color("fff3e4"), 0.0016)
		Mark.BLUEPRINT:
			add_text("BP", Color("e9faff"), 0.0020)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or not facing_camera:
		return
	var camera := get_viewport().get_camera_3d()
	if camera and camera.global_position.distance_squared_to(global_position) < 625.0:
		facing_camera.look_at(camera.global_position, Vector3.UP, true)

func add_orbit() -> void:
	var band := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.96
	band.mesh = quad
	band.position.z = -0.028
	band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var finish := ShaderMaterial.new()
	finish.shader = preload("res://assets/pickups/orb_orbit.gdshader")
	finish.set_shader_parameter("tint", tint)
	finish.set_shader_parameter("mark", mark)
	band.material_override = finish
	facing_camera.add_child(band)

func add_text(symbol: String, ink: Color, units_per_pixel: float) -> void:
	var glyph := Label3D.new()
	glyph.font = preload("res://assets/ui/fonts/BarlowCondensed-ExtraBoldItalic.ttf")
	glyph.text = symbol
	glyph.font_size = 104
	glyph.pixel_size = units_per_pixel
	glyph.modulate = ink
	glyph.outline_size = 0 if mark == Mark.XP else 9
	glyph.outline_modulate = tint.darkened(0.78)
	glyph.position.z = RADIUS + 0.005
	facing_camera.add_child(glyph)

func add_lightning() -> void:
	var points := PackedVector2Array([
		Vector2(0.025, 0.156), Vector2(-0.104, -0.015), Vector2(-0.025, -0.015),
		Vector2(-0.051, -0.153), Vector2(0.105, 0.051), Vector2(0.022, 0.051),
		Vector2(0.052, 0.156),
	])
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in Geometry2D.triangulate_polygon(points):
		var point := points[index]
		surface.add_vertex(Vector3(point.x, point.y, 0.0))
	var bolt := MeshInstance3D.new()
	bolt.mesh = surface.commit()
	var ink := StandardMaterial3D.new()
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.cull_mode = BaseMaterial3D.CULL_DISABLED
	ink.albedo_color = Color("effbff")
	bolt.material_override = ink
	bolt.position.z = RADIUS + 0.005
	bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	facing_camera.add_child(bolt)
