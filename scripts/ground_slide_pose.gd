extends SkeletonModifier3D

var mode := ""
var windup_target := 0.0
var windup := 0.0

func _process_modification_with_delta(delta: float) -> void:
	var rig := get_skeleton()
	windup = move_toward(windup, windup_target, delta * 19.0)
	match mode:
		"dash":
			air_dash(rig)
		"wall_slide":
			wall_slide(rig)
		"slide":
			ground_slide(rig)
		_:
			if windup > 0.0:
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
	aim(rig, "Spine", "Spine1", Vector3(-.06, .93, .30))
	aim(rig, "Spine1", "Spine2", Vector3(0, .95, .31))
	aim(rig, "Neck", "Head", Vector3(0, .99, .10))
	aim(rig, "RightArm", "RightForeArm", Vector3(-.55, .53, -.64))
	aim(rig, "RightForeArm", "RightHand", Vector3(-.18, .87, -.47))
	aim(rig, "LeftArm", "LeftForeArm", Vector3(.38, -.57, .73))
	aim(rig, "LeftForeArm", "LeftHand", Vector3(-.10, .57, .81))
	aim(rig, "RightUpLeg", "RightLeg", Vector3(-.22, -.82, -.53))
	aim(rig, "RightLeg", "RightFoot", Vector3(-.04, -.88, .47))
	aim(rig, "RightFoot", "RightToeBase", Vector3(0, -.18, .98))
	aim(rig, "LeftUpLeg", "LeftLeg", Vector3(.22, -.67, .71))
	aim(rig, "LeftLeg", "LeftFoot", Vector3(.15, -.72, -.68))
	aim(rig, "LeftFoot", "LeftToeBase", Vector3(.08, -.39, .91))

func saber_charge(rig: Skeleton3D) -> void:
	# The left hand holds the blade. Leave the run and jump tracks on the legs.
	aim(rig, "Spine1", "Spine2", Vector3(-.14, .98, -.12), windup * .55)
	aim(rig, "LeftArm", "LeftForeArm", Vector3(.60, .46, -.66), windup)
	aim(rig, "LeftForeArm", "LeftHand", Vector3(-.27, .91, .31), windup)
	aim(rig, "RightArm", "RightForeArm", Vector3(-.41, -.68, .61), windup * .75)
	aim(rig, "RightForeArm", "RightHand", Vector3(.24, -.23, .94), windup * .75)
	for digit in ["Index", "Middle", "Ring", "Pinky"]:
		for joint in range(1, 4):
			var bone := rig.find_bone("mixamorig_LeftHand%s%d" % [digit, joint])
			if bone >= 0:
				var curl := Quaternion(Vector3.RIGHT, -windup * (0.82 if joint == 1 else 1.02))
				rig.set_bone_pose_rotation(bone, (rig.get_bone_rest(bone).basis.get_rotation_quaternion() * curl).normalized())

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
