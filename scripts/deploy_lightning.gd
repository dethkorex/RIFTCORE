extends Node3D

const CYAN := Color("42dfff")
const WHITE := Color("d8faff")

func strike() -> void:
	var source := Vector3(-0.5, 7.0, 0.08)
	var points: Array[Vector3] = [source]
	for i in range(1, 9):
		points.append(Vector3(sin(i * 2.7) * (0.64 - i * 0.04), 7.0 - i * 0.82, 0.09))
	points.append(Vector3(0, 0.02, 0.12))
	var core := bolt(points, WHITE, 0.048)
	var bloom := bolt(points, CYAN, 0.16)
	var arc: Array[Vector3] = [points[2], Vector3(-0.88, 4.0, 0.08), Vector3(-0.66, 2.98, 0.08), Vector3(-1.0, 2.16, 0.08)]
	var branch := bolt(arc, CYAN, 0.039)
	var flare := RiftProjectile.add_glow(self, CYAN, 3.7)
	flare.position = Vector3(0, 0.57, 0.37)
	var light := OmniLight3D.new()
	light.light_color = CYAN
	light.light_energy = 4.2
	light.omni_range = 6.7
	light.position = Vector3(0, 0.95, 0.1)
	add_child(light)
	var ring := RiftProjectile.part(self, RiftProjectile.cached_mesh("Ring"), RiftProjectile.light_paint(CYAN, 2.4), Vector3(0, 0.11, 0), Vector3.ONE * 0.32)
	var effect := create_tween().set_parallel()
	effect.tween_property(light, "light_energy", 0.0, 0.32)
	effect.tween_property(flare, "scale", Vector3.ONE * 0.03, 0.29)
	effect.tween_property(ring, "scale", Vector3(4.5, 0.03, 4.5), 0.32)
	effect.tween_callback(core.hide).set_delay(0.145)
	effect.tween_callback(bloom.hide).set_delay(0.195)
	effect.tween_callback(branch.hide).set_delay(0.21)
	effect.tween_callback(ring.hide).set_delay(0.25)
	effect.chain().tween_callback(queue_free)

func bolt(points: Array[Vector3], tint: Color, width: float) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	var geometry := ImmediateMesh.new()
	var material := RiftProjectile.light_paint(tint, 2.8)
	var ribbon := material.duplicate() as StandardMaterial3D
	ribbon.cull_mode = BaseMaterial3D.CULL_DISABLED
	geometry.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, ribbon)
	for i in range(points.size()):
		var taper := 1.0 - i / float(points.size()) * 0.46
		geometry.surface_add_vertex(points[i] + Vector3.RIGHT * width * taper)
		geometry.surface_add_vertex(points[i] - Vector3.RIGHT * width * taper)
	geometry.surface_end()
	piece.mesh = geometry
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(piece)
	return piece

