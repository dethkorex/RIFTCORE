extends Node3D

const Door := preload("res://scripts/campaign_door.gd")
const Fire := preload("res://addons/pyrolux_fx/nodes_3d/pyrolux_fire_3d.gd")
const LAVA_SHADER := preload("res://assets/neon_factory/foundry/rising_lava.gdshader")
const UI := preload("res://scripts/rift_ui.gd")
const REST_LEVEL := -1.55
const TOP_LEVEL := 79.95
const SHAFT_LEFT := 3.46
const SHAFT_RIGHT := 19.75
const EXIT_CLEARANCE := 20.75
const ENTRY_CLEARANCE := 1.0
const TUNNEL_CEILING := 3.16
const RISE_SPEED := 2.14
const RISE_ACCELERATION := 0.028
const MAX_RISE_SPEED := 3.12
const RISE_DELAY := 1.65
const WARNING_SECONDS := 3.6
const SURFACE_CONTACT := 0.10 # Includes the crest of the visible surface waves.
const LAVA_HALF_DEPTH := 2.29

enum Phase { READY, SEALED, RISING, DRAINING }

var authority := true
var phase := Phase.READY
var surface := REST_LEVEL
var elapsed := 0.0
var door: Door
var actors: Node
var camera_rig: SideCameraRig
var lava: MeshInstance3D
var lava_column: MeshInstance3D
var lava_light: OmniLight3D
var surface_fire: PyroluxFire3D
var surface_fire_active := false
var prompt: Label3D
var warning: Label
var party_size := 1

func _ready() -> void:
	door = Door.new($Entrance)
	door.apply(Door.MAX_LIFT, true)
	var stage := get_parent().get_parent()
	actors = stage.get_node("Actors")
	camera_rig = stage.get_node("CameraRig")
	prompt = $Prompt
	lava = make_lava(SHAFT_RIGHT)
	lava_column = make_lava(SHAFT_RIGHT - SHAFT_LEFT)
	lava_light = OmniLight3D.new()
	lava_light.light_color = Color("ff4e15")
	lava_light.light_energy = 3.4
	lava_light.omni_range = 12.0
	add_child(lava_light)
	surface_fire = Fire.new()
	surface_fire.autoplay = false
	surface_fire.fade_time = 0.26
	surface_fire.shape = PyroluxFire3D.Shape.LINE
	surface_fire.size = Vector3((SHAFT_RIGHT - SHAFT_LEFT) * 0.49, 0.10, 0.22)
	surface_fire.flame_height = 0.95
	surface_fire.flame_width = 0.74
	surface_fire.lean = 0.08
	surface_fire.tongues = 6
	surface_fire.puffs = 8
	surface_fire.embers = 22
	surface_fire.ember_height = 2.05
	surface_fire.smoke = 8
	surface_fire.smoke_height = 3.3
	surface_fire.smoke_opacity = 0.31
	surface_fire.light_enabled = false
	add_child(surface_fire)
	surface_fire.set_process(false)
	surface_fire.finished.connect(func(): surface_fire.set_process(false))
	make_warning()
	present()

func make_lava(width: float) -> MeshInstance3D:
	var slab := BoxMesh.new()
	slab.size = Vector3(width, 14.0, 4.58)
	slab.subdivide_width = 28
	slab.subdivide_depth = 12
	var molten := ShaderMaterial.new()
	molten.shader = LAVA_SHADER
	return RiftProjectile.part(self, slab, molten, Vector3.ZERO, Vector3.ONE)

func make_warning() -> void:
	var overlay := CanvasLayer.new()
	overlay.layer = 29
	add_child(overlay)
	warning = UI.hud_readout(overlay, 158.0, 400.0, Color("ff505d"), 67)
	warning.text = "WARNING\nLAVA SURGE"
	warning.add_theme_stylebox_override("normal", UI.hud_frame(Color("ff505d"), Vector2(18, 10), true))

func _physics_process(delta: float) -> void:
	if not authority:
		return
	var party := actors.get_children().filter(func(actor): return actor is RiftPlayer and actor.health > 0.0)
	party_size = party.size()
	var inside := party.filter(is_inside)
	match phase:
		Phase.READY:
			if not inside.is_empty() and party.all(past_entrance):
				elapsed = 0.0
				set_phase(Phase.SEALED)
		Phase.SEALED:
			if inside.is_empty():
				set_phase(Phase.DRAINING)
			elif not door.passable:
				elapsed += delta
				if elapsed >= RISE_DELAY:
					set_phase(Phase.RISING)
		Phase.RISING:
			elapsed += delta
			var rise_time := elapsed - RISE_DELAY
			surface = minf(TOP_LEVEL, surface + minf(MAX_RISE_SPEED, RISE_SPEED + rise_time * RISE_ACCELERATION) * delta)
			if inside.is_empty():
				set_phase(Phase.DRAINING)
		Phase.DRAINING:
			surface = move_toward(surface, REST_LEVEL, 27.0 * delta)
			if is_equal_approx(surface, REST_LEVEL):
				set_phase(Phase.READY)
	# Damage follows the rendered lava, independently of the escape-room trigger.
	# In particular, it remains lethal while draining and at the sides of the
	# player capsule, where the old centre-point room test missed contact.
	for operator: RiftPlayer in party:
		if touches_lava(operator):
			operator.die_in_pit()
	door.step(delta, phase == Phase.READY or phase == Phase.DRAINING, party)
	present()

func touches_lava(operator: RiftPlayer) -> bool:
	var at := to_local(operator.global_position)
	var radius := operator.standing_capsule.radius
	var contact_surface := surface if at.x + radius >= SHAFT_LEFT else minf(surface, TUNNEL_CEILING)
	return at.x + radius >= 0.0 and at.x - radius <= SHAFT_RIGHT \
		and absf(at.z) - radius <= LAVA_HALF_DEPTH \
		and at.y - operator.standing_capsule.height * 0.5 <= contact_surface + SURFACE_CONTACT

func past_entrance(operator: RiftPlayer) -> bool:
	return to_local(operator.global_position).x >= ENTRY_CLEARANCE

func is_inside(operator: RiftPlayer) -> bool:
	var at := to_local(operator.global_position)
	return at.x > 0.0 and at.x < EXIT_CLEARANCE and absf(at.z) < 1.5

func set_phase(next: Phase) -> void:
	if phase == next:
		return
	phase = next
	if phase == Phase.SEALED:
		RiftAudio.play_effect(&"enemy_break")
	elif phase == Phase.RISING:
		RiftAudio.foundry_sound(&"fire_jet", global_position)

func present() -> void:
	lava.visible = surface > -1.2
	lava.position = Vector3(SHAFT_RIGHT * 0.5, minf(surface, TUNNEL_CEILING) - 7.0, 0)
	lava.material_override.set_shader_parameter("surface_open", surface <= TUNNEL_CEILING)
	lava_column.visible = surface > TUNNEL_CEILING
	var shaft_center := (SHAFT_LEFT + SHAFT_RIGHT) * 0.5
	lava_column.position = Vector3(shaft_center, surface - 7.0, 0.0)
	lava_column.material_override.set_shader_parameter("visible_depth", minf(surface - TUNNEL_CEILING, 14.0))
	lava_light.visible = lava.visible
	lava_light.position = Vector3(shaft_center, surface + 0.22, 0)
	match phase:
		Phase.READY: prompt.text = "ESCAPE SHAFT\nENTER TOGETHER" if not authority or party_size > 1 else "ESCAPE SHAFT"
		Phase.SEALED: prompt.text = "DOOR SEALED\nCLIMB TO THE GANTRY"
		Phase.RISING: prompt.text = "LAVA RISING\nKEEP CLIMBING"
		Phase.DRAINING: prompt.text = "SHAFT DRAINING"
	var viewer := camera_rig.target
	surface_fire.position = Vector3(shaft_center, surface + 0.04, -0.55)
	var show_fire := lava_column.visible and is_instance_valid(viewer) and absf(to_local(viewer.global_position).y - surface) < 12.0
	if show_fire != surface_fire_active:
		surface_fire_active = show_fire
		if show_fire:
			surface_fire.set_process(true)
			surface_fire.ignite()
		else:
			surface_fire.extinguish()
	warning.visible = (phase == Phase.SEALED or phase == Phase.RISING) and not door.passable \
		and elapsed < WARNING_SECONDS and is_instance_valid(viewer) and viewer.health > 0.0 and is_inside(viewer)
	if warning.visible:
		warning.modulate.a = 1.0 if sin(elapsed * TAU * 1.45) >= -0.22 else 0.20

func snapshot() -> Array:
	return [phase, surface, door.lift(), door.passable, elapsed]

func apply_snapshot(state: Array) -> void:
	set_phase(state[0])
	surface = state[1]
	door.apply(state[2], state[3])
	elapsed = state[4]
	present()
