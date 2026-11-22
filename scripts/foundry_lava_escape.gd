extends Node3D

const Door := preload("res://scripts/campaign_door.gd")
const Fire := preload("res://addons/pyrolux_fx/nodes_3d/pyrolux_fire_3d.gd")
const LAVA_SHADER := preload("res://assets/neon_factory/foundry/rising_lava.gdshader")
const UI := preload("res://scripts/rift_ui.gd")
const REST_LEVEL := -1.55
const TOP_LEVEL := 79.95
const SHAFT_LEFT := 3.46
const SHAFT_RIGHT := 25.55
const EXIT_CLEARANCE := 26.55
const ENTRY_CLEARANCE := 1.0
const TUNNEL_CEILING := 3.16
const RISE_SPEED := 2.461
const RISE_ACCELERATION := 0.0322
const MAX_RISE_SPEED := 3.588
const RISE_DELAY := 1.65
const WARNING_SECONDS := 3.6
const SURFACE_CONTACT := 0.10 # Includes the crest of the visible surface waves.
const LAVA_HALF_DEPTH := 2.29

enum Phase { READY, SEALED, RISING, DRAINING }

var authority := true
var require_full_party := false
var entrance_ready := false
var phase := Phase.READY
var surface := REST_LEVEL
var elapsed := 0.0
var door: Door
var relays: Node
var actors: Node
var camera_rig: SideCameraRig
var lava: MeshInstance3D
var lava_column: MeshInstance3D
var lava_light: OmniLight3D
var surface_fire: PyroluxFire3D
var surface_fire_active := false
var warning: Label

func _ready() -> void:
	door = Door.new($Entrance)
	door.reset()
	var stage := get_parent().get_parent()
	actors = stage.get_node("Actors")
	camera_rig = stage.get_node("CameraRig")
	lava = make_lava(SHAFT_RIGHT)
	lava_column = make_lava(SHAFT_RIGHT - SHAFT_LEFT + .42)
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
	var volume := RiftProjectile.part(self, slab, molten, Vector3.ZERO, Vector3.ONE)
	volume.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return volume

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
	var squad := actors.get_children().filter(func(actor): return actor is RiftPlayer)
	var party := squad.filter(func(actor): return actor.health > 0.0)
	if not is_instance_valid(relays):
		relays = get_parent().get_parent().get_node_or_null("GateRelays")
	var unlocked: bool = is_instance_valid(relays) and relays.complete()
	var inside := party.filter(is_inside)
	match phase:
		Phase.READY:
			if require_full_party and (not door.passable or (inside.is_empty() and not party.any(door.near))):
				# A partner who has reached the upper gallery cannot return through the sealed shaft.
				entrance_ready = unlocked and squad.any(door.near) and squad.all(ready_for_shaft)
			if unlocked and door.passable and not inside.is_empty() and party.all(past_entrance):
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
	var ready_to_enter := phase == Phase.READY and (not require_full_party or entrance_ready)
	var solo_draining := phase == Phase.DRAINING and not require_full_party
	var open := unlocked and (ready_to_enter or solo_draining)
	door.step(delta, open, party)
	present()

func touches_lava(operator: RiftPlayer) -> bool:
	var at := to_local(operator.global_position)
	var radius := operator.standing_capsule.radius
	var contact_surface := surface if at.x + radius >= SHAFT_LEFT else minf(surface, TUNNEL_CEILING)
	return at.x + radius >= 0.0 and at.x - radius <= SHAFT_RIGHT \
		and absf(at.z) - radius <= LAVA_HALF_DEPTH \
		and at.y - operator.standing_capsule.height * 0.5 <= contact_surface + SURFACE_CONTACT

func ready_for_shaft(operator: RiftPlayer) -> bool:
	if door.near(operator):
		return true
	var at := to_local(operator.global_position)
	return operator.health > 0.0 and at.x >= EXIT_CLEARANCE and at.y >= $ExitBridge.position.y - 2.0

func past_entrance(operator: RiftPlayer) -> bool:
	return to_local(operator.global_position).x >= ENTRY_CLEARANCE

func is_inside(operator: RiftPlayer) -> bool:
	var at := to_local(operator.global_position)
	return at.x > 0.0 and at.x < EXIT_CLEARANCE and absf(at.z) < 1.5

func set_phase(next: Phase) -> void:
	if phase == next:
		return
	phase = next
	if phase != Phase.READY:
		entrance_ready = false
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
