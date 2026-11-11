extends Area3D

const CHAMFER := preload("res://scripts/factory_chamfer.gd")

enum Kind { HEALTH, ENERGY, CREDITS, XP, LIFE }

@export var kind: Kind
@export var large := false
@export var expires := false
@export var full_heal := false
@export var xp_amount := 0
var consumed := false

func _ready() -> void:
	collision_layer = 0
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.72 if large else 0.6
	shape.shape = sphere
	add_child(shape)
	var visual := get_node_or_null("Visual") as Node3D
	if visual:
		add_halo(visual)
		refine_case(visual)
		var bob := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		bob.tween_property(visual, "position:y", 0.13, 0.65)
		bob.tween_property(visual, "position:y", 0.0, 0.65)
	body_entered.connect(_collect)
	if expires:
		get_tree().create_timer(25.0, false).timeout.connect(queue_free)

func add_halo(visual: Node3D) -> void:
	var halo := MeshInstance3D.new()
	var quad := QuadMesh.new()
	var radius := 1.18 if large else (0.65 if kind == Kind.XP else 0.94)
	quad.size = Vector2.ONE * radius
	halo.mesh = quad
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/pickups/pickup_halo.gdshader")
	material.set_shader_parameter("tint", [Color("54ff96"), Color("30dfff"), Color("ffce50"), Color("be80ff"), Color("6dffdd")][kind])
	halo.material_override = material
	visual.add_child(halo)

func refine_case(visual: Node3D) -> void:
	if kind == Kind.HEALTH or kind == Kind.ENERGY:
		for name in ["Cell", "Bottom", "Top"]:
			var piece := visual.get_node_or_null(name) as MeshInstance3D
			if not piece or not piece.mesh is BoxMesh:
				continue
			var box := piece.mesh as BoxMesh
			piece.material_override = box.material
			piece.mesh = CHAMFER.from_box(box, 0.036)
		var tint := Color("54ff96") if kind == Kind.HEALTH else Color("30dfff")
		var accent := BoxMesh.new()
		accent.size = Vector3(0.034, 0.23, 0.022)
		for side in [-1.0, 1.0]:
			RiftProjectile.part(visual, accent, RiftProjectile.light_paint(tint, 0.85), Vector3(side * 0.152, 0, 0.146), Vector3.ONE)
	elif kind == Kind.CREDITS:
		var case := RiftProjectile.light_paint(Color("956129"), 0.21)
		for coin in visual.get_children():
			if coin is MeshInstance3D and coin.mesh is CylinderMesh:
				coin.material_override = case
				var rim := RiftProjectile.part(visual, RiftProjectile.cached_mesh("Ring"), RiftProjectile.light_paint(Color("ffca55"), 0.8), coin.position + Vector3.UP * 0.046, Vector3(0.40, 0.29, 0.40))
				rim.rotation.y = 0.25

func _collect(body: Node3D) -> void:
	var player := body as RiftPlayer
	if consumed or player == null or player.health <= 0.0:
		return
	if kind == Kind.HEALTH and player.health >= player.max_health:
		return
	if kind == Kind.ENERGY and player.energy >= player.max_energy:
		return
	if kind == Kind.LIFE and player.lives >= 5:
		return
	consumed = true
	RiftAudio.play_effect(&"pickup")
	match kind:
		Kind.HEALTH:
			player.health = player.max_health if full_heal else minf(player.max_health, player.health + (50.0 if large else 25.0))
			player.health_changed.emit(player.health, player.max_health)
		Kind.ENERGY:
			player.restore_energy(60.0 if large else 30.0)
		Kind.CREDITS:
			player.credits += 30 if large else 10
			player.credits_changed.emit(player.credits)
		Kind.XP:
			player.gain_experience(xp_amount if xp_amount > 0 else (50 if large else 10))
		Kind.LIFE:
			player.add_life()
	queue_free()
