@tool
extends Node3D

enum Piece { ICE_PLATFORM, GRIP_PLATFORM, ICICLES, COOLANT_PUMP, ROCKET_BOARD, JUMP_PAD, SPIKE_GATE }

const ICE := preload("res://assets/campaign/frozen_reactor/kit/ice.tres")
const SNOW := preload("res://assets/campaign/frozen_reactor/kit/snow.tres")
const CHAMFER := preload("res://scripts/factory_chamfer.gd")
@export var piece: Piece
@export var width := 5.0
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
			for x in [-.48,.37]:
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
			box(self,Vector3(0,.10,0),Vector3(2.4,.20,3.2),metal)
			for i in 4:
				var bar := box(self,Vector3((i-1.5)*.42,.23,0),Vector3(.12,.06,2.5),light)
				bar.rotation.z = .20
		Piece.SPIKE_GATE:
			box(self,Vector3(0,2.0,-1.8),Vector3(2.8,4.0,.28),metal)
			box(self,Vector3(0,4.55,0),Vector3(2.8,4.24,3.6),metal)
			for side in [-1,1]:
				box(self,Vector3(side*1.21,3.80,1.84),Vector3(.21,2.45,.14),ceramic)
			for row in 5:
				box(self,Vector3(0,2.84+row*.39,1.83),Vector3(2.2,.20,.10),paint(Color("274557"),.45))
			box(self,Vector3(0,2.40,1.85),Vector3(2.35,.16,.15),ceramic)
			for i in 6:
				var caution := box(self,Vector3((i-2.5)*.36,2.40,1.94),Vector3(.16,.12,.025),paint(Color("fcb660"),.15))
				caution.rotation.z = -.34
			for i in 8:
				var spike := CylinderMesh.new()
				spike.top_radius = .12
				spike.bottom_radius = .005
				spike.height = .28
				spike.radial_segments = 8
				mesh(self,spike,SNOW,Vector3((i-3.5)*.34,2.29,1.90))
			for side in [-1,1]:
				box(self,Vector3(side*1.24,2.5,1.84),Vector3(.13,.66,.07),paint(Color("ff9745"),.1,.7))

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
