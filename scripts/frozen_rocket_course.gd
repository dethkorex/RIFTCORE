extends Node3D

const UI := preload("res://scripts/rift_ui.gd")
## Authored coolant spillway. All movement goes through the rider's CharacterBody.
const KIT := preload("res://scripts/frozen_kit.gd")
const ROUTE := preload("res://scripts/rocket_spillway_route.gd")
const LENGTH := ROUTE.LENGTH
const MAX_SPEED := 20.0
const HOVER_HEIGHT := .49
const JUMP_SPEED := 5.35
const PAD_LAUNCH_SPEED := 7.25
const MAX_BOOST_HEIGHT := 2.4
const HELD_ASCENT_GRAVITY := 12.0
const GLIDE_GRAVITY := 8.0
const FALL_GRAVITY := 27.0
const MINIMUM_SECONDS := LENGTH / MAX_SPEED
const PATH := ROUTE.GRADE
const GAPS := ROUTE.HOP_GAPS + ROUTE.BOOST_GAPS
const GATES := ROUTE.OVERHEAD
const SPIKES := ROUTE.SPIKES
const WARNING_DISTANCE := 36.0

var dock := Vector3(235,1.25,0)
var return_at := Vector3(243,2.15,0)
var stage: Node3D
var boards := {}
var readout: Label
var pads: Array[float] = []
var warnings: Array[Dictionary] = []

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
	var ui := CanvasLayer.new()
	ui.layer = 12
	add_child(ui)
	readout = UI.hud_readout(ui, 98, 580)

func ground_height(x: float) -> float:
	return ROUTE.surface_at(x)

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
		kit_piece(KIT.Piece.GAP_BEACON, Vector3(gap.x, ground_height(gap.x), 0))
		var receiving_lip := kit_piece(KIT.Piece.GAP_BEACON, Vector3(gap.y, ground_height(gap.y), 0))
		receiving_lip.rotation.y = PI
	for gap in ROUTE.HOP_GAPS:
		warnings.append({"x": gap.x, "text": "BROKEN DECK  ·  JUMP AT THE EDGE", "color": Color("9deeff")})
	for gap in ROUTE.BOOST_GAPS:
		var boost_at: float = gap.x - ROUTE.PAD_OFFSET
		pads.append(boost_at)
		warnings.append({"x": boost_at, "text": "BOOST GAP  ·  KEEP SPEED / HOLD JUMP", "color": Color("9deeff")})
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
		var gate := kit_piece(KIT.Piece.SPIKE_GATE, Vector3(x, ground_height(x), 0))
		gate.rotation.z = track_pitch(x)
		var height := KIT.GATE_TOP - KIT.GATE_CLEARANCE
		add_hazard(gate, KIT.GATE_CLEARANCE + height * .5, Vector3(KIT.GATE_WIDTH, height, 3.6))
		warnings.append({"x": x, "text": "SPIKE GATE  ·  HOLD CROUCH", "color": Color("ffac62")})
	for rack in SPIKES:
		var prop := kit_piece(KIT.Piece.SPIKE_RACK, Vector3(rack.x, ground_height(rack.x), 0), rack.y)
		prop.rotation.z = track_pitch(rack.x)
		add_hazard(prop, KIT.RACK_HEIGHT * .5, Vector3(rack.y, KIT.RACK_HEIGHT, 3.5))
		warnings.append({"x": rack.x, "text": "FLOOR SPIKES  ·  JUMP", "color": Color("ffac62")})
	for x in pads:
		var pad := kit_piece(KIT.Piece.JUMP_PAD, Vector3(x, ground_height(x), 0))
		pad.rotation.z = track_pitch(x)
	warnings.sort_custom(func(a: Dictionary, b: Dictionary): return a.x < b.x)

func add_hazard(prop: Node3D, height: float, size: Vector3) -> void:
	var blocker := StaticBody3D.new()
	blocker.add_to_group(&"spillway_spikes")
	prop.add_child(blocker)
	KIT.collider(blocker, Vector3(0, height, 0), size)

func track_pitch(x: float) -> float:
	return atan2(ground_height(x + 1.0) - ground_height(x - 1.0), 2.0)

func decorate(parent: Node3D, at: Vector3, size: Vector3, material: Material) -> void:
	var mesh := KIT.box(parent,at,size,material)
	mesh.visibility_range_end = 85
	mesh.visibility_range_end_margin = 8
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func kit_piece(type: int, at: Vector3, span := 0.0) -> Node3D:
	var prop := KIT.new()
	prop.piece = type
	prop.position = at
	if span > 0.0:
		prop.width = span
	add_child(prop)
	return prop

func _physics_process(_delta: float) -> void:
	for actor in stage.get_node("Actors").get_children():
		if not actor is RiftPlayer or not actor.is_physics_processing() or actor.health <= 0.0:
			continue
		if is_instance_valid(actor.rocket_course):
			continue
		if can_board(actor) and actor.movement_axis("climb_down","climb_up") > .4:
			mount(actor)

func can_board(actor: RiftPlayer) -> bool:
	var offset := actor.global_position - dock
	return absf(offset.x) < 1.7 and absf(offset.y - .85) < 1.0 and not actor.controls_suspended

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
	camera.minimum_follow_y = global_position.y + ground_height(LENGTH) - 17.0
	if camera.target == actor:
		camera.snap_to_target()

func simulate(actor: RiftPlayer, delta: float) -> void:
	var local := to_local(actor.global_position)
	if local.x < -5 or local.x > LENGTH + 20:
		actor.rocket_course = null
		return
	if actor.controls_suspended:
		actor.velocity = Vector3.ZERO
		return
	actor.rocket_seconds += delta
	var crouch := actor.action_held("crouch") or actor.action_held("crouch_stick") or actor.movement_axis("climb_down", "climb_up") < -.4
	actor.wall_sliding = false
	actor.dash_left = 0.0
	actor.set_crouch(crouch)
	var ground := ground_height(local.x)
	var slope := (ground_height(local.x + 1.0) - ground_height(local.x - 1.0)) * .5
	var previous_floor_speed := (ground - ground_height(local.x - actor.velocity.x * delta)) / delta
	var brake := actor.movement_axis("move_left", "move_right") < -.25
	var acceleration := 1.8 - slope * 8.5
	actor.rocket_speed = clampf(actor.rocket_speed + (acceleration - (8.0 if brake else 0.0)) * delta, 10.0, MAX_SPEED)
	actor.velocity.x = actor.rocket_speed if local.x < LENGTH else 0.0
	var half := actor.standing_capsule.height * .5
	var next_x := local.x + actor.velocity.x * delta
	var next_ground := ground_height(next_x)
	var floor_speed := (next_ground - ground) / delta
	var foot := local.y - half
	var clearance := foot - ground
	var lift := actor.velocity.y - previous_floor_speed
	var on_track := not in_gap(local.x) and clearance >= -.08 and clearance < HOVER_HEIGHT + .11 and lift <= 1.0
	var glide := actor.action_held("jump") and not crouch
	if actor.action_pressed("jump") and on_track and not crouch:
		lift = JUMP_SPEED
	elif on_track and not in_gap(next_x):
		lift = clampf((HOVER_HEIGHT - clearance) / delta, -20.0, 20.0)
	else:
		var gravity := FALL_GRAVITY
		if glide:
			gravity = HELD_ASCENT_GRAVITY if lift > 0.0 else GLIDE_GRAVITY
		lift -= gravity * delta
	for pad in pads:
		if local.x <= pad and next_x > pad and clearance >= -.08 and clearance < HOVER_HEIGHT + 1.2:
			lift = PAD_LAUNCH_SPEED
	# Keep the jump arc consistent on grades by bounding lift above the deck.
	var lift_limit := (HOVER_HEIGHT + MAX_BOOST_HEIGHT - clearance) / delta
	actor.velocity.y = floor_speed + clampf(lift, -32.0, maxf(-32.0, lift_limit))
	actor.velocity.z = -actor.global_position.z * 18.0
	actor.facing = 1.0
	actor.move_and_slide()
	actor.update_character_visuals(1.0)
	actor.fire_lock = maxf(0.0, actor.fire_lock - delta)
	if not actor.local_prediction:
		actor.update_charge(delta)

	local = to_local(actor.global_position)
	if hit_spikes(actor, local, half) or local.y - half < ground_height(local.x) - 9.0:
		if not actor.local_prediction:
			actor.rocket_course = null
			actor.die_in_pit()
		return
	if local.x >= LENGTH and on_track and not actor.local_prediction:
		finish(actor)

func hit_spikes(actor: RiftPlayer, local: Vector3, half: float) -> bool:
	for index in actor.get_slide_collision_count():
		var hit := actor.get_slide_collision(index).get_collider()
		if is_instance_valid(hit) and hit.is_in_group(&"spillway_spikes"):
			return true
	var feet := local.y - half
	var head := feet + (1.05 if actor.low_profile else half * 2)
	for x in GATES:
		if absf(local.x - x) < KIT.GATE_WIDTH * .5 + .35:
			var floor_height := ground_height(local.x)
			if head > floor_height + KIT.GATE_CLEARANCE and feet < floor_height + KIT.GATE_TOP:
				return true
	for rack in SPIKES:
		if absf(local.x - rack.x) < rack.y * .5 + .35 and feet < ground_height(local.x) + KIT.RACK_HEIGHT:
			return true
	return false

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
	var eligible := is_instance_valid(local_actor) and local_actor.health > 0
	var riding := eligible and local_actor.rocket_course == self
	var boarding := eligible and not is_instance_valid(local_actor.rocket_course) and can_board(local_actor)
	readout.visible = riding or boarding
	if boarding:
		var key := RiftSettings.binding_label("climb_up", "key")
		var pad := RiftSettings.binding_label("climb_up", "pad")
		readout.modulate = Color.WHITE
		readout.text = "ROCKET SPILLWAY  ·  HOLD %s / %s TO BOARD" % [key, pad]
	if riding:
		var progress := clampf(to_local(local_actor.global_position).x/LENGTH,0,1)*100
		var instruction := "JUMP: HOP / GLIDE    ·    CROUCH: SLIDE    ·    LEFT: BRAKE    ·    BUSTER: FIRE"
		var here := to_local(local_actor.global_position).x
		readout.modulate = Color.WHITE
		for warning in warnings:
			var distance: float = warning.x - here
			if distance >= -1.9 and distance <= WARNING_DISTANCE:
				instruction = "%s   ·   %dm" % [warning.text, ceili(maxf(distance, 0.0))]
				readout.modulate = warning.color
				break
		readout.text = "ROCKET SPILLWAY  ·  %d%%  ·  %.1f m/s  ·  %02d:%02d\n%s" % [progress, local_actor.rocket_speed, int(local_actor.rocket_seconds) / 60, int(local_actor.rocket_seconds) % 60, instruction]

	var live := {}
	for actor in stage.get_node("Actors").get_children():
		if not actor is RiftPlayer or actor.rocket_course != self or actor.health<=0:
			continue
		var key := actor.get_instance_id()
		live[key] = true
		if not boards.has(key):
			boards[key] = kit_piece(KIT.Piece.ROCKET_BOARD,Vector3.ZERO)
		var board: Node3D = boards[key]
		var x := to_local(actor.global_position).x
		var hovering := not in_gap(x) and absf(actor.global_position.y-global_position.y-actor.standing_capsule.height*.5-ground_height(x)-HOVER_HEIGHT)<.3
		var pitch := track_pitch(x) if hovering else clampf(actor.velocity.y*.018,-.3,.3)
		var deck_up := Vector3.UP.rotated(Vector3.BACK,pitch)
		var feet: Vector3 = actor.global_position-Vector3.UP*actor.standing_capsule.height*.5
		board.global_position = feet-deck_up*.075
		board.rotation.z = pitch
		if actor.model_root:
			actor.model_root.basis = Basis(Vector3.BACK,pitch)*Basis(Vector3.UP,.30)
			# The grip ridges sit 0.146 m above the board origin.
			actor.model_root.position = feet-actor.global_position+deck_up*.071
		board.nozzle.scale.x = 1.5 if actor.velocity.y>.8 else .7
	for key in boards.keys():
		if not live.has(key):
			var former_rider := instance_from_id(key) as RiftPlayer
			if is_instance_valid(former_rider) and former_rider.model_root and not is_instance_valid(former_rider.rocket_course):
				former_rider.model_root.position = Vector3.DOWN*former_rider.standing_capsule.height*.5
				if former_rider.is_physics_processing():
					former_rider.model_root.rotation.z = 0.0
			boards[key].queue_free()
			boards.erase(key)
