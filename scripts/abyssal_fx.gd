extends Node3D
## Spatial water volumes and branching electrical tubes. No screen/compute dependency.
const WATER := preload("res://assets/campaign/abyssal_plant/kit/water.gdshader")
const ARC := preload("res://assets/campaign/abyssal_plant/kit/discharge.gdshader")
enum Kind { CURRENT, LEAK, DISCHARGE, POOL }
var kind := Kind.CURRENT
var dimensions := Vector3(3,8,3)
var direction := Vector3.UP
var active := true
var warning := false
var material: ShaderMaterial
var volume: MeshInstance3D
var bubbles: CPUParticles3D
var arc_mesh: MeshInstance3D
var age := 0.0
var next_arc := 0.0

func _ready() -> void:
	material = ShaderMaterial.new()
	material.shader = ARC if kind == Kind.DISCHARGE else WATER
	if kind == Kind.DISCHARGE:
		arc_mesh = MeshInstance3D.new()
		arc_mesh.material_override = material
		add_child(arc_mesh)
		redraw_arc()
	else:
		volume = MeshInstance3D.new()
		if kind == Kind.POOL:
			var water := PlaneMesh.new()
			water.size = Vector2(dimensions.x,dimensions.z)
			water.subdivide_width = 16
			water.subdivide_depth = 8
			volume.mesh = water
		else:
			var jet := CylinderMesh.new()
			jet.top_radius = dimensions.x*.41
			jet.bottom_radius = dimensions.x*.28
			jet.height = dimensions.y
			jet.radial_segments = 24
			jet.rings = 8
			volume.mesh = jet
			volume.quaternion = Quaternion(Vector3.UP,direction.normalized())
		volume.material_override = material
		add_child(volume)
		bubbles = CPUParticles3D.new()
		bubbles.amount = 56 if kind == Kind.CURRENT else 24
		bubbles.lifetime = 1.4
		bubbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		bubbles.emission_box_extents = Vector3(dimensions.x*.32,dimensions.y*.4,dimensions.z*.22)
		bubbles.direction = direction
		bubbles.spread = 12
		bubbles.gravity = Vector3(0,.5,0)
		bubbles.initial_velocity_min = 2
		bubbles.initial_velocity_max = 4
		bubbles.scale_amount_min = .025
		bubbles.scale_amount_max = .065
		var bubble := SphereMesh.new()
		bubble.radial_segments = 8
		bubble.rings = 4
		var finish := StandardMaterial3D.new()
		finish.albedo_color = Color("8bd5df")
		finish.metallic = .5
		finish.roughness = .18
		bubble.material = finish
		bubbles.mesh = bubble
		add_child(bubbles)
	for child in get_children():
		if child is GeometryInstance3D:
			child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			child.visibility_range_end = 42
			child.visibility_range_end_margin = 6

func _process(delta: float) -> void:
	age += delta
	var camera := get_viewport().get_camera_3d()
	var nearby := camera == null or camera.global_position.distance_squared_to(global_position)<1900
	visible = nearby
	if kind == Kind.DISCHARGE:
		material.set_shader_parameter("intensity",1.0 if active else (.12 if warning else 0.0))
		material.set_shader_parameter("tint",Color("65cfff") if active else Color("ffac42"))
		if nearby and (active or warning) and age>=next_arc:
			next_arc=age+.085
			redraw_arc()
	else:
		bubbles.emitting = active and nearby
		bubbles.direction=direction
		if kind!=Kind.POOL: volume.quaternion=Quaternion(Vector3.UP,direction.normalized())
		volume.visible = active

func redraw_arc() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for branch in 3:
		var previous := Vector3(-dimensions.x*.5,0,(branch-1)*.13)
		for segment in range(1,17):
			var ratio := segment/16.0
			var point := Vector3(lerpf(-dimensions.x*.5,dimensions.x*.5,ratio),sin(segment*4.17+age*37+branch)*.24,(branch-1)*.13+sin(segment*2.31+age*29)*.13)
			if segment==16: point=Vector3(dimensions.x*.5,0,0)
			tube(surface,previous,point,.027 if branch==0 else .013)
			if segment in [4,9,12]:
				tube(surface,point,point+Vector3(.25,(-1 if segment%2==0 else 1)*.62,.10),.009)
			previous=point
	surface.generate_normals()
	arc_mesh.mesh = surface.commit()

static func tube(surface: SurfaceTool, a: Vector3,b: Vector3,radius: float) -> void:
	var axis := (b-a).normalized()
	var right := axis.cross(Vector3.FORWARD).normalized()*radius
	var up := axis.cross(right).normalized()*radius
	for i in 6:
		var p := right*cos(i*TAU/6)+up*sin(i*TAU/6)
		var q := right*cos((i+1)*TAU/6)+up*sin((i+1)*TAU/6)
		for vertex in [a+p,b+p,b+q,a+p,b+q,a+q]:
			surface.set_uv(Vector2(vertex.x,vertex.y))
			surface.add_vertex(vertex)
