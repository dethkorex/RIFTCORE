@tool
extends Area3D

const CHAMFER := preload("res://scripts/factory_chamfer.gd")

@export var width := 5.4
@export var tint := Color("ff9c45")

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	var hurt_box := BoxShape3D.new()
	hurt_box.size = Vector3(width - 0.12, 0.98, 3.4)
	var hazard := CollisionShape3D.new()
	hazard.shape = hurt_box
	hazard.position.y = 0.16
	add_child(hazard)
	if not Engine.is_editor_hint():
		body_entered.connect(impale)

	var steel := RiftProjectile.light_paint(Color("405875"), 0.0)
	steel.metallic = 0.62
	steel.roughness = 0.42
	var sockets := RiftProjectile.light_paint(Color("18263b"), 0.0)
	var marker := RiftProjectile.light_paint(tint, 2.3)
	var tooth := CylinderMesh.new()
	tooth.radial_segments = 4
	tooth.rings = 0
	tooth.top_radius = 0.018
	tooth.bottom_radius = 0.36
	tooth.height = 1.02
	var columns := ceili(width / 0.72)
	var pitch := width / columns
	for i in columns:
		var x := (i+0.5)*pitch-width*0.5
		for z in [-0.75, 0.02, 0.79]:
			var blade := RiftProjectile.part(self, tooth, steel, Vector3(x,0.11,z), Vector3.ONE)
			blade.rotation.y = PI * 0.25
		rail(Vector3(x,-0.323,0),Vector3(pitch * 0.88,0.16,2.7),sockets)
		rail(Vector3(x,-0.31,1.38),Vector3(pitch * 0.72,0.09,0.09),marker)
	rail(Vector3(0,-0.52,0),Vector3(width,0.35,3.05),steel)
	for side in [-1, 1]:
		rail(Vector3(side * width * 0.39,-0.72,-1.37),Vector3(0.52,0.62,2.4),sockets)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0,0.78,0.65)
	lamp.light_color = tint
	lamp.light_energy = 1.55
	lamp.omni_range = width * 0.64
	add_child(lamp)

func rail(at: Vector3, dimensions: Vector3, material: Material) -> void:
	var box := BoxMesh.new()
	box.size = dimensions
	RiftProjectile.part(self, CHAMFER.from_box(box, 0.055), material, at, Vector3.ONE)

func impale(player: Node3D) -> void:
	if player is RiftPlayer and not player.local_prediction:
		player.die_in_pit()
