extends "res://scripts/climb_pose.gd"
## Use a fixed stance on the grip pads and absorb motion through the knees.

var actor: Node3D
var crouch_weight := 0.0

func _process(delta: float) -> void:
	var riding: bool = is_instance_valid(actor) and actor.health > 0.0 and is_instance_valid(actor.rocket_course)
	influence = 1.0 if riding else 0.0
	if riding:
		var ducking: bool = actor.low_profile or actor.current_animation == "crouch"
		crouch_weight = move_toward(crouch_weight,1.0 if ducking else 0.0,delta*12.0)
	else:
		crouch_weight = 0.0

func _process_modification_with_delta(_delta: float) -> void:
	if influence <= 0.0:
		return
	var rig := get_skeleton()
	var hips := rig.find_bone("mixamorig_Hips")
	var rest := rig.get_bone_rest(hips)
	var torso_drop := lerpf(.08,.25,crouch_weight)
	rig.set_bone_pose_position(hips,rest.origin+Vector3(.018,-torso_drop,-.022))
	rig.set_bone_pose_rotation(hips,rest.basis.get_rotation_quaternion())
	aim(rig,"Spine","Spine1",Vector3(.08,1.0,lerpf(.21,.55,crouch_weight)))
	aim(rig,"Spine1","Spine2",Vector3(.08,1.0,lerpf(.19,.65,crouch_weight)))
	aim(rig,"Neck","Head",Vector3(.04,1.0,.04))
	var head := rig.find_bone("mixamorig_Head")
	var head_rotation := rig.get_bone_rest(head).basis.get_rotation_quaternion()
	rig.set_bone_pose_rotation(head,(Quaternion(Vector3.UP,.9)*head_rotation).normalized())
	for side in [1.0,-1.0]:
		var limb := "Left" if side > 0.0 else "Right"
		plant_boot(rig,limb,side)
		aim(rig,limb+"Arm",limb+"ForeArm",Vector3(side*.69,-.56,.18*side))
		aim(rig,limb+"ForeArm",limb+"Hand",Vector3(side*.58,lerpf(-.24,.22,crouch_weight),.40))

func plant_boot(rig: Skeleton3D, limb: String, side: float) -> void:
	var thigh := rig.find_bone("mixamorig_"+limb+"UpLeg")
	var shin := rig.find_bone("mixamorig_"+limb+"Leg")
	var boot := rig.find_bone("mixamorig_"+limb+"Foot")
	var thigh_length := rig.get_bone_rest(shin).origin.length()
	var shin_length := rig.get_bone_rest(boot).origin.length()
	var hip := rig.get_bone_global_pose(thigh).origin
	var rest_boot := rig.get_bone_global_rest(boot)
	var target := Vector3(side*.213,rest_boot.origin.y,-.055)
	var leg_axis := (target-hip).normalized()
	var reach := minf(hip.distance_to(target),thigh_length+shin_length-.001)
	# Project a forward and outward knee bend onto the plane of the leg.
	var knee_bend := Vector3(side*.55,0,1.0).slide(leg_axis).normalized()
	var along := (thigh_length*thigh_length-shin_length*shin_length+reach*reach)/(2.0*reach)
	var knee := hip+leg_axis*along+knee_bend*sqrt(maxf(0.0,thigh_length*thigh_length-along*along))
	aim(rig,limb+"UpLeg",limb+"Leg",knee-hip)
	aim(rig,limb+"Leg",limb+"Foot",target-knee)
	var shin_basis := rig.get_bone_global_pose(shin).basis.orthonormalized()
	var boot_basis := Basis(Vector3.UP,side*.14)*rest_boot.basis.orthonormalized()
	rig.set_bone_pose_rotation(boot,(shin_basis.inverse()*boot_basis).get_rotation_quaternion())
	var toe := rig.find_bone("mixamorig_"+limb+"ToeBase")
	rig.set_bone_pose_rotation(toe,rig.get_bone_rest(toe).basis.get_rotation_quaternion())
