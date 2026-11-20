extends Node3D
## Scoped swimming volume: the same CharacterBody simulation runs on host/guest.
const SWIM_SPEED := 5.8
const VERTICAL_SPEED := 4.5
var dimensions:=Vector3(66,13.8,3.6)
var readout: Label
var trails:={}

func _ready() -> void:
	add_to_group(&"abyssal_water")
	var surface:=MeshInstance3D.new()
	var plane:=PlaneMesh.new()
	plane.size=Vector2(dimensions.x,4)
	plane.subdivide_width=48
	plane.subdivide_depth=8
	surface.mesh=plane
	surface.position.y=dimensions.y*.5
	var water:=ShaderMaterial.new()
	water.shader=preload("res://assets/campaign/abyssal_plant/kit/water.gdshader")
	water.set_shader_parameter("tint",Color(.015,.4,.48,.56))
	water.set_shader_parameter("flow",.22)
	surface.material_override=water
	surface.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(surface)
	var volume:=MeshInstance3D.new()
	var box:=BoxMesh.new()
	box.size=Vector3(dimensions.x,dimensions.y,4)
	volume.mesh=box
	var depth:=ShaderMaterial.new()
	depth.shader=preload("res://assets/campaign/abyssal_plant/kit/water_volume.gdshader")
	volume.material_override=depth
	volume.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(volume)
	var bubbles:=bubble_trail(96,7.0)
	bubbles.emission_shape=CPUParticles3D.EMISSION_SHAPE_BOX
	bubbles.emission_box_extents=Vector3(dimensions.x*.49,dimensions.y*.43,1.5)
	bubbles.initial_velocity_min=.35
	bubbles.initial_velocity_max=.8
	add_child(bubbles)
	var layer:=CanvasLayer.new()
	layer.layer=11
	add_child(layer)
	var screen:=Control.new()
	layer.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter=Control.MOUSE_FILTER_IGNORE
	readout=Label.new()
	screen.add_child(readout)
	readout.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	readout.offset_left=-330
	readout.offset_right=330
	readout.offset_top=145
	readout.offset_bottom=245
	readout.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	readout.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	readout.add_theme_font_override("font",preload("res://assets/ui/fonts/BarlowCondensed-ExtraBoldItalic.ttf"))
	readout.add_theme_font_size_override("font_size",24)
	readout.add_theme_color_override("font_color",Color("a5e9ef"))
	readout.add_theme_color_override("font_outline_color",Color("031423"))
	readout.add_theme_constant_override("outline_size",8)
	readout.mouse_filter=Control.MOUSE_FILTER_IGNORE
	readout.text="FLOODED SERVICE CONDUIT\nSteer to swim. Hold Jump / Up to rise. Down / Crouch to dive."
	readout.hide()

func contains(at: Vector3) -> bool:
	var p:=to_local(at)
	return absf(p.x)<dimensions.x*.5 and p.y<dimensions.y*.5-.12 and p.y>-dimensions.y*.5-.2 and absf(p.z)<1.7

func simulate(actor,delta: float) -> void:
	if actor.controls_suspended:
		actor.velocity=Vector3.ZERO
		return
	actor.fire_lock=maxf(0,actor.fire_lock-delta)
	actor.dash_lock=maxf(0,actor.dash_lock-delta)
	actor.coyote=0
	actor.jump_buffer=0
	actor.wall_sliding=false
	actor.wall_grace=0
	actor.air_dash_available=true
	actor.landing_left=0
	actor.clear_ladder_support()
	actor.ladder=null
	actor.jungle_vine=null
	actor.set_crouch(false)
	var axis: float=actor.movement_axis("move_left","move_right")
	var vertical: float=actor.movement_axis("climb_down","climb_up")
	if actor.action_held("jump"): vertical=1
	if actor.action_held("crouch") or actor.action_held("crouch_stick"): vertical=-1
	if actor.shock_stun>0:
		axis=0
		vertical=0
	if absf(axis)>.1: actor.facing=signf(axis)
	if not actor.local_prediction:
		if actor.melee_lock<=0:
			if actor.action_pressed("swap_weapon"): actor.cycle_weapon()
			elif actor.action_pressed("previous_suit"): actor.cycle_weapon(-1)
		actor.update_charge(delta)
		actor.update_melee(delta)
	var steering:=Vector2(axis,vertical).limit_length(1)
	var frost:=.66 if actor.boss_debuff==3 else 1.0
	var drift:=0.0 if actor.action_held("field_interact") else .12
	var target:=Vector3(steering.x*SWIM_SPEED*frost,steering.y*VERTICAL_SPEED*frost if absf(vertical)>.1 else drift,0)
	var diving:=vertical<-.2
	if not diving and actor.resume_input_guard<=0 and actor.shock_stun<=0 and actor.action_pressed("dash") and actor.dash_lock<=0:
		actor.dash_left=.20
		actor.dash_elapsed=0
		actor.dash_lock=.65
		actor.dash_facing=actor.facing
		actor.velocity.x=actor.facing*9.0
	if actor.dash_left>0:
		actor.dash_left=maxf(0,actor.dash_left-delta)
		actor.dash_elapsed+=delta
		target.x=actor.dash_facing*9.0
	if actor.contact_recoil>0:
		actor.contact_recoil=maxf(0,actor.contact_recoil-delta)
	else:
		actor.velocity=actor.velocity.move_toward(target,(17.0 if steering.length()<.1 else 13.0)*delta)
	actor.velocity.z=-actor.global_position.z*18.0
	actor.update_one_way_collisions()
	actor.move_and_slide()
	if not contains(actor.global_position): actor.dash_left=0
	actor.update_character_visuals(axis)

func bubble_trail(amount: int,lifetime: float) -> CPUParticles3D:
	var particles:=CPUParticles3D.new()
	particles.amount=amount
	particles.lifetime=lifetime
	particles.direction=Vector3.UP
	particles.spread=20
	particles.gravity=Vector3(0,.3,0)
	particles.initial_velocity_min=.25
	particles.initial_velocity_max=.6
	particles.scale_amount_min=.025
	particles.scale_amount_max=.055
	particles.visibility_range_end=45
	var bubble:=SphereMesh.new()
	bubble.radial_segments=8
	bubble.rings=4
	var finish:=StandardMaterial3D.new()
	finish.albedo_color=Color("a2ebef")
	finish.metallic=.65
	finish.roughness=.15
	bubble.material=finish
	particles.mesh=bubble
	return particles

func _process(_delta: float) -> void:
	var stage:=get_parent().get_parent()
	var camera:=stage.get_node("CameraRig") as SideCameraRig
	readout.visible=is_instance_valid(camera.target) and camera.target.health>0 and not camera.target.controls_suspended and contains(camera.target.global_position)
	var live:={}
	for actor in stage.get_node("Actors").get_children():
		if not actor is RiftPlayer or actor.health<=0 or not contains(actor.global_position): continue
		var id:=actor.get_instance_id()
		live[id]=true
		if not trails.has(id):
			var bubbles:=bubble_trail(18,1.1)
			add_child(bubbles)
			trails[id]=bubbles
		trails[id].global_position=actor.global_position+Vector3(0,.35,0)
	for id in trails.keys():
		if not live.has(id):
			trails[id].queue_free()
			trails.erase(id)
