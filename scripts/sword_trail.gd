extends MeshInstance3D

var blade: Node3D
var age := 0.0
var swing_time := 0.18
var intensity := 1.0
var samples: Array[PackedVector3Array] = []
var ribbon := ImmediateMesh.new()
var tint := StandardMaterial3D.new()

func _ready() -> void:
	mesh = ribbon
	tint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tint.cull_mode = BaseMaterial3D.CULL_DISABLED
	tint.vertex_color_use_as_albedo = true

func _process(delta: float) -> void:
	age += delta
	if not is_instance_valid(blade) or age >= swing_time + 0.10:
		queue_free()
		return
	if age <= swing_time and blade.visible:
		samples.append(PackedVector3Array([
			to_local(blade.to_global(Vector3(0.08, 0, 0))),
			to_local(blade.to_global(Vector3(1.62, 0, 0)))
		]))
		if samples.size() > 10:
			samples.pop_front()
	if samples.size() < 2:
		return
	ribbon.clear_surfaces()
	ribbon.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, tint)
	var fade := clampf((swing_time + 0.10 - age) / 0.10, 0.0, 1.0)
	for index in range(samples.size()):
		var alpha := fade * float(index) / float(samples.size() - 1)
		ribbon.surface_set_color(Color(0.03, 0.48, 1.0, alpha * 0.31 * intensity))
		ribbon.surface_add_vertex(samples[index][0])
		ribbon.surface_set_color(Color(0.48, 0.96, 1.0, minf(1.0, alpha * 0.95 * intensity)))
		ribbon.surface_add_vertex(samples[index][1])
	ribbon.surface_end()
