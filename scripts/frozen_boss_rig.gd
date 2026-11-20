extends Node3D
## Rigid mechanical skin and constrained in-place clips. The CharacterBody owns movement.
var animation: AnimationPlayer
var model: Node3D
var cinematic := false
var intent := [-1.0,0.0,""]
var clip := ""
var frost: CPUParticles3D
var skeleton: Skeleton3D
var bone_axes := {}
var rest_rotations := {}
var cannon_offset := Vector3.ZERO
var cannon_bone := -1

func bind_model(mesh: Node3D, height: float, floor_offset: float) -> void:
	model = mesh
	model.rotation.y = -PI*.5
	var bounds := AABB()
	var found := false
	for node in model.find_children("*","MeshInstance3D",true,false):
		var part: AABB = (global_transform.affine_inverse()*node.global_transform)*node.get_aabb()
		bounds = bounds.merge(part) if found else part
		found = true
	var fit := height/maxf(bounds.size.y,.01)
	model.scale *= fit
	model.position = Vector3(-bounds.get_center().x*fit,-floor_offset-bounds.position.y*fit,-bounds.get_center().z*fit)
	skeleton = model.find_children("*","Skeleton3D",true,false).front()
	animation = AnimationPlayer.new()
	add_child(animation)
	var from_model := skeleton.global_basis.inverse().orthonormalized()*global_basis.orthonormalized()
	for bone in skeleton.get_bone_count():
		bone_axes[skeleton.get_bone_name(bone)] = skeleton.get_bone_global_rest(bone).basis.orthonormalized().inverse()*from_model
		rest_rotations[skeleton.get_bone_name(bone)] = skeleton.get_bone_pose_rotation(bone)
	cannon_bone = skeleton.find_bone("RightForearm")
	var tip := Vector3(.08,.397,.495) if floor_offset>0 else Vector3(.03,.375,.495)
	var rest_tip := skeleton.global_transform.affine_inverse()*model.to_global(tip)
	cannon_offset = skeleton.get_bone_global_rest(cannon_bone).affine_inverse()*rest_tip
	var library := AnimationLibrary.new()
	for name in ["idle","walk","shoot","slash"]:
		library.add_animation(name,mechanical_clip(name))
	animation.add_animation_library("",library)
	frost = preload("res://scripts/frost_fx.gd").particles(self,36,Vector3(0,height*.45-floor_offset,0),.95)
	frost.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	frost.emission_sphere_radius = height*.42
	frost.gravity = Vector3.UP*.8
	frost.scale_amount_min = .08
	frost.scale_amount_max = .21
	play("idle")

func mechanical_clip(name: String) -> Animation:
	var motion := Animation.new()
	motion.length = 2.4 if name=="idle" else 1.20 if name=="walk" else .85 if name=="shoot" else 1.15
	if name in ["idle","walk"]:
		motion.loop_mode = Animation.LOOP_LINEAR
	var path := String(get_path_to(skeleton))
	for bone in skeleton.get_bone_count():
		var label := skeleton.get_bone_name(bone)
		var track := motion.add_track(Animation.TYPE_ROTATION_3D)
		motion.track_set_path(track,NodePath(path+":"+label))
		for i in 9:
			var phase := float(i)/8
			var pulse := sin(phase*TAU)
			var step := pulse if name=="walk" else 0.0
			var angles := Vector3.ZERO
			var side := 1.0 if label.begins_with("Left") else -1.0
			if label.ends_with("UpperArm"):
				var guard := .94
				if name=="shoot":
					guard = .60 if side>0 else lerpf(.94,.22,smoothstep(0,.35,phase))
				elif name=="slash":
					guard -= .44*sin(phase*PI)
				angles = Vector3(step*side*.035,0,-side*guard)
			elif label.ends_with("Forearm"):
				angles.y = side*.13*sin(phase*PI) if name in ["shoot","slash"] else 0.0
			elif label.ends_with("Thigh"):
				angles.x = step*side*.22
			elif label.ends_with("Calf"):
				angles.x = maxf(0,-step*side)*.26
			elif label.ends_with("Foot"):
				angles.x = -step*side*.13
			elif label=="Spine":
				angles = Vector3(.008*pulse,.09*sin(phase*PI) if name=="slash" else 0.0,0)
			var axes: Basis = bone_axes[label]
			var turn := Quaternion(axes.x,angles.x)*Quaternion(axes.y,angles.y)*Quaternion(axes.z,angles.z)
			motion.rotation_track_insert_key(track,phase*motion.length,rest_rotations[label]*turn)
	return motion

func play(name: String) -> void:
	if name == clip or not is_instance_valid(animation) or not animation.has_animation(name):
		return
	clip = name
	animation.speed_scale = 1.0
	animation.play(name,.18)

func face_immediately(direction: float) -> void:
	intent[0] = direction
	rotation.y = direction * Combatant.BOSS_SIDE_YAW

func set_combat_pose(facing: float, speed: float, attack: String) -> void:
	intent = [facing,speed,attack]

func _process(delta: float) -> void:
	if cinematic or not is_visible_in_tree() or not animation:
		return
	rotation.y = lerpf(rotation.y,float(intent[0])*Combatant.BOSS_SIDE_YAW,1.0-exp(-delta*12))
	var attack: String = intent[2]
	if not attack.is_empty():
		play("slash" if attack in ["charge","ice_burst","signature"] else "shoot")
	elif float(intent[1]) > .5:
		play("walk")
		animation.speed_scale = clampf(float(intent[1])/3.4,.65,1.6)
	else:
		play("idle")

func cinematic_pose(_delta: float, airborne: float, landing: float, showpiece: float, power: float) -> void:
	cinematic = true
	if not animation:
		return
	play("slash")
	animation.speed_scale = 0.0
	var length := animation.get_animation("slash").length
	animation.seek(length*clampf(.18+showpiece*.25+power*.12-landing*.07-airborne*.04,.05,.72),true)
	frost.emitting = power>.05
	frost.initial_velocity_min = .6+power*.8
	frost.initial_velocity_max = 1.4+power*2

func finish_cinematic() -> void:
	cinematic = false
	frost.emitting = false
	clip = ""
	play("idle")

func snapshot() -> Array:
	return intent

func muzzle_position() -> Vector3:
	var at := skeleton.global_transform*(skeleton.get_bone_global_pose(cannon_bone)*cannon_offset)
	return Vector3(at.x,at.y,0)

func apply_snapshot(data: Array) -> void:
	if data.size() == 3:
		intent = data
