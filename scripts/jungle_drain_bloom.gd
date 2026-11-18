extends Node3D

const JADE := preload("res://assets/machine_jungle/jade.tres")
const FX := preload("res://scripts/jungle_boss_fx.gd")
const BEACON := Color("70f7ff")

var signal_mesh: Node3D
var petals: Array[MeshInstance3D] = []
var charged_paint: Material
var ready_paint: Material
var prompt: Label3D
var shown_percent := -2

func _ready() -> void:
	var rim := TorusMesh.new()
	rim.inner_radius = 0.70
	rim.outer_radius = 0.94
	RiftProjectile.part(self, rim, JADE, Vector3.UP * .055, Vector3(1.25, .28, .94))
	signal_mesh = Node3D.new()
	add_child(signal_mesh)
	ready_paint = RiftProjectile.light_paint(BEACON.darkened(.46), .85)
	charged_paint = RiftProjectile.light_paint(FX.OPEN, 1.65)
	RiftProjectile.part(signal_mesh, rim, ready_paint, Vector3.UP * .085, Vector3(1.15, .30, .9))
	var blade := PrismMesh.new()
	for i in 8:
		var angle := TAU * float(i) / 8.0
		var petal := RiftProjectile.part(signal_mesh, blade, ready_paint,
			Vector3(sin(angle) * .93, .13, cos(angle) * .69), Vector3(.20, .24, .16))
		petal.rotation = Vector3(-.64, angle, 0)
		petals.append(petal)
	prompt = Label3D.new()
	prompt.font = preload("res://assets/ui/fonts/BarlowCondensed-ExtraBoldItalic.ttf")
	prompt.font_size = 51
	prompt.pixel_size = 0.0046
	prompt.outline_size = 12
	prompt.modulate = BEACON
	prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prompt.position = Vector3(0, 1.60, -0.37)
	add_child(prompt)
	present(false, 0.0)

func present(enabled: bool, progress: float) -> void:
	var percent := roundi(progress * 100.0) if enabled else -1
	if percent == shown_percent:
		return
	shown_percent = percent
	signal_mesh.visible = enabled
	prompt.visible = enabled
	if enabled:
		prompt.text = "STAND HERE TO DRAIN" if percent == 0 else "DRAINING  %d%%" % percent
		for i in petals.size():
			petals[i].material_override = charged_paint if percent >= (i + 1) * 100.0 / petals.size() else ready_paint

func discharge() -> void:
	FX.burst(self, global_position + Vector3.UP * .22, BEACON, 1.55, 18, true)

func occupied_by(actor: RiftPlayer) -> bool:
	return actor.health > 0.0 and actor.grounded() and absf(actor.global_position.x - global_position.x) <= 1.16 and absf(actor.global_position.y - actor.standing_capsule.height * 0.5 - global_position.y) < .37
