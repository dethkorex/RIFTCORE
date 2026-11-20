@tool
extends Node3D

## Cross-sections are authored in metres. The front stays open to the side camera.
@export var ceiling := PackedVector2Array()
@export var lower_edge := -8.0
@export var rock: Texture2D
@export var stone_tint := Color(.60, .63, .68)

func _ready() -> void:
	if ceiling.size() < 2:
		return
	var finish := StandardMaterial3D.new()
	finish.albedo_texture = rock
	finish.albedo_color = stone_tint
	finish.roughness = .85
	finish.cull_mode = BaseMaterial3D.CULL_DISABLED
	finish.uv1_triplanar = true
	finish.uv1_world_triplanar = true
	finish.uv1_scale = Vector3(.19, .19, .19)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var roof := StaticBody3D.new()
	roof.name = "Vault"
	roof.add_to_group(&"no_wall_kick")
	add_child(roof)
	for i in range(1, ceiling.size()):
		var a := ceiling[i - 1]
		var b := ceiling[i]
		var width := b.x - a.x
		if width <= 0.0:
			continue
		var front_a := Vector3(a.x, a.y, 1.78)
		var front_b := Vector3(b.x, b.y, 1.78)
		var rear_a := Vector3(a.x, a.y, -4.05)
		var rear_b := Vector3(b.x, b.y, -4.05)
		quad(surface, rear_a, rear_b, front_b, front_a)
		quad(surface, front_a, front_b, front_b + Vector3(0, .37, .26), front_a + Vector3(0, .37, .26))
		quad(surface, front_a + Vector3(0, .37, .26), front_b + Vector3(0, .37, .26), front_b + Vector3(0, 3.4, .06), front_a + Vector3(0, 3.4, .06))
		for band in 6:
			var ra := wall_sample(a, i - 1, band)
			var rb := wall_sample(b, i, band)
			quad(surface, ra, rb, wall_sample(b, i, band + 1), wall_sample(a, i - 1, band + 1))
		var volume := ConvexPolygonShape3D.new()
		volume.points = PackedVector3Array([front_a, front_b, rear_a, rear_b, front_a + Vector3.UP * 3.4, front_b + Vector3.UP * 3.4, rear_a + Vector3.UP * 3.4, rear_b + Vector3.UP * 3.4])
		var collision := CollisionShape3D.new()
		collision.shape = volume
		roof.add_child(collision)
	surface.generate_normals()
	surface.set_material(finish)
	var wall := MeshInstance3D.new()
	wall.mesh = surface.commit()
	add_child(wall)

func wall_sample(section: Vector2, column: int, band: int) -> Vector3:
	var seam := sin(column * 1.7 + band * 2.14)
	var t := band / 6.0
	return Vector3(section.x, lerpf(lower_edge, section.y, t) + seam * sin(t * PI) * .57, -4.05 - sin(t * PI) * (.48 + .42 * seam))

func quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for v in [a, d, c, a, c, b]:
		surface.add_vertex(v)
