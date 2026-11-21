extends SkeletonModifier3D

var mode := ""
var windup_target := 0.0
var windup := 0.0

# The attack clip supplies the torso and sword arm. Sample only the locomotion
# tracks below the waist during a moving cut so the feet keep their cadence.
var actor
var leg_clips := {}
var leg_tracks := {}
var stride_phase := 0.0
var leg_weight := 0.0

func configure_stride(operator: CharacterBody3D, player: AnimationPlayer) -> void:
	actor = operator
	if not player:
		return
	var rig := get_skeleton()
	for key: StringName in [&"walk", &"run", &"jump", &"fall"]:
		if not player.has_animation(key):
			continue
		var clip := player.get_animation(key)
		leg_clips[key] = clip
		var tracks := {}
		for track in clip.get_track_count():
			if clip.track_get_type(track) != Animation.TYPE_ROTATION_3D:
				continue
			var path := clip.track_get_path(track)
			if path.get_subname_count() != 1:
				continue
			var bone := String(path.get_subname(0))
			if not (bone.ends_with("Leg") or bone.ends_with("Foot") or bone.ends_with("ToeBase") or bone.ends_with("_Hips")):
				continue
			var index := rig.find_bone(bone)
			if index >= 0:
				tracks[index] = track
		leg_tracks[key] = tracks

func moving_swing(rig: Skeleton3D, delta: float) -> void:
	if not actor:
		return
	var speed := absf(actor.velocity.x)
	var air: bool = not actor.grounded() if actor.is_physics_processing() else absf(actor.velocity.y) > 0.35
	var key := &"run" if speed >= 4.5 else &"walk"
	if air:
		key = &"jump" if actor.velocity.y >= 0.0 else &"fall"
	if not leg_clips.has(key):
		return
	leg_weight = move_toward(leg_weight, 1.0 if air or speed > 0.35 else 0.0, delta * 18.0)
	var clip: Animation = leg_clips[key]
	var phase := stride_phase
	if air:
		phase = clampf(1.0 - actor.velocity.y / actor.jump_velocity, 0.05, 0.95) if key == &"jump" else 0.45
	for index: int in leg_tracks[key]:
		var rot := clip.rotation_track_interpolate(leg_tracks[key][index], clip.length * phase)
		rig.set_bone_pose_rotation(index, rig.get_bone_pose_rotation(index).slerp(rot, leg_weight))

func _process_modification_with_delta(delta: float) -> void:
	var rig := get_skeleton()
	if actor:
		if mode in ["walk", "run"] and leg_clips.has(StringName(mode)):
			stride_phase = fposmod(actor.animation_player.current_animation_position / leg_clips[StringName(mode)].length, 1.0)
		else:
			stride_phase = fposmod(stride_phase + absf(actor.velocity.x) * delta / 4.0, 1.0)
	if mode not in ["saber_cut", "saber_return", "slash_finisher"]:
		leg_weight = 0.0
	windup = move_toward(windup, windup_target, delta * 19.0)
	match mode:
		"dash":
			air_dash(rig)
		"wall_slide":
			wall_slide(rig)
		"slide":
			ground_slide(rig)
			if actor and actor.saber_equipped:
				orient_saber(rig, Vector3(.12, .19, -.97), 1.0)
				grip_saber(rig, 1.0)
		"saber_cut", "saber_return", "slash_finisher":
			moving_swing(rig, delta)
			grip_saber(rig, 1.0)
		_:
			if actor and (actor.saber_equipped or windup > 0.0):
				saber_charge(rig)

func ground_slide(rig: Skeleton3D) -> void:
	aim(rig, "Spine", "Spine1", Vector3(0, .76, -.65))
	aim(rig, "Spine1", "Spine2", Vector3(0, .73, -.68))
	aim(rig, "Neck", "Head", Vector3(0, .97, .24))
	aim(rig, "LeftUpLeg", "LeftLeg", Vector3(.11, -.20, .97))
	aim(rig, "LeftLeg", "LeftFoot", Vector3(.03, -.09, 1.0))
	aim(rig, "LeftFoot", "LeftToeBase", Vector3(.03, .06, 1.0))
	aim(rig, "RightUpLeg", "RightLeg", Vector3(-.10, .49, .85))
	aim(rig, "RightLeg", "RightFoot", Vector3(-.16, -.71, .64))
	aim(rig, "RightFoot", "RightToeBase", Vector3(-.03, .03, 1.0))
	aim(rig, "LeftArm", "LeftForeArm", Vector3(.55, -.38, -.66))
	aim(rig, "LeftForeArm", "LeftHand", Vector3(.28, -.77, -.56))
	aim(rig, "RightArm", "RightForeArm", Vector3(-.58, .32, .71))
	aim(rig, "RightForeArm", "RightHand", Vector3(-.22, .66, .72))

	# Seat the boots on the sliding contact plane; the crouch clip's root was
	# authored for bent legs and otherwise leaves a gap under the extended heel.
	var hips := rig.find_bone("mixamorig_Hips")
	var heel := rig.find_bone("mixamorig_LeftFoot")
	var back_heel := rig.find_bone("mixamorig_RightFoot")
	if hips >= 0 and heel >= 0 and back_heel >= 0 and actor:
		var lowest := minf(rig.to_global(rig.get_bone_global_pose(heel).origin).y, rig.to_global(rig.get_bone_global_pose(back_heel).origin).y)
		var floor_y: float = actor.global_position.y - actor.standing_capsule.height * .5
		var correction := Vector3.UP * clampf(floor_y + .12 - lowest, -.28, 0.0)
		var local_shift := rig.global_basis.inverse() * correction
		var parent := rig.get_bone_parent(hips)
		if parent >= 0:
			local_shift = rig.get_bone_global_pose(parent).basis.inverse() * local_shift
		rig.set_bone_pose_position(hips, rig.get_bone_pose_position(hips) + local_shift)

func air_dash(rig: Skeleton3D) -> void:
	aim(rig, "Spine", "Spine1", Vector3(0, .49, .87))
	aim(rig, "Spine1", "Spine2", Vector3(0, .44, .90))
	aim(rig, "Neck", "Head", Vector3(0, .86, .50))
	aim(rig, "LeftArm", "LeftForeArm", Vector3(.42, -.57, .70))
	aim(rig, "LeftForeArm", "LeftHand", Vector3(-.13, .63, .76))
	aim(rig, "RightArm", "RightForeArm", Vector3(-.64, .34, -.68))
	aim(rig, "RightForeArm", "RightHand", Vector3(.16, -.59, -.79))
	aim(rig, "LeftUpLeg", "LeftLeg", Vector3(.14, -.83, -.54))
	aim(rig, "LeftLeg", "LeftFoot", Vector3(.05, -.08, -1))
	aim(rig, "LeftFoot", "LeftToeBase", Vector3(.09, -.15, -.98))
	aim(rig, "RightUpLeg", "RightLeg", Vector3(-.17, -.26, -.95))
	aim(rig, "RightLeg", "RightFoot", Vector3(-.07, -.40, -.91))
	aim(rig, "RightFoot", "RightToeBase", Vector3(-.09, -.18, -.98))

func wall_slide(rig: Skeleton3D) -> void:
	# Local -Z stays against the wall on either travel direction.
	# RX-07's right arm is the cannon; its barrel traces up the wall.
	aim(rig, "Spine", "Spine1", Vector3(0, .99, .13))
	aim(rig, "Spine1", "Spine2", Vector3(0, .98, .18))
	aim(rig, "Neck", "Head", Vector3(0, .98, .16))
	aim(rig, "RightArm", "RightForeArm", Vector3(-.19, .58, -.79))
	aim(rig, "RightForeArm", "RightHand", Vector3(.04, .94, -.33))
	aim(rig, "LeftArm", "LeftForeArm", Vector3(.25, -.82, .52))
	aim(rig, "LeftForeArm", "LeftHand", Vector3(-.05, .55, .84))
	aim(rig, "LeftUpLeg", "LeftLeg", Vector3(.13, -.89, .45))
	aim(rig, "LeftLeg", "LeftFoot", Vector3(.01, -.90, -.45))
	aim(rig, "LeftFoot", "LeftToeBase", Vector3(.02, -.63, .77))
	aim(rig, "RightUpLeg", "RightLeg", Vector3(-.16, -.88, -.44))
	aim(rig, "RightLeg", "RightFoot", Vector3(-.02, -.97, -.24))
	aim(rig, "RightFoot", "RightToeBase", Vector3(0, -.78, .63))

func saber_charge(rig: Skeleton3D) -> void:
	# Keep the hilt ahead of the belt and the elbow below the shoulder.
	# Positive Z is forward in the rig on both world-facing directions.
	var grip := 1.0 if actor.saber_equipped else windup
	var blocking := bool(actor.guarding)
	aim(rig, "Spine", "Spine1", Vector3(-.05, .98, .18), windup * .48)
	aim(rig, "LeftArm", "LeftForeArm", Vector3(.30, -.82, .42) if blocking else Vector3(.30, -.93, -.17), grip)
	aim(rig, "LeftForeArm", "LeftHand", Vector3(-.30, .65, .69) if blocking else Vector3(-.22, .06, .974), grip)
	aim(rig, "RightArm", "RightForeArm", Vector3(-.35, -.90, -.24), windup * .82)
	aim(rig, "RightForeArm", "RightHand", Vector3(-.10, -.35, .93), windup * .82)
	var direction := Vector3(-.23, .94, .26) if blocking else Vector3(.09, lerpf(.22, .51, windup), lerpf(.97, .855, windup))
	orient_saber(rig, direction, grip)
	grip_saber(rig, grip)

func orient_saber(rig: Skeleton3D, direction: Vector3, amount: float) -> void:
	var hand := rig.find_bone("mixamorig_LeftHand")
	if hand < 0 or not is_instance_valid(actor.sword_pivot):
		return
	var palm := rig.get_bone_global_pose(hand).basis.orthonormalized()
	var blade: Vector3 = (palm * actor.sword_pivot.basis.x).normalized()
	var wrist_parent := rig.get_bone_global_pose(rig.get_bone_parent(hand)).basis.orthonormalized().get_rotation_quaternion()
	var turn := Quaternion.IDENTITY.slerp(Quaternion(blade, direction.normalized()), amount)
	rig.set_bone_pose_rotation(hand, (wrist_parent.inverse() * turn * wrist_parent * rig.get_bone_pose_rotation(hand)).normalized())

func grip_saber(rig: Skeleton3D, amount: float) -> void:
	if amount <= 0.0:
		return
	var hand := rig.find_bone("mixamorig_LeftHand")
	if hand < 0:
		return
	var palm := rig.get_bone_global_pose(hand).basis.orthonormalized()
	# Pose each phalanx in palm space: over the barrel, around its side,
	# then back toward the palm. The thumb closes across the index finger.
	var curve := [Vector3(0, .93, -.36), Vector3(0, .12, -.99), Vector3(0, -.88, -.48)]
	for digit in ["Index", "Middle", "Ring", "Pinky"]:
		var splay := -.07 if digit == "Pinky" else (.03 if digit == "Index" else 0.0)
		for joint in range(1, 4):
			var arc: Vector3 = curve[joint - 1]
			arc.x = splay
			aim(rig, "LeftHand%s%d" % [digit, joint], "LeftHand%s%d" % [digit, joint + 1], palm * arc, amount)
	var thumb := [Vector3(.66, .65, -.37), Vector3(-.20, .88, -.43), Vector3(-.84, .26, -.48)]
	for joint in range(1, 4):
		aim(rig, "LeftHandThumb%d" % joint, "LeftHandThumb%d" % (joint + 1), palm * thumb[joint - 1], amount)

func aim(rig: Skeleton3D, joint: String, tip: String, toward: Vector3, weight := 1.0) -> void:
	var bone := rig.find_bone("mixamorig_" + joint)
	var child := rig.find_bone("mixamorig_" + tip)
	if bone < 0 or child < 0:
		return
	var reach := rig.get_bone_global_pose(child).origin - rig.get_bone_global_pose(bone).origin
	if reach.length_squared() < .000001:
		return
	var pivot := rig.get_bone_global_pose(rig.get_bone_parent(bone)).basis.orthonormalized().get_rotation_quaternion()
	var turn := Quaternion.IDENTITY.slerp(Quaternion(reach.normalized(), toward.normalized()), weight)
	rig.set_bone_pose_rotation(bone, (pivot.inverse() * turn * pivot * rig.get_bone_pose_rotation(bone)).normalized())
