extends SkeletonModifier3D

func _process_modification_with_delta(_delta: float) -> void:
	var rig := get_skeleton()
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

func aim(rig: Skeleton3D, joint: String, tip: String, toward: Vector3) -> void:
	var bone := rig.find_bone("mixamorig_" + joint)
	var child := rig.find_bone("mixamorig_" + tip)
	if bone < 0 or child < 0:
		return
	var reach := rig.get_bone_global_pose(child).origin - rig.get_bone_global_pose(bone).origin
	if reach.length_squared() < .000001:
		return
	var pivot := rig.get_bone_global_pose(rig.get_bone_parent(bone)).basis.orthonormalized().get_rotation_quaternion()
	var turn := Quaternion(reach.normalized(), toward.normalized())
	rig.set_bone_pose_rotation(bone, (pivot.inverse() * turn * pivot * rig.get_bone_pose_rotation(bone)).normalized())
