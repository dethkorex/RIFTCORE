extends Area3D

signal taken

enum Kind { HEALTH, ENERGY, CREDITS, LIFE = 4 }
const TINTS := [Color("54ff96"), Color("369eff"), Color("ffce50"), Color("bf72ff"), Color("6dffdd")]
const COMBAT_VFX := preload("res://scripts/combat_vfx.gd")

@export var kind: Kind
@export var large := false
@export var expires := false
@export var full_heal := false
var consumed := false
var claimant: RiftPlayer
var replica := false
var local_copy := true

func _ready() -> void:
	collision_layer = 0
	collision_mask = 0 if replica else 1
	visible = local_copy
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.72 if large else 0.6
	shape.shape = sphere
	add_child(shape)
	var visual := get_node_or_null("Visual") as Node3D
	if visual:
		if large and kind != Kind.LIFE:
			visual.scale *= 1.28
		add_halo(visual)
		var bob := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		bob.tween_property(visual, "position:y", 0.13, 0.65)
		bob.tween_property(visual, "position:y", 0.0, 0.65)
	body_entered.connect(_collect)
	if expires:
		get_tree().create_timer(25.0, false).timeout.connect(queue_free)

func add_halo(visual: Node3D) -> void:
	var halo := MeshInstance3D.new()
	var quad := QuadMesh.new()
	var radius := 1.18 if large else 0.94
	quad.size = Vector2.ONE * radius
	halo.mesh = quad
	halo.position.z = -0.06
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/pickups/pickup_halo.gdshader")
	material.set_shader_parameter("tint", TINTS[kind])
	halo.material_override = material
	visual.add_child(halo)

func _collect(body: Node3D) -> void:
	var player := body as RiftPlayer
	if consumed or replica or player == null or player.health <= 0.0 or (is_instance_valid(claimant) and player != claimant):
		return
	if kind == Kind.HEALTH and player.health >= player.max_health:
		return
	if kind == Kind.ENERGY and player.energy >= player.max_energy:
		return
	if kind == Kind.LIFE and player.lives >= 5:
		return
	consumed = true
	taken.emit()
	if local_copy:
		RiftAudio.play_effect(&"pickup")
		collect_fx.call_deferred()
	match kind:
		Kind.HEALTH:
			player.restore_health(player.max_health if full_heal else (50.0 if large else 25.0) * player.healing_pickup_multiplier, true)
		Kind.ENERGY:
			player.restore_energy(60.0 if large else 30.0, true)
		Kind.CREDITS:
			player.credits += roundi((30.0 if large else 10.0) * player.salvage_multiplier)
			player.credits_changed.emit(player.credits)
		Kind.LIFE:
			player.add_life()
	queue_free()

func collect_fx() -> void:
	var flash := Node3D.new()
	get_parent().add_child(flash)
	flash.global_position = global_position
	COMBAT_VFX.hit(flash, TINTS[kind], 0.72 if large else 0.49)
	get_tree().create_timer(0.23, false).timeout.connect(flash.queue_free)
