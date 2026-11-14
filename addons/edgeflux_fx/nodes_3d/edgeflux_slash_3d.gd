@tool
@icon("res://addons/edgeflux_fx/icons/slash.svg")
class_name EdgefluxSlash3D
extends EdgefluxEffect3D
## One-shot slash arc. The arc lies on the node's local XZ plane and is centred on -Z, so the
## node's forward axis is where the blade cuts. Rotate the node for vertical or diagonal cuts.
## Call slash() (or slash(true) to sweep the other way, for combo hits).

const SLASH_SHADER: Shader = preload("res://addons/edgeflux_fx/shaders/edgeflux_slash.gdshader")
const SLASH_SOLID_SHADER: Shader = preload("res://addons/edgeflux_fx/shaders/edgeflux_slash_solid.gdshader")

enum Shape { CRESCENT, WIDE, SPIN, CROSS, DOUBLE }
enum Look { GLOW, SOLID }

@export var shape: Shape = _default(&"shape", Shape.CRESCENT):
	set(v):
		shape = v
		_rebuild_mesh()
## GLOW is additive light; SOLID draws flat colour bands with an outline.
@export var look: Look = _default(&"look", Look.GLOW):
	set(v):
		look = v
		_rebuild_mesh()
## Angle covered by the arc, in degrees.
@export_range(10.0, 360.0, 1.0) var arc_degrees: float = _default(&"arc_degrees", 150.0):
	set(v):
		arc_degrees = v
		_rebuild_mesh()
## Distance from the pivot to the cutting edge, in metres before node scale.
@export_range(0.1, 20.0, 0.01, "or_greater") var radius: float = _default(&"radius", 1.6):
	set(v):
		radius = v
		_rebuild_mesh()
## Width of the slash band.
@export_range(0.02, 10.0, 0.01, "or_greater") var band: float = _default(&"band", 0.85):
	set(v):
		band = v
		_rebuild_mesh()
## Seconds for the whole sweep (in and out).
@export_range(0.05, 3.0, 0.01) var duration: float = _default(&"duration", 0.32)
## Length of the lit part as a fraction of the arc.
@export_range(0.05, 1.5, 0.01) var trail_length: float = _default(&"trail_length", 0.65)
@export_range(0.05, 1.0, 0.01) var thickness: float = _default(&"thickness", 0.85)
@export_range(0.0, 0.5, 0.005) var edge_width: float = _default(&"edge_width", 0.08)
## Noise that eats the tail away.
@export_range(0.0, 1.0, 0.01) var dissolve: float = _default(&"dissolve", 0.5)
@export_range(0.0, 1.0, 0.01) var streaks: float = _default(&"streaks", 0.5)
## Sweep direction. slash(true) sweeps the other way.
@export var flip: bool = false
## Change direction on every play (combo strings).
@export var alternate: bool = _default(&"alternate", false)
## A wider, dimmer copy that lingers after the cut.
@export_range(0.0, 1.0, 0.01) var afterimage: float = _default(&"afterimage", 0.5)

@export_group("Sparks")
@export var sparks: bool = _default(&"sparks", true)
@export_range(0, 64) var spark_count: int = _default(&"spark_count", 14)

var _mi: MeshInstance3D
var _ghost: MeshInstance3D
var _light: OmniLight3D
var _flip_now: bool = false
var _sparked: int = 0
var _max_delay: float = 0.0


func _class_defaults() -> Dictionary:
	return {&"light_energy": 2.0, &"light_range": 4.0}


func _build() -> void:
	_mi = make_mesh(null, SLASH_SHADER)
	_ghost = make_mesh(null, SLASH_SHADER)
	_light = make_light()
	make_streak_pool(3, 32)
	_rebuild_mesh()
	_set_progress(10.0)


## Plays the slash. `reverse` sweeps the other way for this run.
func slash(reverse: bool = false) -> void:
	_flip_now = flip != reverse
	play()


func _on_play() -> void:
	if alternate:
		_flip_now = not _flip_now
	_sparked = 0


func _strands() -> Array[Dictionary]:
	match shape:
		Shape.WIDE:
			return [{"arc": minf(arc_degrees * 1.6, 320.0)}]
		Shape.SPIN:
			return [{"arc": 360.0}]
		Shape.CROSS:
			return [{"roll": 38.0}, {"roll": -38.0, "delay": 0.22}]
		Shape.DOUBLE:
			return [{}, {"radius": 0.8, "delay": 0.14, "roll": 6.0}]
	return [{}]


func _rebuild_mesh() -> void:
	if not _mi:
		return
	var st: Array[Dictionary] = _strands()
	_max_delay = 0.0
	for d in st:
		var dl: float = d.get("delay", 0.0)
		_max_delay = maxf(_max_delay, dl)
	var mesh: ArrayMesh = EdgefluxMeshes.arc_strands(st, arc_degrees, radius, band, 64 if shape == Shape.SPIN else 48)
	_mi.mesh = mesh
	_ghost.mesh = mesh
	var sh: Shader = SLASH_SOLID_SHADER if look == Look.SOLID else SLASH_SHADER
	mat_of(_mi).shader = sh
	mat_of(_ghost).shader = SLASH_SHADER
	_ghost.visible = look == Look.GLOW
	var r: float = radius + band
	_mi.custom_aabb = AABB(Vector3(-r, -r, -r), Vector3(r, r, r) * 2.0)
	_ghost.custom_aabb = _mi.custom_aabb


func _total() -> float:
	return duration * (1.0 + _max_delay) + 0.05


func _is_done() -> bool:
	return age > _total() and not streaks_busy()


func _set_progress(p: float) -> void:
	var m: ShaderMaterial = mat_of(_mi)
	m.set_shader_parameter("progress", p)
	var g: ShaderMaterial = mat_of(_ghost)
	g.set_shader_parameter("progress", p * 0.92)


func _tick(_dt: float) -> void:
	if not _mi:
		return
	var p: float = age / duration
	var running: bool = age <= _total()
	_mi.visible = running
	_ghost.visible = running and look == Look.GLOW and afterimage > 0.0
	if not running:
		drive_light(_light, 0.0)
		return
	_set_progress(p)
	var m: ShaderMaterial = mat_of(_mi)
	m.set_shader_parameter("trail_length", trail_length)
	m.set_shader_parameter("thickness", thickness)
	m.set_shader_parameter("edge_width", edge_width)
	m.set_shader_parameter("dissolve", dissolve)
	m.set_shader_parameter("streaks", streaks)
	m.set_shader_parameter("flip", _flip_now)
	m.set_shader_parameter("time", age)
	m.set_shader_parameter("intensity", intensity)
	var g: ShaderMaterial = mat_of(_ghost)
	g.set_shader_parameter("trail_length", minf(trail_length * 1.7, 1.5))
	g.set_shader_parameter("thickness", thickness * 0.55)
	g.set_shader_parameter("edge_width", 0.0)
	g.set_shader_parameter("dissolve", 1.0)
	g.set_shader_parameter("streaks", 1.0)
	g.set_shader_parameter("flip", _flip_now)
	g.set_shader_parameter("time", age * 0.7)
	g.set_shader_parameter("intensity", intensity * afterimage * 0.6)
	var head_u: float = clampf(p * (1.0 + trail_length), 0.0, 1.0)
	_light.position = _arc_point(head_u, 0.85)
	drive_light(_light, envelope(age, duration * 0.15, _total(), duration * 0.6))
	if sparks and spark_count > 0:
		var marks: Array[float] = [0.45, 0.95]
		while _sparked < marks.size() and head_u >= marks[_sparked]:
			_emit_sparks(marks[_sparked])
			_sparked += 1


## Point on the main arc at u (0..1 along the sweep), r = fraction of the radius.
func _arc_point(u: float, r: float) -> Vector3:
	var uu: float = 1.0 - u if _flip_now else u
	var arc: float = deg_to_rad(arc_degrees)
	match shape:
		Shape.WIDE:
			arc = deg_to_rad(minf(arc_degrees * 1.6, 320.0))
		Shape.SPIN:
			arc = TAU
	var a: float = -arc * 0.5 + arc * uu
	var p: Vector3 = Vector3(sin(a), 0.0, -cos(a)) * radius * r
	if shape == Shape.CROSS:
		p = Basis(Vector3.FORWARD, deg_to_rad(38.0)) * p
	return p


func _emit_sparks(u: float) -> void:
	var s: float = world_scale()
	var p0: Vector3 = to_global(_arc_point(u, 1.0))
	var p1: Vector3 = to_global(_arc_point(maxf(u - 0.2, 0.0), 1.0))
	var tangent: Vector3 = (p0 - p1).normalized()
	emit_streaks({"mode": 0, "origin": p0, "origin_b": p1, "emit_dir": tangent, "spread": 0.7,
		"speed_min": 2.0, "speed_max": 6.0, "life_min": 0.18, "life_max": 0.45, "gravity": 5.0,
		"drag": 3.5, "streak": 0.05, "width": 0.018, "delay_spread": 0.04,
		"count_fraction": clampf(float(spark_count) / 32.0, 0.0, 1.0), "intensity": intensity}, 3.0 * s)
