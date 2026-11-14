extends MeshInstance3D

const LIGHT_FX := preload("res://scripts/combat_vfx.gd")
const GOLD := Color("ffd679")
var arc_mesh := ImmediateMesh.new()
var core := StandardMaterial3D.new()
var halo: Sprite3D
var arcs: MeshInstance3D
var tint := Color.CYAN
var timer := 0.0
var redraw_left := 0.0
var full_charge := false

func _ready() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = .44
	sphere.height = .88
	sphere.radial_segments = 20
	sphere.rings = 10
	mesh = sphere
	core.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core.emission_enabled = true
	material_override = core
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halo = LIGHT_FX.sprite(self, LIGHT_FX.FLASH, Vector3(0, 0, .02), 1.9, tint)
	halo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	halo.material_override = null
	var ionized := StandardMaterial3D.new()
	ionized.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ionized.vertex_color_use_as_albedo = true
	ionized.cull_mode = BaseMaterial3D.CULL_DISABLED
	arcs = MeshInstance3D.new()
	arcs.mesh = arc_mesh
	arcs.material_override = ionized
	arcs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(arcs)

func charge(progress: float, weapon_color: Color, primed: bool) -> void:
	tint = weapon_color
	full_charge = primed
	scale = Vector3.ONE * lerpf(.17, .64, progress)
	var highlight := weapon_color.lerp(Color.WHITE, .67)
	core.albedo_color = highlight if not primed else GOLD.lerp(highlight, .65)
	core.emission = weapon_color
	core.emission_energy_multiplier = 1.65 if primed else .75
	halo.modulate = Color(GOLD.lerp(tint, .68) if primed else tint, lerpf(.35, .79, progress))
	arcs.visible = progress >= .51

func _process(delta: float) -> void:
	timer += delta
	halo.scale = Vector3.ONE * (.93 + sin(timer * (9.0 if full_charge else 6.0)) * .13)
	redraw_left -= delta
	if not arcs.visible or redraw_left > 0.0:
		return
	redraw_left = .055
	arc_mesh.clear_surfaces()
	var count := 3 if full_charge else 2
	for arc in count:
		arc_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for step in range(9):
			var angle := timer * (3.1 + .35 * arc) + float(arc) * 2.16 + step * .265
			var z := .47 + (step % 2) * .075
			var radius := .52 + randf_range(-.045, .065)
			var point := Vector3(cos(angle) * radius, sin(angle) * radius, z * (1 if arc!=1 else -.3))
			var width := .015 if step in [0,8] else .043
			arc_mesh.surface_set_color(tint.lerp(Color.WHITE, .65) if step % 3 else GOLD.lerp(tint, .4))
			arc_mesh.surface_add_vertex(point + Vector3.UP * width)
			arc_mesh.surface_set_color(tint)
			arc_mesh.surface_add_vertex(point - Vector3.UP * width)
		arc_mesh.surface_end()
