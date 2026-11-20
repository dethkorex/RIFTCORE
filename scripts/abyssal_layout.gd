extends Node3D
## Authored, metre-scale layouts. No random generation: changes are reviewable here.
const FX := preload("res://scripts/abyssal_fx.gd")
const SYSTEMS := preload("res://scripts/pressure_breach.gd")
const KIT := "res://assets/campaign/abyssal_plant/kit/"
@export var act_number := 1
var terrain: Node3D
var decor: Node3D
var systems: Node3D
var decks: Array[Vector3] = [] # x, surface y, width
var props := {}

const ROUTE_ONE := [
	Vector3(6,0,28),Vector3(24,0,8),Vector3(34,7,12),Vector3(47,7,6),Vector3(56,9.2,4),Vector3(64,11.4,4),Vector3(72,11.4,8),
	Vector3(87,0,22),Vector3(104,2.2,4),Vector3(112,4.4,4),Vector3(120,6.6,4),Vector3(131,6.6,12),Vector3(145,4.4,8),Vector3(157,2.2,8),Vector3(169,0,8),
	Vector3(181,0,8),Vector3(193,2.2,5),Vector3(202,4.4,4),Vector3(211,6.6,5),Vector3(222,6.6,8),Vector3(234,8.8,6),Vector3(244,11,6),
	Vector3(257,8.8,10),Vector3(271.5,7.35,8),Vector3(285.5,5,9),Vector3(300,3.2,10),Vector3(317,0,12),
	Vector3(333,-5,12),Vector3(348,-5,8),Vector3(359,-2.8,5),Vector3(369,-.6,5),Vector3(380,1.6,8),Vector3(393,3.8,8),
	Vector3(408,3.8,12),Vector3(423,6,8),Vector3(435,8.2,6),Vector3(446,10.4,6),Vector3(458,10.4,8),
	Vector3(472,8.2,10),Vector3(486,6,8),Vector3(499,3.8,10),Vector3(514,1.6,10),Vector3(529,.6,12),Vector3(549,.6,20),Vector3(568,.6,18)
]
const ROUTE_TWO := [
	Vector3(6,1,28),Vector3(28,3.2,10),Vector3(42,5.4,10),Vector3(56,7.6,10),Vector3(70,9.8,8),Vector3(84,7.6,8),Vector3(98,5.4,8),
	Vector3(104,4.8,4),Vector3(183,-3.4,18),Vector3(198,-1.2,10),Vector3(211,1,8),Vector3(222,3.2,6),Vector3(232,5.4,6),Vector3(243,7.6,6),Vector3(254,9.8,6),
	Vector3(268,7.6,8),Vector3(281,5.4,8),Vector3(295,3.2,8),Vector3(309,1,8),Vector3(317,-1.2,6),Vector3(334,12,6),Vector3(339,-3.4,20),
	Vector3(357,-1.2,12),Vector3(372,.6,10),Vector3(386,2.4,9),Vector3(400,3.3,10),Vector3(415,5.5,10),Vector3(429,7.5,8),
	Vector3(445,7.6,10),Vector3(461,5.4,10),Vector3(477,3.2,10),Vector3(493,1,10),Vector3(508,.75,10),Vector3(524,.75,12),Vector3(544,.75,20),Vector3(567,.75,24),Vector3(582,.75,8)
]

func _ready() -> void:
	terrain = $TERRAIN
	decor = $DECOR
	systems = SYSTEMS.new()
	systems.name = "PressureBreach"
	systems.act_number = act_number
	terrain.add_child(systems)
	for point in (ROUTE_ONE if act_number==1 else ROUTE_TWO):
		deck(point,(act_number==1 and point.x==408) or (act_number==2 and point.x in [334,357,400]))
	if act_number==1: build_act_one()
	else: build_act_two()
	build_architecture()
	batch_static_kit()
	$KeyLight.light_energy=.8
	$WorldEnvironment.environment.ambient_light_energy=.55
	place_enemies()
	$CameraRig.minimum_follow_y = -14.0
	$TERRAIN/MidpointCheckpoint.position = Vector3(317,0,0) if act_number==1 else Vector3(183,-3.4,0)
	$MARKERS/PlayerSpawn.position = Vector3(0,.905,0) if act_number==1 else Vector3(0,1.905,0)
	$Actors/RiftcoreMecha.position = $MARKERS/PlayerSpawn.position
	$Actors/RiftcoreMecha.pit_floor_y = -24
	set_meta("pit_floor_y",-24.0)
	set_meta("abyssal_layout",2)

func piece(id: String, at: Vector3, parent: Node3D = null) -> Node3D:
	if parent==null: parent=decor
	if not props.has(id): props[id] = load(KIT+id+".glb")
	var model := (props[id] as PackedScene).instantiate() as Node3D
	model.set_meta("static_abyssal",id not in ["turbine_rotor","pressure_lock_slab","pressure_wheel"])
	parent.add_child(model)
	model.position = at
	for part in model.find_children("*","GeometryInstance3D",true,false):
		part.visibility_range_end = 42
		part.visibility_range_end_margin = 6
	return model

func deck(at: Vector3, insulated := false, cavern_ledge := false) -> StaticBody3D:
	decks.append(at)
	var body := StaticBody3D.new()
	body.name = "Refuge%02d"%decks.size() if insulated else "Catwalk%02d"%decks.size()
	body.position = Vector3(at.x,at.y,0)
	body.add_to_group(&"factory_drop_through")
	if insulated: body.add_to_group(&"abyssal_insulated")
	terrain.add_child(body)
	var collider := CollisionShape3D.new()
	var slab := BoxShape3D.new()
	slab.size = Vector3(at.z,.56,3.2)
	collider.shape=slab
	collider.position.y=-.28
	body.add_child(collider)
	if cavern_ledge:
		body.add_to_group(&"factory_one_way")
		collider.name = "Collider"
		var ledge := preload("res://assets/campaign/abyssal_plant/caverns/traverse_ledge.glb").instantiate() as Node3D
		body.add_child(ledge)
		ledge.scale.x = at.z / 4.0
		ledge.set_meta("static_abyssal", true)
		body.set_meta("abyssal_deck", at)
		return body
	var tile_width:=4.0 if insulated or at.z<=6 else 8.0
	var id: String="insulated_refuge" if insulated else ("catwalk_8m" if at.z>6 else "catwalk_4m")
	for i in ceili(at.z/tile_width):
		var length:=minf(tile_width,at.z-i*tile_width)
		var model:=piece(id,Vector3(-at.z*.5+i*tile_width+length*.5,0,0),body)
		model.scale.x=length/tile_width
	body.set_meta("abyssal_deck",at)
	return body

func relay(index: int, at: Vector3, approach: Vector3) -> void:
	var marker := Marker3D.new()
	marker.name="GateRelay%d"%index
	marker.position=at
	var rooms := ["Intake catwalk", "Upper return duct"] if act_number == 1 else ["Observation loop", "Release lock catwalk"]
	marker.set_meta("landmark", rooms[index - 1])
	$MARKERS.add_child(marker)
	var entry := Marker3D.new()
	entry.name = "RelayApproach%d" % index
	entry.position = approach
	$MARKERS.add_child(entry)

func cache(at: Vector3, index: int) -> void:
	var chest := preload("res://scripts/factory_salvage_chest.gd").new()
	chest.name="PressureCache%d_%d"%[act_number,index]
	chest.position=at
	chest.sector=4
	chest.materials=5
	chest.collision_layer=0
	chest.collision_mask=1
	chest.add_to_group(&"factory_salvage_chest")
	var model := preload("res://assets/campaign/abyssal_plant/salvage_cache.glb").instantiate()
	chest.add_child(model)
	var shape := CollisionShape3D.new()
	var bounds := BoxShape3D.new()
	bounds.size=Vector3(1.5,1.5,1.5)
	shape.shape=bounds
	shape.position.y=.65
	chest.add_child(shape)
	terrain.add_child(chest)

func current(at: Vector3, height: float, width := 3.0, direction := Vector3.UP) -> Node3D:
	var jet := Node3D.new()
	jet.set_script(preload("res://scripts/abyssal_current.gd"))
	jet.position=at+direction*height*.5
	jet.dimensions=Vector3(height,width,3.2) if absf(direction.x)>.5 else Vector3(width,height,3.2)
	jet.direction=direction
	terrain.add_child(jet)
	var effect := FX.new()
	effect.dimensions=Vector3(width,height,3.2)
	effect.direction=direction
	jet.add_child(effect)
	var emitter := piece("turbine_shroud",at+Vector3(0,.25,-.3))
	emitter.scale=Vector3(.55,.25,.55)
	emitter.rotation.x=-PI*.5
	if absf(direction.x)>.5:
		emitter.rotation=Vector3(0,PI*.5,0)
		emitter.scale=Vector3.ONE*.45
	return jet

func electric(at: Vector3, span: float, offset: float) -> void:
	for x in [-span*.5,span*.5]: piece("arc_electrode",at+Vector3(x,-1.5,-.9))
	var effect := FX.new()
	effect.kind=FX.Kind.DISCHARGE
	effect.position=at
	effect.dimensions=Vector3(span,1,2)
	decor.add_child(effect)
	systems.grids.append({"at":at,"span":span,"offset":offset,"fx":effect})

func turbine(at: Vector3, offset: float) -> void:
	piece("turbine_shroud",at)
	var rotor := piece("turbine_rotor",at)
	systems.turbines.append({"at":at,"offset":offset,"rotor":rotor})

func valve(at: Vector3,index: int) -> void:
	piece("pressure_valve",at+Vector3(0,0,-1.25))
	var handwheel := piece("pressure_wheel",at+Vector3(0,1.15,-1.20))
	systems.valves.append({"at":at,"wheel":handwheel,"index":index})

func pressure_lock(at: Vector3) -> void:
	piece("pressure_lock_frame",at).rotation.y=PI*.5
	var slab := piece("pressure_lock_slab",at)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size=Vector3(.5,5.6,3.3)
	shape.shape=box
	shape.position.y=2.8
	body.position=at
	body.add_child(shape)
	terrain.add_child(body)
	slab.rotation.y=PI*.5
	systems.locks.append({"slab":slab,"body":body,"at":at})
	# A real bulkhead prevents bypassing the door above or underneath it.
	for bounds in [Vector2(-24,at.y),Vector2(at.y+5.6,37)]:
		var wall := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var solid := BoxShape3D.new()
		solid.size=Vector3(.5,bounds.y-bounds.x,3.3)
		collision.shape=solid
		wall.position=Vector3(at.x,(bounds.x+bounds.y)*.5,0)
		wall.add_child(collision)
		terrain.add_child(wall)
		var panel:=piece("pressure_lock_slab",Vector3(at.x,bounds.x,0))
		panel.rotation.y=PI*.5
		panel.scale.y=(bounds.y-bounds.x)/5.6

func climb_wall(x: float, bottom: float, top: float) -> void:
	var body:=StaticBody3D.new()
	var collider:=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=Vector3(.45,top-bottom,3.6)
	collider.shape=shape
	body.position=Vector3(x,(bottom+top)*.5,0)
	body.add_child(collider)
	terrain.add_child(body)
	var skin:=piece("pressure_lock_slab",Vector3(x,bottom,0))
	skin.rotation.y=PI*.5
	skin.scale.y=(top-bottom)/5.6

func turbine_chamber(at: Vector3, profile: PackedVector2Array, label: String) -> void:
	var shell := preload("res://scripts/cavern_envelope.gd").new()
	shell.name = label
	shell.position = at
	shell.ceiling = profile
	shell.lower_edge = -10
	shell.rock = preload("res://assets/campaign/abyssal_plant/surfaces/sector_wall.jpg")
	decor.add_child(shell)
	var rotor := preload("res://assets/campaign/abyssal_plant/caverns/chamber_landmark.glb").instantiate() as Node3D
	rotor.position = at + Vector3(12, 3, -2.85)
	rotor.set_meta("static_abyssal", true)
	decor.add_child(rotor)

func build_act_one() -> void:
	# The intake bell feeds a reverse overhang above the rising inlet route.
	for refuge in [Vector3(139.1,8.65,4.0), Vector3(131.4,10.75,4), Vector3(123.6,12.55,4.5), Vector3(114,12.55,6)]:
		deck(refuge, true, true)
	turbine_chamber(Vector3(103,4,0), PackedVector2Array([Vector2(0,11),Vector2(6,13),Vector2(17,15),Vector2(25,12),Vector2(35,11)]), "IntakeBell")
	cache(Vector3(113,12.55,0), 6)
	current(Vector3(24,0,0),9)
	current(Vector3(340,-5,0),13)
	# Optional high return circuit; it heads left over the outgoing lower route.
	for at in [Vector3(254,13.2,5),Vector3(244,15.4,6),Vector3(232,17.6,8),Vector3(219,17.6,8),Vector3(206,17.6,8)]: deck(at,true)
	cache(Vector3(205,17.6,0),1)
	for at in [Vector3(506.75,6,5),Vector3(497,8.2,5),Vector3(486,10.4,7),Vector3(473,12.6,9),Vector3(460,14.8,8)]: deck(at,true)
	relay(1,Vector3(130,6.6,0),Vector3(87,0,0))
	relay(2,Vector3(459,14.8,0),Vector3(514,1.6,0))
	cache(Vector3(75,11.4,0),2)
	cache(Vector3(393,3.8,0),3)
	turbine(Vector3(152,4.8,0),.0)
	turbine(Vector3(278,8.35,0),1.6)
	electric(Vector3(181,1.4,0),7,0)
	electric(Vector3(409,5.2,0),8,3.4)
	deck(Vector3(175,2.2,3.5),true)
	systems.entry_x=176
	systems.exit_x=440
	# A dry inspection loop climbs left above the turbine outlet, then returns to the gate.
	for shelf in [Vector3(548,2.95,4),Vector3(540,5.05,5),Vector3(532,6.9,5),Vector3(523,5.1,4)]:
		deck(shelf, true, true)
	cache(Vector3(532,6.9,0),7)
	# The intake fight has a low insulated bank and one high shelf fed by a vertical jet.
	for shelf in [Vector3(589,3.05,6),Vector3(601,5.25,5),Vector3(616,3.55,8)]:
		deck(shelf,true,true).add_to_group(&"arena_player_deck")
	current(Vector3(596,.6,0),6.2,2.8)

func build_act_two() -> void:
	# Drop through the gallery to a recessed bypass; the exhaust returns the player to the next deck.
	for shelf in [Vector3(518,-2.0,5), Vector3(524,-3.4,4.6), Vector3(532,-3.9,6), Vector3(540,-2.4,4.6)]:
		deck(shelf, true, true)
	turbine_chamber(Vector3(511,.75,0), PackedVector2Array([Vector2(0,7.5),Vector2(7,8.8),Vector2(14,7.4),Vector2(27,7),Vector2(33,8.7)]), "ExhaustBypass")
	cache(Vector3(532,-3.9,0), 6)
	# A flooded S-route: dive under the hanging baffle, rise over the second,
	# then swim onto a dry landing. There are no walkable stepping stones here.
	var water:=preload("res://scripts/abyssal_water.gd").new()
	water.name="FloodedConduit"
	water.position=Vector3(141,-2.1,0)
	terrain.add_child(water)
	deck(Vector3(141,-9,66))
	deck(Vector3(141,5.8,52))
	# Sealed machinery above the conduit prevents bypassing the swim by running
	# over its roof. The solid upper hull is visible and cannot be wall-kicked.
	var roof:=StaticBody3D.new()
	roof.name="Blocker"
	roof.position=Vector3(141,20.24,0)
	var roof_collision:=CollisionShape3D.new()
	var roof_shape:=BoxShape3D.new()
	roof_shape.size=Vector3(52,30,3.6)
	roof_collision.shape=roof_shape
	roof.add_child(roof_collision)
	terrain.add_child(roof)
	for x in 8:
		for y in 5:
			var panel:=piece("bulkhead_panel",Vector3(118.25+x*6.5,5.8+y*6.0,.3))
			panel.scale=Vector3(6.5/7.0,6.0/6.6,1)
	climb_wall(126,-2.5,5.8)
	climb_wall(149,-9,-1.6)
	climb_wall(174,-9,-3.4)
	# The upper observation loop carries relay A back to the left, away from progress.
	for at in [Vector3(80,12,5),Vector3(70,14.2,8),Vector3(56,16.4,10),Vector3(42,16.4,8),Vector3(28,16.4,8),Vector3(16,16.4,8)]: deck(at,true)
	relay(1,Vector3(16,16.4,0),Vector3(84,7.6,0))
	cache(Vector3(45,16.4,0),1)
	# Three different valve approaches: lift / submerged descent / reverse upper route.
	current(Vector3(211,1,0),12)
	deck(Vector3(220,12,8),true)
	deck(Vector3(232,12,6),true)
	valve(Vector3(222,12,0),0)
	for at in [Vector3(291,-3.4,6),Vector3(305,-5.6,8),Vector3(318,-5.6,8)]: deck(at,true)
	valve(Vector3(317,-5.6,0),1)
	current(Vector3(323,-5.6,0),10)
	# Maintenance wall-kick chimney: current reaches the first wall, not the reward.
	# The 5.55m inner width fits the real wall-kick arc; there is no low crossbar.
	climb_wall(327,1.2,12)
	climb_wall(321,6,12)
	cache(Vector3(334,12,0),4)
	current(Vector3(389,2.4,0),16)
	for at in [Vector3(401,17,8),Vector3(414,17,8),Vector3(427,17,8)]: deck(at,true)
	valve(Vector3(426,17,0),2)
	# Valve A reverses a real side current toward the harder upper cache route.
	var duct:=current(Vector3(236,14,0),14,4,Vector3.RIGHT)
	duct.speed=16.0
	duct.direction=Vector3.LEFT
	systems.redirects.append({"valve":0,"jet":duct,"fx":duct.get_child(0)})
	deck(Vector3(246,14.2,10),true)
	cache(Vector3(246,14.2,0),5)
	# Final release lock remains open for the whole squad once all three valves vent.
	pressure_lock(Vector3(439,7.6,0))
	systems.entry_x=176
	systems.exit_x=439
	for at in [Vector3(500,3.2,4),Vector3(490,5.4,5),Vector3(480,7.6,5),Vector3(468,9.8,9)]: deck(at,true)
	relay(2,Vector3(467,9.8,0),Vector3(508,.75,0))
	cache(Vector3(306,-5.6,0),2)
	cache(Vector3(414,17,0),3)
	turbine(Vector3(237,6.8,0),0)
	turbine(Vector3(366,2.8,0),2.4)
	electric(Vector3(282,6.9,0),8,1)
	electric(Vector3(357,.2,0),8,4.2)
	electric(Vector3(408,5.3,0),5,2.5)
	deck(Vector3(274,8.8,4),true)
	current(Vector3(540,-2.4,0), 5.5, 2.5)
	# Carry the exhaust bypass up through the floor, then make a return jump to its inspection pocket.
	for shelf in [Vector3(547,3.25,4),Vector3(555,4.9,5),Vector3(564,6.15,5.5),Vector3(572,3.45,4)]:
		deck(shelf,true,true)
	cache(Vector3(564,6.15,0),7)
	# The dry lock has opposing balconies. Cross the central jet high or duck underneath the balconies.
	for shelf in [Vector3(596,3.15,4.5),Vector3(604,5.25,5),Vector3(620,7.0,7),Vector3(627,4.3,4.5)]:
		deck(shelf,true,true).add_to_group(&"arena_player_deck")
	current(Vector3(613,.75,0),8.6,3.4)
	# Grounding decks stop electricity: their amber ceramic lip is the safe cue.

func build_architecture() -> void:
	# Large rooms retain distinct elevations; no low ceiling over jumps.
	var bays := [[-8,78,-8,26],[78,173,-12,24],[173,263,-12,30],[263,345,-14,26],[345,440,-12,32],[440,580,-9,29],[580,640,-5,25]]
	for bay in bays:
		var span: float=bay[1]-bay[0]
		for i in ceili(span/7.0):
			var x: float=bay[0]+3.5+i*7
			var row:=0
			for y in [float(bay[2]),float(bay[2])+6.6,float(bay[2])+13.2,float(bay[2])+19.8,float(bay[2])+26.4]:
				var window := (i%4 in [1,2]) and row in [2,3]
				piece("observation_frame" if window else "bulkhead_panel",Vector3(x,y,-4.6))
				row+=1
		var ocean := MeshInstance3D.new()
		var glass := PlaneMesh.new()
		glass.size=Vector2(span,float(bay[3]-bay[2])+12)
		ocean.mesh=glass
		ocean.rotation.x=PI*.5
		ocean.position=Vector3((bay[0]+bay[1])*.5,(bay[2]+bay[3])*.5,-5.05)
		var sea := ShaderMaterial.new()
		sea.shader=preload("res://assets/campaign/abyssal_plant/kit/sea.gdshader")
		ocean.material_override=sea
		decor.add_child(ocean)
		var pool := FX.new()
		pool.kind=FX.Kind.POOL
		pool.position=Vector3((bay[0]+bay[1])*.5,bay[2]+.4,0)
		pool.dimensions=Vector3(span,1,4.0)
		decor.add_child(pool)
		# The actual licensed pipe kit sits behind the walk lane, with shared materials.
		for x in [float(bay[0])+4,float(bay[1])-5]:
			var pipes := piece("industrial_pipes",Vector3(x,2,-3.8))
			pipes.scale=Vector3(3,3,3)
		var leak := FX.new()
		leak.kind=FX.Kind.LEAK
		leak.dimensions=Vector3(.38,5,.4)
		leak.direction=Vector3.DOWN
		leak.position=Vector3(bay[0]+8,16,-3.0)
		decor.add_child(leak)
	# Seal the service-room lane and the two outer level boundaries.
	deck(Vector3(-8,0,2) if act_number==1 else Vector3(-8,1,2))
	var left := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var bounds := BoxShape3D.new()
	bounds.size=Vector3(1,55,4)
	shape.shape=bounds
	left.position=Vector3(-9.5,5,0)
	left.add_child(shape)
	terrain.add_child(left)

func place_enemies() -> void:
	var index:=0
	var positions: Array=[6,87,131,181,257,317,393,423,472,549] if act_number==1 else [28,56,84,198,268,309,373,401,461,524]
	var landings:=decks.filter(func(p: Vector3):return roundi(p.x) in positions and p.z>=8)
	for actor in $Actors.get_children():
		if not actor is WalkerBot: continue
		# Spread encounters over wide landings, never on a current exit or thin jump.
		var p: Vector3=landings[index%landings.size()]
		actor.position=Vector3(p.x+(1.8 if index>=landings.size() else -1.8),p.y+.95,0)
		actor.patrol_left_limit=p.x-p.z*.5+.65
		actor.patrol_right_limit=p.x+p.z*.5-.65
		index+=1

func batch_static_kit() -> void:
	# Spatial cells retain offscreen culling. MultiMesh shares the source geometry
	# rather than duplicating the high-detail kit across the entire campaign map.
	var batches:={}
	for model in find_children("*","Node3D",true,false):
		if not model.get_meta("static_abyssal",false): continue
		var cell:=floori(model.global_position.x/24.0)
		var origin:=Vector3(cell*24.0+12.0,0,0)
		for part in model.find_children("*","MeshInstance3D",true,false):
			if not part.mesh: continue
			var finish: Material=part.material_override
			var key: String="%d_%d_%d"%[cell,part.mesh.get_rid().get_id(),finish.get_rid().get_id() if finish else 0]
			if not batches.has(key):
				batches[key]={"mesh":part.mesh,"material":finish,"origin":origin,"transforms":[]}
			var transform: Transform3D=Transform3D(Basis.IDENTITY,-origin)*part.global_transform
			batches[key].transforms.append(transform)
		model.hide()
		model.queue_free()
	for key in batches:
		var batch: Dictionary=batches[key]
		var instances:=MultiMesh.new()
		instances.transform_format=MultiMesh.TRANSFORM_3D
		instances.mesh=batch.mesh
		instances.instance_count=batch.transforms.size()
		for i in batch.transforms.size(): instances.set_instance_transform(i,batch.transforms[i])
		var art:=MultiMeshInstance3D.new()
		art.name="AbyssalKit_"+key
		art.multimesh=instances
		art.material_override=batch.material
		art.position=batch.origin
		art.visibility_range_end=52
		art.visibility_range_end_margin=5
		decor.add_child(art)
