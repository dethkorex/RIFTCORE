extends RefCounted

const ICE := preload("res://assets/campaign/frozen_reactor/kit/ice.tres")
static var shard_mesh: ArrayMesh

static func crystal_mesh() -> ArrayMesh:
	if shard_mesh:
		return shard_mesh
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in 6:
		var a := Vector3(cos(side * TAU/6),0,sin(side * TAU/6))*.18
		var b := Vector3(cos((side+1)*TAU/6),0,sin((side+1)*TAU/6))*.18
		for point in [a,b,Vector3(.035,1.0,.025),b,a,Vector3(0,-.24,0)]:
			surface.add_vertex(point)
	surface.generate_normals()
	shard_mesh = surface.commit()
	return shard_mesh

static func projectile(parent: Node3D, heavy: bool) -> void:
	var scale := 1.7 if heavy else 1.0
	var geometry := RiftProjectile.part(parent,crystal_mesh(),ICE,Vector3.ZERO,Vector3.ONE * scale)
	geometry.rotation.x = PI*.5
	geometry.rotation.z = .19
	var trail := particles(parent,14 if heavy else 8,Vector3(0,0,-.34),.5)
	trail.direction = Vector3(0,0,-1)
	trail.gravity = Vector3.ZERO
	trail.initial_velocity_min = 1.0
	trail.initial_velocity_max = 2.8
	trail.local_coords = false
	trail.set_deferred("emitting",true)

static func particles(parent: Node3D, count: int, at: Vector3, lifetime: float) -> CPUParticles3D:
	var flakes := CPUParticles3D.new()
	flakes.emitting = false
	flakes.amount = count
	flakes.position = at
	flakes.lifetime = lifetime
	flakes.mesh = crystal_mesh()
	flakes.material_override = ICE
	flakes.scale_amount_min = .055
	flakes.scale_amount_max = .14
	flakes.initial_velocity_min = 1.0
	flakes.initial_velocity_max = 2.6
	flakes.direction = Vector3.UP
	flakes.spread = 72
	flakes.gravity = Vector3.DOWN * 3.0
	flakes.visibility_range_end = 42
	flakes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var size := Curve.new()
	size.add_point(Vector2(0,1))
	size.add_point(Vector2(.60,.7))
	size.add_point(Vector2(1,0))
	flakes.scale_amount_curve = size
	parent.add_child(flakes)
	return flakes

static func shatter(parent: Node3D, at: Vector3, heavy := false) -> void:
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var burst := Node3D.new()
	parent.add_child(burst)
	burst.global_position = at
	var shards := particles(burst,24 if heavy else 12,Vector3.ZERO,.46)
	shards.one_shot = true
	shards.explosiveness = 1.0
	shards.initial_velocity_max = 5.5 if heavy else 3.2
	shards.emitting = true
	burst.create_tween().tween_callback(burst.queue_free).set_delay(.72)

static func vent(parent: Node3D, at: Vector3, size := 1.0) -> CPUParticles3D:
	var plume := particles(parent,20,at,.85)
	plume.scale_amount_min = .06*size
	plume.scale_amount_max = .17*size
	plume.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	plume.emission_box_extents = Vector3(size*.35,.04,.35)
	plume.spread = 19
	plume.initial_velocity_min = 2.0*size
	plume.initial_velocity_max = 3.2*size
	return plume

static func telegraph(parent: Node3D, width: float, duration: float) -> void:
	var strip := PlaneMesh.new()
	strip.size = Vector2(width,1.35)
	var ice := MeshInstance3D.new()
	ice.mesh = strip
	ice.material_override = ICE
	ice.position.y = .035
	parent.add_child(ice)
	var count := clampi(ceili(width/.65),2,20)
	for i in count:
		var seed := MeshInstance3D.new()
		seed.mesh = crystal_mesh()
		seed.material_override = ICE
		seed.position = Vector3((i+.5)*width/count-width*.5,.04,.53 if i%2 else -.53)
		seed.scale = Vector3(.45,.08,.45)
		parent.add_child(seed)
		parent.create_tween().tween_property(seed,"scale:y",.42,maxf(duration,.1))
	var chill := vent(parent,Vector3.ZERO,minf(width*.45,2.0))
	chill.initial_velocity_max = .9
	chill.emitting = true

static func field(parent: Node3D, radius: float, height: float, duration: float) -> void:
	var count := clampi(ceili(radius*3.0),4,22)
	for i in count:
		var shard := MeshInstance3D.new()
		shard.mesh = crystal_mesh()
		shard.material_override = ICE
		shard.position = Vector3((i+.5)*radius*2/count-radius,-height*.5,.25*sin(i*2.1))
		shard.rotation.z = .22*sin(i*1.8)
		var size := Vector3(1.4,height*(.7+.1*(i%4)),1.6)
		shard.scale = Vector3(size.x,.01,size.z)
		parent.add_child(shard)
		var rise := parent.create_tween()
		rise.tween_property(shard,"scale",size,minf(.19,duration*.32)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		rise.tween_interval(maxf(.0,duration-.38))
		rise.tween_property(shard,"scale:y",.01,.19)
	var fog := vent(parent,Vector3(0,-height*.4,0),minf(radius,2.0))
	fog.emitting = true
