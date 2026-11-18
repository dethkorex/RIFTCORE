extends StaticBody3D

signal uprooted

const BARK := preload("res://assets/machine_jungle/tread.tres")
const JADE := preload("res://assets/machine_jungle/jade.tres")
const BLOOM := Color("86ff9b")
const FX := preload("res://scripts/jungle_boss_fx.gd")
const TETHER_SHADER := preload("res://assets/machine_jungle/terrain/seed_tether.gdshader")

var armor_owner: Node3D
var dormant := true
var durability := 0
var tether: MeshInstance3D
var shell: MeshInstance3D
var heart: MeshInstance3D
var prompt: Label3D

func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	var shape := SphereShape3D.new()
	shape.radius = 0.58
	var collider := CollisionShape3D.new()
	collider.shape = shape
	add_child(collider)
	var bud := RiftProjectile.cached_mesh("Orb")
	shell = RiftProjectile.part(self, bud, JADE, Vector3.ZERO, Vector3(.50, .65, .43))
	var lamp := RiftProjectile.light_paint(BLOOM, 1.45)
	heart = RiftProjectile.part(self, bud, lamp, Vector3(0, .11, .42), Vector3(.19, .30, .12))
	for angle in [-2.1, -0.75, 0.75, 2.1]:
		var husk := RiftProjectile.part(self, bud, BARK, Vector3(sin(angle) * .37, -.24, cos(angle) * .43), Vector3(.19, .42, .20))
		husk.rotation.z = -angle * 0.26
	var flow := ShaderMaterial.new()
	flow.shader = TETHER_SHADER
	var ribbon := QuadMesh.new()
	ribbon.size = Vector2.ONE
	tether = RiftProjectile.part(self, ribbon, flow, Vector3.ZERO, Vector3.ONE)
	prompt = Label3D.new()
	prompt.font = preload("res://assets/ui/fonts/BarlowCondensed-ExtraBoldItalic.ttf")
	prompt.font_size = 49
	prompt.pixel_size = .0049
	prompt.outline_size = 12
	prompt.modulate = BLOOM.lightened(.28)
	prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prompt.position = Vector3(0, .88, .42)
	prompt.text = "SHOOT SEED ANCHOR"
	add_child(prompt)
	hide()
	set_process(false)

func present(at: Vector3, health: int, authority: bool) -> void:
	var previous := durability
	global_position = at
	dormant = health <= 0
	durability = health
	set_deferred("collision_layer", 2 if not dormant and authority else 0)
	visible = not dormant
	set_process(not dormant)
	if not dormant:
		prompt.text = "SEED ANCHOR  %d" % durability
	if previous != health:
		FX.burst(armor_owner, at + Vector3.BACK * .38, BLOOM, .85 if dormant else .52, 15 if dormant else 7, previous == 0)

func _process(_delta: float) -> void:
	if not is_instance_valid(armor_owner):
		return
	var origin := to_local(armor_owner.global_position + Vector3(0, .39, .64))
	var flat := Vector3(origin.x, origin.y, 0)
	tether.position = flat * .5 + Vector3(0, 0, .57)
	tether.rotation.z = atan2(flat.y, flat.x)
	tether.scale = Vector3(maxf(.05, flat.length()), .31, 1.0)
	shell.scale.y = .65 + sin(Time.get_ticks_msec() * .007) * .05
	heart.scale.y = .29 + sin(Time.get_ticks_msec() * .010) * .04

func hit_by_projectile(shot: RiftProjectile) -> bool:
	if dormant or shot.owner_faction != "player" or shot.launch_profile == -2:
		return false
	present(global_position, maxi(0, durability - (2 if shot.is_charged else 1)), true)
	if dormant:
		RiftAudio.play_effect(&"enemy_break")
		uprooted.emit()
	return true
