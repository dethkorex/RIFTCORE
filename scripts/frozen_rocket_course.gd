extends Node3D
## Authored coolant spillway. All movement goes through the rider's CharacterBody.
const KIT := preload("res://scripts/frozen_kit.gd")
const LENGTH := 2040.0
const MAX_SPEED := 20.0
const HOVER_HEIGHT := .50
const GATE_CLEARANCE := 2.15
const MINIMUM_SECONDS := LENGTH / MAX_SPEED
const PATH := [Vector2(0,0),Vector2(35,0),Vector2(120,-18),Vector2(190,-18),Vector2(270,-8),Vector2(330,-8),Vector2(420,-32),Vector2(480,-32),Vector2(550,-12),Vector2(620,-12),Vector2(710,-44),Vector2(770,-44),Vector2(850,-26),Vector2(920,-26),Vector2(1010,-58),Vector2(1080,-58),Vector2(1160,-38),Vector2(1225,-38),Vector2(1320,-76),Vector2(1390,-76),Vector2(1470,-48),Vector2(1540,-48),Vector2(1630,-94),Vector2(1700,-94),Vector2(1790,-68),Vector2(1860,-68),Vector2(1950,-108),Vector2(2040,-108)]
const GAPS := [Vector2(360,386),Vector2(805,833),Vector2(1120,1150),Vector2(1590,1618),Vector2(1810,1844)]
const GATES := [155.0,305.0,455.0,590.0,745.0,895.0,1050.0,1200.0,1360.0,1510.0,1690.0,1990.0]
const PADS := [345.0,790.0,1105.0,1575.0,1795.0]
var dock := Vector3(235,1.25,0)
var return_at := Vector3(243,2.15,0)
var stage: Node3D
var boards := {}
var readout: Label

func _ready() -> void:
	stage = get_parent().get_parent()
	add_to_group(&"frozen_rocket_course")
	build_track()
	var station := stage.get_node_or_null("TERRAIN/MidpointCheckpoint") as Node3D
	if station:
		dock = station.global_position + Vector3(4,0,0)
		return_at = station.global_position + Vector3(8,.95,0)
	var entrance := KIT.new()
	entrance.piece = KIT.Piece.ROCKET_BOARD
	add_child(entrance)
	entrance.global_position = dock + Vector3.UP * .18
	label(self,"ROCKET SPILLWAY",to_local(dock + Vector3(0,2.75,0)),Color("83edff"))
	label(self,"HOLD UP TO BOARD",to_local(dock + Vector3(0,2.2,0)),Color.WHITE)
	var ui := CanvasLayer.new()
	ui.layer = 12
	add_child(ui)
	readout = Label.new()
	readout.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	readout.position = Vector2(-360,94)
	readout.size = Vector2(720,90)
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	readout.add_theme_font_override("font",preload("res://assets/ui/fonts/BarlowCondensed-ExtraBoldItalic.ttf"))
	readout.add_theme_font_size_override("font_size",26)
	readout.add_theme_color_override("font_outline_color",Color("061222"))
	readout.add_theme_constant_override("outline_size",8)
	readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(readout)
	readout.hide()

func ground_height(x: float) -> float:
	for i in range(1,PATH.size()):
		if x <= PATH[i].x:
			return lerpf(PATH[i-1].y,PATH[i].y,clampf(inverse_lerp(PATH[i-1].x,PATH[i].x,x),0,1))
	return PATH[-1].y

func in_gap(x: float) -> bool:
	for gap in GAPS:
		if x > gap.x and x < gap.y:
			return true
	return false

func build_track() -> void:
	var cuts: Array[float] = [0.0,LENGTH+12.0]
	for point in PATH:
		cuts.append(point.x)
	for gap in GAPS:
		cuts.append(gap.x)
		cuts.append(gap.y)
	cuts.sort()
	for i in range(1,cuts.size()):
		var a := cuts[i-1]
		var b := cuts[i]
		if b-a < .01 or in_gap((a+b)*.5):
			continue
		var segments := ceili((b-a)/12.0)
		for j in segments:
			var start := Vector2(lerpf(a,b,float(j)/segments),0)
			var end := Vector2(lerpf(a,b,float(j+1)/segments),0)
			start.y = ground_height(start.x)
			end.y = ground_height(end.x)
			var floor_body := StaticBody3D.new()
			floor_body.add_to_group(&"ice_deck")
			floor_body.position = Vector3((start.x+end.x)*.5,(start.y+end.y)*.5,0)
			floor_body.rotation.z = (end-start).angle()
			add_child(floor_body)
			var size := Vector3(start.distance_to(end)+.025,.6,3.6)
			KIT.collider(floor_body,Vector3(0,-.3,0),size)
			decorate(floor_body,Vector3(0,-.3,0),size,KIT.ICE)
			decorate(floor_body,Vector3(0,-.44,1.85),Vector3(size.x,.18,.16),KIT.paint(Color("285c78"),.5))
	var back := KIT.SNOW
	for i in ceili(LENGTH/24.0):
		var x := i*24.0+12
		var y := ground_height(x)
		decorate(self,Vector3(x,y+9,-4.0),Vector3(24.0,26,.7),back)
		decorate(self,Vector3(x,y+6,-3.58),Vector3(.45,18,.38),KIT.paint(Color("1e3544"),.25))
		decorate(self,Vector3(x,y+1.0,-3.45),Vector3(21,.11,.1),KIT.paint(Color("62d4e9"),.1,.15))
		for rib in 3:
			var glacier := SphereMesh.new()
			glacier.radial_segments = 24
			glacier.rings = 12
			var rock := KIT.mesh(self,glacier,KIT.SNOW,Vector3(x+(rib-1)*7.6,y+5.5+float((i+rib)%3)*2.1,-4.05))
			rock.scale = Vector3(5.5,10.0+float(i%3)*2,1.9)
			rock.rotation.z = .14*sin(i+rib)
			rock.visibility_range_end = 70
			rock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if i%2 == 0:
			kit_piece(KIT.Piece.COOLANT_PUMP,Vector3(x+3,y+.5,-2.4))
			decorate(self,Vector3(x+3,y+5.5,-2.6),Vector3(.24,8,.28),KIT.paint(Color("31444f"),.4))
		if i % 3 == 0:
			var icicles := kit_piece(KIT.Piece.ICICLES,Vector3(x,y+13,-2.5))
			icicles.scale = Vector3(2.0,2.1,1)
	for x in GATES:
		var gate := kit_piece(KIT.Piece.SPIKE_GATE,Vector3(x,ground_height(x),0))
		var blocker := StaticBody3D.new()
		blocker.add_to_group(&"frozen_spike_gate")
		gate.add_child(blocker)
		KIT.collider(blocker,Vector3(0,GATE_CLEARANCE+2.26,0),Vector3(2.8,4.52,3.6))
		label(self,"CROUCH",Vector3(x-22,ground_height(x-22)+3,0),Color("ffac62"))
	for x in PADS:
		kit_piece(KIT.Piece.JUMP_PAD,Vector3(x,ground_height(x),0))
		label(self,"HOLD JUMP · THRUST",Vector3(x-22,ground_height(x-22)+3.2,0),Color("8aefff"))
	label(self,"RELAY A · SPILLWAY EXIT",Vector3(LENGTH-14,ground_height(LENGTH)+3,0),Color("8affbb"))

func decorate(parent: Node3D, at: Vector3, size: Vector3, material: Material) -> void:
	var mesh := KIT.box(parent,at,size,material)
	mesh.visibility_range_end = 85
	mesh.visibility_range_end_margin = 8
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func kit_piece(type: int, at: Vector3) -> Node3D:
	var prop := KIT.new()
	prop.piece = type
	prop.position = at
	add_child(prop)
	return prop

func label(parent: Node3D, caption: String, at: Vector3, color: Color) -> void:
	var sign := Label3D.new()
	sign.text = caption
	sign.font = preload("res://assets/ui/fonts/BarlowCondensed-ExtraBoldItalic.ttf")
	sign.font_size = 54
	sign.pixel_size = .006
	sign.modulate = color
	sign.outline_size = 9
	sign.position = at
	sign.visibility_range_end = 45
	parent.add_child(sign)

func _physics_process(_delta: float) -> void:
	for actor in stage.get_node("Actors").get_children():
		if not actor is RiftPlayer or not actor.is_physics_processing() or actor.health <= 0.0:
			continue
		if is_instance_valid(actor.rocket_course):
			continue
		var offset: Vector3 = actor.global_position-dock
		if absf(offset.x)<1.7 and absf(offset.y-.85)<1.0 and not actor.controls_suspended and actor.movement_axis("climb_down","climb_up")>.4:
			mount(actor)

func mount(actor: RiftPlayer) -> void:
	actor.reset_predicted_position(to_global(Vector3(0,.85+HOVER_HEIGHT,0)),Vector3(12,0,0),1)
	actor.rocket_course = self
	actor.rocket_speed = 12.0
	actor.rocket_seconds = 0.0
	actor.cancel_charge()
	actor.cancel_saber_charge()
	relocated(actor)

func relocated(actor: RiftPlayer) -> void:
	var mission := stage.get_parent()
	if mission.has_method("mark_position_reset") and mission.host:
		mission.mark_position_reset(actor)
	var camera := stage.get_node("CameraRig") as SideCameraRig
	camera.max_x = maxf(camera.max_x,global_position.x+LENGTH+20)
	camera.minimum_follow_y = -160.0
	if camera.target == actor:
		camera.snap_to_target()

func simulate(actor: RiftPlayer, delta: float) -> void:
	var local := to_local(actor.global_position)
	if local.x < -5 or local.x > LENGTH+20:
		actor.rocket_course = null
		return
	if actor.controls_suspended:
		actor.velocity = Vector3.ZERO
		return
	actor.rocket_seconds += delta
	var crouch := actor.action_held("crouch") or actor.action_held("crouch_stick") or actor.movement_axis("climb_down","climb_up") < -.4
	actor.set_crouch(crouch)
	actor.wall_sliding = false
	actor.dash_left = 0.0
	var slope := (ground_height(local.x+1)-ground_height(local.x-1))*.5
	var brake := actor.movement_axis("move_left","move_right") < -.25
	var acceleration := 1.25-slope*8.5
	actor.rocket_speed = clampf(actor.rocket_speed + (acceleration- (8.0 if brake else 0.0))*delta,9.0,MAX_SPEED)
	actor.velocity.x = actor.rocket_speed
	if local.x>=LENGTH:
		actor.velocity.x = 0.0
	var half := actor.standing_capsule.height*.5
	var feet := local.y-half
	var on_track := not in_gap(local.x) and feet-ground_height(local.x)<HOVER_HEIGHT+.22 and actor.velocity.y<=maxf(1.0,slope*actor.rocket_speed+.8)
	var thrust := actor.action_held("jump") and not crouch
	if thrust and on_track:
		actor.velocity.y = 7.0
	elif on_track:
		var next_ground := ground_height(local.x+actor.velocity.x*delta)
		actor.velocity.y = clampf((next_ground+half+HOVER_HEIGHT-local.y)/delta,-20.0,20.0)
	else:
		actor.velocity.y = clampf(actor.velocity.y + (4.0 if thrust else -28.0)*delta,-32.0,8.0)
	for pad in PADS:
		if on_track and absf(local.x-pad)<.55:
			actor.velocity.y = maxf(actor.velocity.y,8.0)
	actor.velocity.z = -actor.global_position.z*18.0
	actor.facing = 1.0
	actor.move_and_slide()
	actor.update_character_visuals(1.0)
	local = to_local(actor.global_position)
	var lethal := local.y-half < ground_height(local.x)-9.0
	for index in actor.get_slide_collision_count():
		var hit := actor.get_slide_collision(index).get_collider()
		if is_instance_valid(hit) and hit.is_in_group(&"frozen_spike_gate"):
			lethal = true
	for x in GATES:
		if absf(local.x-x)<1.85:
			var head := local.y-half+(1.05 if actor.low_profile else half*2)
			lethal = lethal or (head>ground_height(x)+GATE_CLEARANCE and local.y-half<ground_height(x)+GATE_CLEARANCE+4.52)
	if lethal:
		if not actor.local_prediction:
			actor.rocket_course = null
			actor.die_in_pit()
		return
	if local.x >= LENGTH and on_track and not actor.local_prediction:
		finish(actor)

func finish(actor: RiftPlayer) -> void:
	var switches := stage.get_node_or_null("GateRelays")
	if switches:
		switches.set_active(switches.active | 1)
	actor.rocket_course = null
	actor.set_crouch(false)
	actor.reset_predicted_position(return_at,Vector3.ZERO,1)
	RiftAudio.play_effect(&"checkpoint")
	relocated(actor)

func _process(_delta: float) -> void:
	var camera := stage.get_node("CameraRig") as SideCameraRig
	var local_actor := camera.target
	readout.visible = is_instance_valid(local_actor) and local_actor.rocket_course == self and local_actor.health > 0
	if readout.visible:
		var progress := clampf(to_local(local_actor.global_position).x/LENGTH,0,1)*100
		var instruction := "HOLD JUMP: THRUST   ·   DOWN: CROUCH   ·   LEFT: BRAKE"
		var here := to_local(local_actor.global_position).x
		for gate in GATES:
			if gate-here>0 and gate-here<30:
				instruction = "CROUCH GATE AHEAD  ·  HOLD DOWN"
		for pad in PADS:
			if pad-here>0 and pad-here<30:
				instruction = "GAP AHEAD  ·  HOLD JUMP TO THRUST"
		readout.text = "ROCKET SPILLWAY  ·  %d%%  ·  %.1f m/s  ·  %02d:%02d\n%s" % [progress,local_actor.rocket_speed,int(local_actor.rocket_seconds)/60,int(local_actor.rocket_seconds)%60,instruction]
	var live := {}
	for actor in stage.get_node("Actors").get_children():
		if not actor is RiftPlayer or actor.rocket_course != self or actor.health<=0:
			continue
		var key := actor.get_instance_id()
		live[key] = true
		if not boards.has(key):
			boards[key] = kit_piece(KIT.Piece.ROCKET_BOARD,Vector3.ZERO)
		var board: Node3D = boards[key]
		board.global_position = actor.global_position+Vector3(.15,-actor.standing_capsule.height*.5-.065,0)
		var x := to_local(actor.global_position).x
		var hovering := not in_gap(x) and absf(actor.global_position.y-global_position.y-actor.standing_capsule.height*.5-ground_height(x)-HOVER_HEIGHT)<.3
		board.rotation.z = atan2(ground_height(x+1)-ground_height(x-1),2) if hovering else clampf(actor.velocity.y*.018,-.3,.3)
		board.nozzle.scale.x = 1.5 if actor.velocity.y>.8 else .7
	for key in boards.keys():
		if not live.has(key):
			boards[key].queue_free()
			boards.erase(key)
