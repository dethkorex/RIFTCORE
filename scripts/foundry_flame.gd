extends Node3D

const FLOOR_SHADER := preload("res://assets/neon_factory/foundry/attack_floor.gdshader")
const Fire := preload("res://addons/pyrolux_fx/nodes_3d/pyrolux_fire_3d.gd")

enum Style { BACKDRAFT, CASTING, HIGH_VENT, DRILL }

var height := 2.4
var width := 1.2
var warning_time := 0.65
var burst_time := 0.66
var style := Style.BACKDRAFT
var mark: MeshInstance3D
var mark_material: ShaderMaterial
var fire: PyroluxFire3D
var burning_last_frame := false


func _ready() -> void:
	var footprint := width * 0.98 + 0.64
	var tint := Color("ff5f29")
	if style == Style.CASTING:
		tint = Color("ff8d3f")
	elif style == Style.HIGH_VENT:
		tint = Color("ff4a31")
	mark = floor_mark(footprint, 2.22 if style == Style.CASTING else 1.96, style, tint)
	add_child(mark)
	mark_material = mark.material_override as ShaderMaterial
	fire = Fire.new()
	fire.autoplay = false
	fire.preview_in_editor = false
	fire.fade_time = 0.10
	fire.lean = 0.11
	fire.shape = PyroluxFire3D.Shape.LINE
	fire.size = Vector3(width * 0.38, 0.08, 0.23)
	fire.flame_height = height * (0.82 if style == Style.CASTING else 0.96)
	fire.flame_width = clampf(width * 0.24, 0.38, 0.94)
	fire.tongues = 5 if width > 2.2 else 4
	fire.puffs = 6
	fire.embers = 13 if width > 2.2 else 9
	fire.ember_height = height * 1.23
	fire.smoke = 5
	fire.smoke_height = height * 1.33
	fire.smoke_opacity = 0.29 if style == Style.CASTING else 0.40
	fire.light_enabled = true
	fire.light_energy = 0.77 if style == Style.CASTING else 1.32
	fire.light_range = 3.4
	var colors := PyroluxPalette.new()
	colors.cool = Color("922716")
	colors.hot = tint
	colors.core = Color("ffd77d")
	colors.smoke = Color("4c4644")
	colors.light = tint
	fire.palette = colors
	add_child(fire)
	fire.set_process(false)
	fire.finished.connect(func(): fire.set_process(false))
	show_phase(-1.0)


static func floor_mark(length: float, depth: float, mode: int, tint: Color) -> MeshInstance3D:
	var floor_strip := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(length, depth)
	floor_strip.mesh = quad
	floor_strip.rotation.x = -PI * 0.5
	floor_strip.position.y = 0.11
	floor_strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shader := ShaderMaterial.new()
	shader.shader = FLOOR_SHADER
	shader.set_shader_parameter("tint", tint)
	shader.set_shader_parameter("mode", mode)
	shader.set_shader_parameter("span", length)
	floor_strip.material_override = shader
	return floor_strip


func show_phase(at: float) -> void:
	var warning := at >= 0.0 and at < warning_time
	var burning := at >= warning_time and at < warning_time + burst_time
	if warning or burning:
		mark_material.set_shader_parameter("progress", clampf(at / maxf(warning_time, 0.001), 0.0, 1.0))
		var cooling := 1.0 - clampf((at - warning_time) / burst_time, 0.0, 1.0)
		mark_material.set_shader_parameter("heat", cooling if burning else 0.0)
	mark.visible = warning or burning
	if burning and not burning_last_frame:
		fire.set_process(true)
		fire.ignite()
	elif not burning and burning_last_frame:
		fire.extinguish()
	burning_last_frame = burning
