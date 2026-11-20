@tool
extends Node3D

enum Piece {
	ICE_PLATFORM, GRIP_PLATFORM, ICICLES, COOLANT_PUMP, ROCKET_BOARD, JUMP_PAD, SPIKE_GATE,
	SPIKE_RACK, GAP_BEACON,
}

const ICE := preload("res://assets/campaign/frozen_reactor/kit/ice.tres")
const SNOW := preload("res://assets/campaign/frozen_reactor/kit/snow.tres")
const CHAMFER := preload("res://scripts/factory_chamfer.gd")
const GATE_WIDTH := 3.2
const GATE_CLEARANCE := 1.94
const GATE_TOP := 5.35
const RACK_HEIGHT := 1.02
@export var piece: Piece
@export var width := 5.0
@export var drop_through := true
var metal: StandardMaterial3D
var ceramic: StandardMaterial3D
var light: StandardMaterial3D
var nozzle: Node3D

func _ready() -> void:
	metal = paint(Color("172c42"), .65)
	ceramic = paint(Color("96b7c7"), .36)
	light = paint(Color("7de6ff"), .25, .65)
	match piece:
		Piece.ICE_PLATFORM, Piece.GRIP_PLATFORM:
			box(self, Vector3(0,-.30,0), Vector3(width,.60,3.2), metal)
			box(self, Vector3(0,-.035,0), Vector3(width-.05,.12,3.14), ICE if piece == Piece.ICE_PLATFORM else ceramic)
			for i in maxi(2,roundi(width/.65)):
				var x := (float(i) + .5) * .65 - width*.5
				box(self, Vector3(x,-.32,1.62), Vector3(.22,.18,.09), light)
				if piece == Piece.GRIP_PLATFORM:
					box(self, Vector3(x,.035,0), Vector3(.12,.045,2.90), metal)
			var body := StaticBody3D.new()
			body.name = "DeckCollider"
			if piece == Piece.ICE_PLATFORM:
				body.add_to_group(&"ice_deck")
			if drop_through:
				body.add_to_group(&"factory_drop_through")
			add_child(body)
			collider(body, Vector3(0,-.30,0), Vector3(width,.60,3.2))
		Piece.ICICLES:
			for i in 7:
				var icicle := CylinderMesh.new()
				icicle.top_radius = .13 + float(i % 3)*.045
				icicle.bottom_radius = .008
				icicle.height = .60 + float(i % 4)*.29
				icicle.radial_segments = 10
				mesh(self, icicle, ICE, Vector3((i-3)*.30,-icicle.height*.5,.13*sin(i*1.9)))
		Piece.COOLANT_PUMP:
			box(self, Vector3(0,.22,0), Vector3(2.0,.44,1.0), metal)
			for side in [-1,1]:
				var cylinder := CylinderMesh.new()
				cylinder.top_radius = .30
				cylinder.bottom_radius = .30
				cylinder.height = 1.4
				cylinder.radial_segments = 24
				mesh(self,cylinder,light,Vector3(side*.49,1.12,0))
				for y in [.48,1.77]:
					box(self,Vector3(side*.49,y,0),Vector3(.80,.19,.85),ceramic)
				box(self,Vector3(side*.49,1.10,.34),Vector3(.13,1.0,.15),metal)
			box(self,Vector3(0,.99,.17),Vector3(.45,.65,.48),metal)
		Piece.ROCKET_BOARD:
			mesh(self,board_hull(),metal,Vector3.ZERO)
			for x in [-.91,.89]:
				box(self,Vector3(x,.085,0),Vector3(.49,.075,.56),ceramic)
			box(self,Vector3(.02,.085,0),Vector3(.56,.04,.61),metal)
			for x in [-.43,.43]:
				box(self,Vector3(x,.11,0),Vector3(.33,.045,.55),paint(Color("101e2b"),.1))
				for ridge in 4:
					box(self,Vector3(x+(ridge-1.5)*.065,.139,0),Vector3(.025,.014,.46),metal)
			for i in 20:
				var a := i*TAU/20.0
				var b := (i+1)*TAU/20.0
				var start := Vector3(cos(a)*1.28,.025,sin(a)*(.35+.1*maxf(0,-cos(a))))
				var end := Vector3(cos(b)*1.28,.025,sin(b)*(.35+.1*maxf(0,-cos(b))))
				var edge := box(self,(start+end)*.5,Vector3(start.distance_to(end)+.015,.032,.035),light)
				edge.rotation.y = -atan2(end.z-start.z,end.x-start.x)
			for side in [-1,1]:
				box(self,Vector3(-.69,-.065,side*.32),Vector3(.54,.18,.19),ceramic)
				box(self,Vector3(.58,.025,side*.28),Vector3(.75,.045,.035),light)
				var pod := CylinderMesh.new()
				pod.top_radius = .14
				pod.bottom_radius = .17
				pod.height = .67
				pod.radial_segments = 24
				var engine := mesh(self,pod,metal,Vector3(-.65,-.10,side*.40))
				engine.rotation.z = PI*.5
				var ring := TorusMesh.new()
				ring.inner_radius = .10
				ring.outer_radius = .15
				ring.rings = 20
				ring.ring_segments = 8
				var exhaust := mesh(self,ring,light,Vector3(-1.0,-.10,side*.40))
				exhaust.rotation.z = PI*.5
				var fin := box(self,Vector3(-.54,.03,side*.49),Vector3(.72,.10,.11),ceramic)
				fin.rotation.y = side*.24
			var nose := box(self,Vector3(1.12,.035,0),Vector3(.42,.10,.45),ceramic)
			nose.rotation.z = .22
			box(self,Vector3(1.25,.10,0),Vector3(.06,.04,.25),light)
			nozzle = Node3D.new()
			add_child(nozzle)
			for side in [-1,1]:
				var jet := SphereMesh.new()
				jet.radius = .11
				jet.height = .22
				var flame := mesh(nozzle,jet,light,Vector3(-1.18,-.055,side*.32))
				flame.scale = Vector3(3.5,.65,.65)
		Piece.JUMP_PAD:
			box(self, Vector3(0, .075, 0), Vector3(3.1, .15, 3.2), metal)
			box(self, Vector3(0, .095, 0), Vector3(2.9, .15, 2.66), ceramic)
			for x in [-.90, 0.0, .90]:
				for side in [-1, 1]:
					var chevron := box(self, Vector3(x, .18, side * .46), Vector3(1.11, .04, .13), light)
					chevron.rotation.y = side * .65
					box(self, Vector3(x, .09, side * 1.59), Vector3(.48, .11, .12), light)
		Piece.SPIKE_GATE:
			build_pressure_gate()
		Piece.SPIKE_RACK:
			build_spike_rack()
		Piece.GAP_BEACON:
			build_gap_beacon()

func build_pressure_gate() -> void:
	var caution := paint(Color("ff994d"), .36, .42)
	var socket := paint(Color("0c1e2f"), .68)
	var underside := GATE_CLEARANCE + .62
	var frame_height := GATE_TOP - underside
	box(self, Vector3(0, 2.72, -1.92), Vector3(GATE_WIDTH, 5.44, .41), metal)
	box(self, Vector3(0, underside + frame_height * .5, 0), Vector3(GATE_WIDTH, frame_height, 3.72), metal)
	box(self, Vector3(0, underside + .13, 1.90), Vector3(GATE_WIDTH-.26, .26, .22), ceramic)
	box(self, Vector3(0, 3.62, 1.89), Vector3(2.45, 1.42, .20), socket)
	for row in 4:
		box(self, Vector3(0, 3.15 + row*.30, 2.01), Vector3(2.03, .12, .11), ceramic)
	for side in [-1, 1]:
		box(self, Vector3(side*1.34, 3.74, 1.93), Vector3(.28, 2.35, .30), ceramic)
		box(self, Vector3(side*1.34, underside + .46, 2.10), Vector3(.13, .51, .06), caution)
	var tooth := spike_mesh(.62, .15, true)
	for column in 8:
		var x := (column - 3.5) * .36
		var stripe := box(self, Vector3(x, underside + .13, 2.025), Vector3(.15, .16, .04), caution)
		stripe.rotation.z = -.42
		for z in [-1.32, 0.0, 1.32]:
			mesh(self, tooth, ceramic, Vector3(x, GATE_CLEARANCE + .31, z))

func build_spike_rack() -> void:
	var caution := paint(Color("ff9b46"), .53, .51)
	box(self, Vector3(0, .08, 0), Vector3(width, .16, 3.48), metal)
	box(self, Vector3(0, .21, 0), Vector3(width-.10, .15, 3.22), ceramic)
	var count := maxi(4, roundi(width / .45))
	var tooth := spike_mesh(RACK_HEIGHT - .23, .17, false)
	for index in count:
		var x := ((index + .5) / count - .5) * width
		for z in [-1.18, -.40, .40, 1.18]:
			mesh(self, tooth, ceramic, Vector3(x, (RACK_HEIGHT + .23)*.5, z))
		box(self, Vector3(x, .19, 1.76), Vector3(.26, .14, .09), caution)

func build_gap_beacon() -> void:
	var amber := paint(Color("ffc27a"), .25, 1.05)
	box(self, Vector3(-.29, -.15, 0), Vector3(.66, .30, 3.69), metal)
	box(self, Vector3(-.27, .024, 0), Vector3(.25, .052, 3.45), amber)
	for side in [-1, 1]:
		box(self, Vector3(-.30, -.49, side*1.72), Vector3(.42, .65, .24), ceramic)
		box(self, Vector3(-.08, -.37, side*1.73), Vector3(.054, .23, .13), amber)

func spike_mesh(height: float, radius: float, down: bool) -> CylinderMesh:
	var spike := CylinderMesh.new()
	spike.height = height
	spike.radial_segments = 6
	spike.rings = 0
	spike.top_radius = radius if down else .008
	spike.bottom_radius = .008 if down else radius
	return spike

static func paint(color: Color, metal: float, glow := 0.0) -> StandardMaterial3D:
	var surface := StandardMaterial3D.new()
	surface.albedo_color = color
	surface.metallic = metal
	surface.roughness = .38
	surface.emission_enabled = glow > 0.0
	surface.emission = color
	surface.emission_energy_multiplier = glow
	return surface

static func board_hull() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := [Vector2(-.14,.84),Vector2(-.07,1),Vector2(.045,1),Vector2(.10,.88)]
	var points: Array[Vector3] = []
	for ring in rings:
		for i in 32:
			var angle := i*TAU/32.0
			points.append(Vector3(cos(angle)*(1.4 if cos(angle)>0 else 1.23)*ring.y,ring.x,sin(angle)*(.35+.10*maxf(0,-cos(angle)))*ring.y))
	for r in 3:
		for i in 32:
			var a := r*32+i
			var b := r*32+(i+1)%32
			for index in [a,b,a+32,b,b+32,a+32]:
				surface.add_vertex(points[index])
	for i in range(1,31):
		for index in [0,i+1,i,96,96+i,96+i+1]:
			surface.add_vertex(points[index])
	surface.generate_normals()
	return surface.commit()

static func collider(parent: Node3D, at: Vector3, size: Vector3) -> CollisionShape3D:
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = at
	parent.add_child(collision)
	return collision

static func box(parent: Node3D, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var block := BoxMesh.new()
	block.size = size
	return mesh(parent,CHAMFER.from_box(block,minf(.08,minf(size.x,minf(size.y,size.z))*.22)),material,at)

static func mesh(parent: Node3D, geometry: Mesh, surface: Material, at: Vector3) -> MeshInstance3D:
	var object := MeshInstance3D.new()
	object.mesh = geometry
	object.material_override = surface
	object.position = at
	parent.add_child(object)
	return object
