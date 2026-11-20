extends Area3D

const FIELD_SHADER := preload("res://assets/enemies/guard_field.gdshader")
const CHAMFER := preload("res://scripts/factory_chamfer.gd")
const HIT_SECONDS := 0.25
const SPAN := Vector2(1.53, 1.69)
static var field_mesh: ArrayMesh
static var field_hull: ConvexPolygonShape3D
static var metal: StandardMaterial3D
static var contact_pin: StandardMaterial3D
var field: ShaderMaterial
var side := 0.0
var reach := 0.92
var hit_remaining := 0.0

func install(hull: BoxShape3D) -> void:
	name = "FrontGuard"
	add_to_group(&"enemy_guard_field")
	collision_layer = 16
	collision_mask = 0
	monitoring = false
	reach = hull.size.x * 0.5 + 0.17
	scale = Vector3(hull.size.z / 1.18, hull.size.y / 1.36, 1.0)
	if field_mesh == null:
		field_mesh = make_field()
		var vertices := PackedVector3Array()
		for point in field_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			vertices.append(point + Vector3.BACK * 0.035)
			vertices.append(point + Vector3.FORWARD * 0.035)
		field_hull = ConvexPolygonShape3D.new()
		field_hull.points = vertices
		metal = RiftProjectile.light_paint(Color("343047"), 0.03)
		contact_pin = RiftProjectile.light_paint(Color("b883fa"), 1.25)

	var collider := CollisionShape3D.new()
	collider.shape = field_hull
	add_child(collider)
	field = ShaderMaterial.new()
	field.shader = FIELD_SHADER
	var mesh := MeshInstance3D.new()
	mesh.mesh = field_mesh
	mesh.material_override = field
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)
	for y in [-0.69, 0.69]:
		piece(Vector3(0,y,-0.145), Vector3(.45,.15,.13), metal)
		piece(Vector3(0,y,-0.074), Vector3(.25,.043,.034), contact_pin)
	update_pose(1.0, false)
	set_process(false)

func update_pose(facing: float, guarding: bool) -> void:
	var facing_side := -1.0 if facing < 0.0 else 1.0
	if side != facing_side:
		side = facing_side
		position = Vector3(side * reach, 0.02, 0.08)
		rotation.y = side * 1.04
	if visible != guarding:
		visible = guarding
		set_deferred("monitorable", guarding)

func flash_at(at: Vector3) -> void:
	var local := to_local(at)
	var uv := Vector2(clampf(0.5 + local.x / SPAN.x, 0.13, 0.87), clampf(0.5 + local.y / SPAN.y, 0.11, 0.89))
	field.set_shader_parameter("hit_origin", uv)
	field.set_shader_parameter("hit_strength", 1.0)
	hit_remaining = HIT_SECONDS
	set_process(true)

func _process(delta: float) -> void:
	hit_remaining = maxf(0.0, hit_remaining - delta)
	field.set_shader_parameter("hit_strength", hit_remaining / HIT_SECONDS)
	if is_zero_approx(hit_remaining):
		set_process(false)

func piece(at: Vector3, dimensions: Vector3, material: Material) -> void:
	var model := MeshInstance3D.new()
	var block := BoxMesh.new()
	block.size = dimensions
	model.mesh = CHAMFER.from_box(block, 0.025)
	model.material_override = material
	model.position = at
	model.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(model)

static func make_field() -> ArrayMesh:
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for column in 14:
		var u := float(column) / 14.0
		var end := float(column + 1) / 14.0
		for uv in [Vector2(u,0),Vector2(u,1),Vector2(end,0),Vector2(end,0),Vector2(u,1),Vector2(end,1)]:
			var bend: float = absf(float(uv.x) * 2.0 - 1.0)
			builder.set_uv(uv)
			builder.set_normal(Vector3(0,0,1))
			builder.add_vertex(Vector3((uv.x-.5)*SPAN.x,(uv.y-.5)*SPAN.y,.10 - .32 * bend * bend))
	return builder.commit()
