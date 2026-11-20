extends "res://scripts/climb_pose.gd"
## Alternating front crawl and flutter kick (+Y is toward the head).
## Every suit uses the same skeleton; replicas derive the pose from position.
var actor: Node3D
var propulsion := 0.0

func _process(delta: float) -> void:
	var wet: bool=is_instance_valid(actor) and actor.health>0 and actor.swim_volume()!=null
	influence=move_toward(influence,1.0 if wet else 0.0,delta*9)
	var speed: float=Vector2(actor.velocity.x,actor.velocity.y).length() if wet else 0.0
	propulsion=move_toward(propulsion,clampf(speed/4.5,0.0,1.0),delta*3.5)
	if wet and not actor.controls_suspended:
		cycle=fposmod(cycle+delta*lerpf(2.0,3.3,propulsion),TAU)

func _process_modification_with_delta(_delta: float) -> void:
	var skeleton:=get_skeleton()
	if not is_instance_valid(actor): return
	# Look along the water route rather than down toward the floor when prone.
	aim(skeleton,"Neck","Head",Vector3(0,.84,-.54))
	aim(skeleton,"Head","HeadTop_End",Vector3(0,.92,-.38))
	for side in [1.0,-1.0]:
		var label: String="Left" if side>0 else "Right"
		var phase:=fposmod(cycle/TAU+(0.5 if side<0 else 0.0),1.0)*4.0
		var key:=floori(phase)
		var blend:=smoothstep(0.0,1.0,fposmod(phase,1.0))
		var kick: float=sin(cycle*2.0)*side*lerpf(.08,.22,propulsion)
		aim(skeleton,label+"UpLeg",label+"Leg",Vector3(side*.10,-.98,kick))
		aim(skeleton,label+"Leg",label+"Foot",Vector3(side*.04,-.96,maxf(0.0,-kick)*1.6))
		aim(skeleton,label+"Foot",label+"ToeBase",Vector3(0.0,-.83,.30))
		if actor.melee_lock>0 or (label=="Right" and (actor.charge_held or actor.fire_lock>0)): continue
		# Reach, catch below the shoulder, pull to the hip, recover elbow-first.
		# Opposite phases stop the heavy cannon and free hand crossing together.
		var upper: Array[Vector3]=[Vector3(side*.30,.94,.08),Vector3(side*.58,.50,.64),Vector3(side*.34,-.90,.25),Vector3(side*.60,.12,-.70)]
		var lower: Array[Vector3]=[Vector3(side*.10,.99,.10),Vector3(side*-.16,-.35,.92),Vector3(side*.13,-.91,.39),Vector3(side*-.16,.96,-.22)]
		var arm: Vector3=upper[key].lerp(upper[(key+1)%4],blend)
		var hand: Vector3=lower[key].lerp(lower[(key+1)%4],blend)
		# At rest use a smaller scull instead of continuously sprint-swimming.
		arm=Vector3(side*.66,-.16,.50).lerp(arm,propulsion)
		hand=Vector3(side*.24,.55,.68).lerp(hand,propulsion)
		aim(skeleton,label+"Arm",label+"ForeArm",arm)
		aim(skeleton,label+"ForeArm",label+"Hand",hand)
