extends Area3D

const VFX := preload("res://scripts/factory_trap_vfx.gd")

@export var laser := false
@export var phase_offset := 0.0
var clock := 0.0
var hit := false
var hazard: Node3D
var was_active := false
var rotor: Node3D

func _ready() -> void:
	collision_layer = 0
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.65, 2.4, 1.3) if laser else Vector3(1.3, 0.72, 1.35)
	collider.shape = box
	collider.position.y = box.size.y * 0.5
	add_child(collider)
	hazard = VFX.make_laser() if laser else VFX.make_spikes()
	add_child(hazard)
	rotor = hazard.find_child("DrillRotor", true, false) as Node3D
	hazard.hide()
	clock = phase_offset

func _physics_process(delta: float) -> void:
	clock = fposmod(clock + delta, 3.6)
	var active := clock >= 2.6 and clock < 3.25
	hazard.visible = active
	if active and rotor:
		rotor.rotate_z(delta * 30.0)
	if active and not was_active:
		if not laser:
			hazard.scale.y = 0.12
			var rise := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			rise.tween_property(hazard, "scale:y", 1.0, 0.085)
		VFX.throw_sparks(self, VFX.PINK if laser else VFX.EMBER, 1.0)
	was_active = active
	if not active:
		hit = false
	elif not hit:
		for body in get_overlapping_bodies():
			if body is RiftPlayer and body.health > 0.0:
				body.take_projectile_damage(14.0)
				hit = true
				break
