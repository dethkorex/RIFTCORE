extends Node3D

const UI := preload("res://scripts/rift_ui.gd")
## Host-owned valves and pressure lock; clients render/predict the same clock.
const VENT_SECONDS := 90.0
const HOLD_SECONDS := 1.8
var act_number := 1
var entry_x := 176.0
var exit_x := 439.0
var valves: Array[Dictionary] = []
var turbines: Array[Dictionary] = []
var grids: Array[Dictionary] = []
var locks: Array[Dictionary] = []
var redirects: Array[Dictionary] = []
var active_valves := 0
var elapsed := 0.0
var started := false
var completed := false
var clock := 0.0
var holds := [0.0,0.0,0.0]
var next_hit := {}
var readout: Label
var stage: Node3D
var authority := true
var notice_left := 0.0

func _ready() -> void:
	stage=get_parent().get_parent()
	var mission := stage.get_parent()
	if mission.has_method("mark_position_reset"): authority=mission.host
	var layer := CanvasLayer.new()
	layer.layer=11
	add_child(layer)
	var screen := Control.new()
	layer.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter=Control.MOUSE_FILTER_IGNORE
	readout = UI.hud_readout(screen, 146, 610)

func actors() -> Array[RiftPlayer]:
	var result: Array[RiftPlayer]=[]
	for actor in stage.get_node("Actors").get_children():
		if actor is RiftPlayer and actor.health>0: result.append(actor)
	return result

func grid_phase(offset: float) -> float:
	return fposmod(clock+offset,6.4)

func grid_live(offset: float) -> bool:
	var phase := grid_phase(offset)
	return phase>=3.3 and phase<4.7

func blade_hit(at: Vector3, blade: Dictionary) -> bool:
	var p: Vector3=at-blade.at
	var radius:=Vector2(p.x,p.y).length()
	if absf(p.z)>.8 or radius>2.80 or radius<.43: return false
	var angle := clock*.62+float(blade.offset)
	var relative := fposmod(atan2(p.y,p.x)-angle,TAU/3)
	return minf(relative,TAU/3-relative)<(.19+.42/maxf(radius,.8))

func _physics_process(delta: float) -> void:
	var mission := stage.get_parent()
	clock=mission.factory_trap_clock if mission.has_method("mark_position_reset") else clock+delta
	var squad := actors()
	if not authority: return
	if act_number==2:
		if not started and squad.any(func(a): return not a.controls_suspended and a.global_position.x>=entry_x and a.global_position.x<exit_x):
			started=true
			notice_left=9
			RiftAudio.play_effect(&"checkpoint")
		if started and not completed and squad.any(func(a): return not a.controls_suspended):
			elapsed=minf(VENT_SECONDS,elapsed+delta)
		for valve in valves:
			var index: int=valve.index
			if active_valves&(1<<index): continue
			var held:=squad.any(func(a): return near_valve(a,valve.at) and a.action_held(&"field_interact"))
			holds[index]=minf(HOLD_SECONDS,holds[index]+delta) if held else 0.0
			if holds[index]>=HOLD_SECONDS:
				active_valves|=1<<index
				RiftAudio.play_effect(&"checkpoint")
		if not completed and started and active_valves==7 and elapsed>=VENT_SECONDS:
			completed=true
			RiftAudio.play_effect(&"checkpoint")
			notice_left=6
	for actor in squad:
		if actor.local_prediction or actor.controls_suspended: continue
		if float(next_hit.get(actor.get_instance_id(),-1))>clock: continue
		for grid in grids:
			var p: Vector3=actor.global_position-grid.at
			if not insulated(actor) and grid_live(grid.offset) and absf(p.x)<float(grid.span)*.5 and absf(p.y)<1.0 and absf(p.z)<1.2:
				actor.take_boss_hit(14.0,grid.at,4,true)
				next_hit[actor.get_instance_id()]=clock+1.0
				break

		for blade in turbines:
			if blade_hit(actor.global_position,blade):
				actor.take_damage(18.0,blade.at)
				next_hit[actor.get_instance_id()]=clock+1.0
				break

func insulated(actor: RiftPlayer) -> bool:
	if not actor.is_on_floor(): return false
	for i in actor.get_slide_collision_count():
		var hit:=actor.get_slide_collision(i)
		if hit.get_normal().y>.5 and hit.get_collider().is_in_group(&"abyssal_insulated"): return true
	return false

func near_valve(actor: RiftPlayer, at: Vector3) -> bool:
	return not actor.controls_suspended and absf(actor.global_position.x-at.x)<1.5 and absf(actor.global_position.y-at.y-.85)<.75

func _process(delta: float) -> void:
	notice_left=maxf(0,notice_left-delta)
	for valve in valves:
		var i: int=valve.index
		valve.wheel.rotation.z=TAU if active_valves&(1<<i) else float(holds[i])/HOLD_SECONDS*TAU
	for redirect in redirects:
		var direction:=Vector3.RIGHT if active_valves&(1<<int(redirect.valve)) else Vector3.LEFT
		redirect.jet.direction=direction
		redirect.fx.direction=direction
	for turbine in turbines: turbine.rotor.rotation.z=clock*.62+float(turbine.offset)
	for grid in grids:
		grid.fx.active=grid_live(grid.offset)
		grid.fx.warning=grid_phase(grid.offset)>=1.9 and grid_phase(grid.offset)<3.3
	for lock in locks:
		lock.slab.position.y=move_toward(lock.slab.position.y,lock.at.y+(6.1 if completed else 0.0),delta*5)
		# Keep the body solid until the actual slab clears a standing operator.
		lock.body.get_child(0).set_deferred("disabled",completed and lock.slab.position.y>=lock.at.y+2.1)
	var camera := stage.get_node("CameraRig") as SideCameraRig
	var local := camera.target
	readout.visible=is_instance_valid(local) and local.health>0 and not local.controls_suspended and local.global_position.x>15 and local.global_position.x<exit_x+12
	if not readout.visible: return
	var nearby := false
	for valve in valves:
		if near_valve(local,valve.at) and not (active_valves&(1<<int(valve.index))):
			readout.text="HOLD %s / %s  ·  VENT VALVE  ·  %d%%"%[RiftSettings.binding_label("field_interact","key"),RiftSettings.binding_label("field_interact","pad"),int(holds[valve.index]/HOLD_SECONDS*100)]
			nearby=true
			break
	if nearby: return
	if act_number==1:
		readout.text="NOVA  ·  Blue currents lift you. Amber platforms are insulated.\nWait for the electrical arc to switch off before crossing."
		readout.visible=local.global_position.x<40 or grids.any(func(g): return absf(local.global_position.x-g.at.x)<13)
	elif completed:
		readout.text="PRESSURE RESTORED  ·  SHARED LOCK OPEN\nThe two gate relays still control the boss door."
		readout.visible=notice_left>0 or absf(local.global_position.x-exit_x)<12
	elif started:
		var count:=int((active_valves&1)!=0)+int((active_valves&2)!=0)+int((active_valves&4)!=0)
		readout.text="PRESSURE BREACH  ·  VALVES %d/3  ·  PRESSURE %d%%\n%s"%[count,roundi(100.0*(1.0-elapsed/VENT_SECONDS)),"NOVA  ·  Vent all three valves. Use the currents and insulated decks." if notice_left>0 else "Stabilize the pressure to open the release lock."]
	else:
		readout.visible=false

func snapshot() -> Array:
	return [active_valves,elapsed,started,completed,holds.duplicate()]

func apply_snapshot(state: Array) -> void:
	if state.size()!=5 or not state[4] is Array or state[4].size()!=3: return
	active_valves=clampi(int(state[0]),0,7)
	elapsed=clampf(float(state[1]),0,VENT_SECONDS)
	started=bool(state[2])
	completed=bool(state[3]) and active_valves==7 and elapsed>=VENT_SECONDS
	holds=state[4].duplicate()
