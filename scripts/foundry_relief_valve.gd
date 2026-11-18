extends StaticBody3D

signal released

const READY_TINT := Color("65e9ff")
var show_prompt := false
var prompt: Label3D
var ready_to_shoot := false
var lamp: MeshInstance3D
var wheel: MeshInstance3D

func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = Vector3(.82, 1.72, 1.86) if show_prompt else Vector3(.55, .74, .72)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	if show_prompt:
		collider.position.y = -0.09
	add_child(collider)
	var steel := RiftProjectile.light_paint(Color("3d2731"), 0.0)
	var panel := Node3D.new()
	panel.position.z = -1.15
	add_child(panel)
	var frame := BoxMesh.new()
	RiftProjectile.part(panel, frame, steel, Vector3(-.06, -.45, -.27), Vector3(.65, 1.65, .36))
	var ring := TorusMesh.new()
	ring.inner_radius = .24
	ring.outer_radius = .37
	wheel = RiftProjectile.part(panel, ring, steel, Vector3.ZERO, Vector3.ONE)
	wheel.rotation.x = PI * .5
	lamp = RiftProjectile.part(panel, RiftProjectile.cached_mesh("Orb"), steel, Vector3(0, 0, .16), Vector3.ONE * .26)

	if show_prompt:
		prompt = Label3D.new()
		prompt.text = "PURGE VALVE"
		prompt.font = preload("res://assets/ui/fonts/BarlowCondensed-ExtraBoldItalic.ttf")
		prompt.font_size = 60
		prompt.pixel_size = 0.0051
		prompt.modulate = Color("a1b5c4")
		prompt.outline_size = 14
		prompt.outline_modulate = Color("060e18")
		prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		prompt.position = Vector3(0, 0.88, 0.13)
		panel.add_child(prompt)

func present_vent(enabled: bool, authority: bool) -> void:
	if enabled == ready_to_shoot:
		return
	ready_to_shoot = enabled
	set_deferred("collision_layer", 2 if enabled and authority else 0)
	show_target(enabled)

func show_target(enabled: bool) -> void:
	var paint := RiftProjectile.light_paint(READY_TINT if enabled else Color("483845"), 1.60 if enabled else .08)
	if prompt:
		prompt.text = "▼  SHOOT VALVE" if enabled else "PURGE VALVE"
		prompt.modulate = Color("b6f9ff") if enabled else Color("a1b5c4")
	wheel.material_override = paint
	lamp.material_override = paint

func hit_by_projectile(shot: RiftProjectile) -> bool:
	if not ready_to_shoot or shot.owner_faction != "player":
		return false
	present_vent(false, true)
	released.emit()
	return true
