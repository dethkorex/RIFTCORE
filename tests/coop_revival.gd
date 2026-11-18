extends SceneTree

class FakePeer extends Node:
	var sent := []
	var sender := 11
	func get_host() -> int: return 11
	func get_sender_id() -> int: return sender
	func call_func(f: Callable,a=null,b=null,c=null,d=null) -> void:
		sent.append([f,a,b,c,d])

var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, text: String) -> void:
	print("PASS " if ok else "FAIL ",text)
	failures += int(not ok)

func run() -> void:
	var mission=load("res://tests/coop_revival_fixture.gd").new()
	root.add_child(mission)
	mission.host=true
	mission.peer=FakePeer.new()
	mission.roster=[11,12]
	mission.local_profile=load("res://scripts/rogue_profile.gd").new()
	mission.local_profile.manual_only=true
	mission.stage=Node3D.new()
	mission.add_child(mission.stage)
	var actors:=Node3D.new()
	actors.name="Actors"
	mission.stage.add_child(actors)
	var markers:=Node3D.new()
	markers.name="MARKERS"
	mission.stage.add_child(markers)
	var spawn:=Marker3D.new()
	spawn.name="PlayerSpawn"
	markers.add_child(spawn)
	spawn.position=Vector3(0,10.9,0)
	var terrain:=Node3D.new()
	terrain.name="TERRAIN"
	mission.stage.add_child(terrain)
	var beacon=load("res://scripts/factory_checkpoint.gd").new()
	beacon.name="MidpointCheckpoint"
	terrain.add_child(beacon)
	beacon.position=Vector3(20,10,0)
	beacon.activated.connect(mission.activate_checkpoint.bind("TERRAIN/MidpointCheckpoint"))
	var floor_body:=StaticBody3D.new()
	var collider:=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=Vector3(40,1,6)
	collider.shape=shape
	floor_body.add_child(collider)
	terrain.add_child(floor_body)
	floor_body.position=Vector3(0,9.5,0)
	for i in 2:
		var actor=load("res://scenes/actors/riftcore_player.tscn").instantiate()
		actors.add_child(actor)
		actor.global_position=Vector3(i*1.7,10.9,0)
		actor.remote_input=true
		actor.quick_profile=mission.local_profile
		actor.invulnerable_time=100
		mission.operators.append(actor)
	for i in 30:
		await physics_frame
		mission.record_corpse_anchors(1.0/60)
	var fallen=mission.operators[1]
	var rescuer=mission.operators[0]
	var safe: Vector3=fallen.global_position
	check(mission.safe_corpses[fallen.get_instance_id()].has("at"),"standing on a platform records a safe corpse location")
	fallen.lives=1
	fallen.global_position=Vector3(100,-100,0)
	mission.respawn_operator(fallen,true)
	check(fallen.lives==0 and fallen.health==0 and fallen.visible,"last life leaves a visible body")
	check(fallen.global_position.distance_to(safe)<.15,"pit corpse returns to the last reachable platform")
	check(fallen.has_meta("corpse_visual"),"fallen operator uses its own model in a corpse pose")
	floor_body.position.x+=1
	mission.record_corpse_anchors(.1)
	check(absf(fallen.global_position.x-safe.x-1)<.15,"a body stays on its platform as the platform moves")
	floor_body.position.x-=1
	mission.record_corpse_anchors(.1)
	var corpse_at: Vector3=fallen.global_position
	for actor in mission.operators: actor.set_physics_process(false)
	rescuer.remote_held[&"field_interact"]=true
	mission.start_reboot(0)
	check(is_equal_approx(mission.reboot_duration,4.0),"players with no talent can hold to revive in four seconds")
	mission.tick_reboot(2)
	var layer:=CanvasLayer.new()
	mission.add_child(layer)
	mission.build_revive_meter(layer)
	mission.update_revive_meter()
	check(mission.revive_meter.visible and is_equal_approx(mission.revive_meter.value,50),"hold bar fills to fifty percent halfway through")
	rescuer.remote_held.clear()
	mission.tick_reboot(.1)
	check(mission.reboot_left==0 and fallen.health==0,"releasing interact cancels the revive")
	rescuer.remote_held[&"field_interact"]=true
	mission.start_reboot(0)
	rescuer.health-=1
	mission.tick_reboot(.1)
	check(mission.reboot_left==0,"damage interrupts the revive")
	mission.start_reboot(0)
	rescuer.global_position.x-=1
	mission.tick_reboot(.1)
	check(mission.reboot_left==0,"walking away interrupts the revive")
	rescuer.global_position.x+=1
	mission.start_reboot(0)
	rescuer.global_position.x+=2
	fallen.global_position.x+=2
	mission.tick_reboot(.2)
	check(mission.reboot_left>0,"a platform carrying both players does not interrupt the revive")
	rescuer.global_position.x-=2
	fallen.global_position.x-=2
	mission.cancel_reboot()
	mission.start_reboot(0)
	mission.tick_reboot(4.1)
	check(fallen.health==fallen.max_health and fallen.lives==0,"revival restores full HP without adding extra lives")
	check(fallen.global_position.is_equal_approx(corpse_at),"revival happens at the body, not beside the rescuer")
	check(not fallen.has_meta("corpse_visual") and not fallen.has_meta("coop_down") and fallen.is_physics_processing(),"revival restores animation, physics and controls")
	fallen.set_physics_process(false)
	for rank in range(1,4):
		fallen.health=0
		fallen.set_meta("coop_down",true)
		mission.local_profile.owned["field_reboot"]=rank
		mission.start_reboot(0)
		check(is_equal_approx(mission.reboot_duration,[3.2,2.6,2.0][rank-1]),"Field Reboot rank %d speeds up revival"%rank)
		mission.cancel_reboot()
	beacon.activate(rescuer)
	var shared_at: Vector3=mission.checkpoint
	check(shared_at==beacon.global_position+Vector3.UP*.88 and mission.checkpoint_notices==1,"one player activates the squad checkpoint and host notification")
	check(mission.peer.sent.size()==1 and mission.peer.sent[0][4]==true,"checkpoint notification is sent reliably to every other squad member")
	mission.host=false
	mission.shared_checkpoints.clear()
	mission.checkpoint=Vector3.ZERO
	mission.receive_checkpoint(1,"TERRAIN/MidpointCheckpoint",shared_at)
	check(mission.checkpoint==shared_at and mission.checkpoint_notices==2,"a distant guest gets the same respawn and notification")
	mission.receive_checkpoint(1,"TERRAIN/MidpointCheckpoint",shared_at)
	check(mission.checkpoint_notices==2,"repeated checkpoint packets do not repeat the notification")
	mission.shared_checkpoints.clear()
	mission.receive_checkpoint(1,"TERRAIN/MidpointCheckpoint",shared_at,false)
	check(mission.checkpoint_notices==2 and mission.checkpoint==shared_at,"rejoining restores the checkpoint without a duplicate banner")
	mission.peer.sender=12
	mission.receive_checkpoint(1,"TERRAIN/ForgeHallCheckpoint",Vector3(99,99,0))
	check(mission.checkpoint==shared_at,"guests cannot forge a new squad checkpoint")
	mission.peer.free()
	mission.queue_free()
	await process_frame
	quit(failures)
