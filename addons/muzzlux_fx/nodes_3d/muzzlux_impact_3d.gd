@tool
@icon("res://addons/muzzlux_fx/icons/impact.svg")
class_name MuzzluxImpact3D
extends MuzzluxEffect3D
## The material-specific impact: what a round does to the thing it hit.
##
##   impact.burst(hit.position, hit.normal, &"metal")
##   impact.burst(p, n, &"wood", 1.4)          # a heavier round
##
## One node covers every material it knows. **Lite ships three: `concrete`, `metal` and
## `wood`**, as rows of numbers in ROWS below, uploaded once as uniform arrays; a hit carries
## its row index in its slot. So a player spraying a wall of concrete, steel and wood gets
## the right debris, sparks, dust and bloom for each hit out of one static mesh and one
## material - no branch in the shader, no second node, nothing instanced.
##
## What the full pack adds to this node:
##   * six more surfaces (dirt, sand, water, glass, metal_plate, flesh) plus `energy`
##   * the surface table resource, which works the surface out from the collider on its own
##     (a meta key, a PhysicsMaterial name, or a hint in the node name) and lets a project
##     add its own materials without touching any code
##   * bullet holes, so a hit leaves something behind
##   * burst_rolled(), which pins the turn of the hit instead of randomising it (a glancing
##     hit on a steel plate skids in a direction that is not arbitrary)
##   * the optional dark-red layer for hits on a body, double-gated and off by default
##   * 16 live hits instead of 4
##
## Slot packing for this node (the three shared arrays of MuzzluxShots):
##   a = (hit position, start_time)
##   b = (**hit normal**, strength)             - b.xyz is the surface normal, not a heading
##   c = (roll, size, surface row index, **delay in seconds**)

const SH_DUST: Shader = preload("res://addons/muzzlux_fx/shaders/muzzlux_impact_dust.gdshader")
const SH_DEBRIS: Shader = preload("res://addons/muzzlux_fx/shaders/muzzlux_impact_debris.gdshader")
const SH_SPLINTERS: Shader = preload("res://addons/muzzlux_fx/shaders/muzzlux_impact_splinters.gdshader")
const SH_SPARKS: Shader = preload("res://addons/muzzlux_fx/shaders/muzzlux_impact_sparks.gdshader")
const SH_CORE: Shader = preload("res://addons/muzzlux_fx/shaders/muzzlux_impact_core.gdshader")

## Quads the core layer draws per hit: the bloom and the surface ring.
const CORE_PER_SHOT: int = 2

## Rows the shader arrays hold. Must stay equal to MX_SURFACES in
## muzzlux_surfaces.gdshaderinc. Lite fills the first three and repeats concrete in the rest,
## so an unknown id shows a concrete hit instead of nothing at all.
const MAX_ROWS: int = 16

## The ids Lite ships a look for. The shaders get the index of the id in this array, so the
## order is part of the shader contract: it is the same first three the full pack uses.
const IDS: Array[StringName] = [&"concrete", &"metal", &"wood"]

## Row fields, all 0..1 unless said otherwise:
##   debris       colour of chips and splinters
##   dust         colour of the powder cloud
##   chips        how much solid debris flies off
##   sparks       how many white-hot sparks
##   dust_amount  how much of the cloud there is
##   dust_rise    0 hangs in place, 1 climbs
##   along        0 debris leaves along the hit normal, 1 skids along the surface
##   gravity      how fast the debris falls
##   hole_style   which procedural crater the full pack's hole manager would use: 0 pit,
##                1 dent, 3 splinters. Kept so the numbers match the full pack's row exactly
##   light        brightness of the one-frame impact light, 0 = no light
##   duration     seconds the impact burst lasts
##   ring         a ring that spreads *on* the hit surface. 0 = none
##   ring_speed   how fast that ring spreads, metres per second
##   bloom        size of the bright flash at the hit point in metres, 0 = none
##   debris_size  multiplies the node's `debris_size` for this material (a splinter of wood
##                is three times a flake of steel)
const ROWS: Dictionary = {
	&"concrete": {
		"debris": Color(0.69, 0.68, 0.65), "dust": Color(0.82, 0.81, 0.78),
		"chips": 1.0, "sparks": 0.0, "dust_amount": 0.85, "dust_rise": 0.3,
		"along": 0.1, "gravity": 0.8, "hole": 1.0, "hole_style": 0,
		"light": 0.40, "duration": 1.3,
		"ring": 0.18, "ring_speed": 0.16, "bloom": 0.10, "debris_size": 1.0,
	},
	&"metal": {
		"debris": Color(0.72, 0.70, 0.68), "dust": Color(0.56, 0.55, 0.54),
		"chips": 0.4, "sparks": 1.0, "dust_amount": 0.45, "dust_rise": 0.2,
		"along": 0.2, "gravity": 0.7, "hole": 1.0, "hole_style": 1,
		"light": 1.0, "duration": 1.1,
		"ring": 0.16, "ring_speed": 0.14, "bloom": 0.17, "debris_size": 0.6,
	},
	&"wood": {
		"debris": Color(0.56, 0.38, 0.20), "dust": Color(0.74, 0.56, 0.30),
		"chips": 1.0, "sparks": 0.0, "dust_amount": 0.6, "dust_rise": 0.2,
		"along": 0.15, "gravity": 0.6, "hole": 1.0, "hole_style": 3,
		"light": 0.25, "duration": 1.2,
		"ring": 0.12, "ring_speed": 0.12, "bloom": 0.08, "debris_size": 1.3,
	},
}

## Surface used by burst() when it is not told one, and by the editor preview.
@export var default_surface: StringName = _default(&"default_surface", &"concrete")
## Size of the whole hit in metres, before node scale.
@export_range(0.05, 4.0, 0.01, "or_greater") var size: float = _default(&"size", 1.0)
## Multiplies the strength every burst() is given.
@export_range(0.0, 4.0, 0.01) var strength_scale: float = _default(&"strength_scale", 1.0)

@export_group("Debris")
## Solid pieces per hit at `chips` = 1. 0 turns the layer off.
@export_range(0, 24, 1) var debris_count: int = _default(&"debris_count", 10):
	set(value):
		debris_count = clampi(value, 0, 24)
		rebuild()
## Longest edge of a piece in metres.
@export_range(0.002, 0.3, 0.001) var debris_size: float = _default(&"debris_size", 0.06)
## Metres per second a piece leaves at.
@export_range(0.0, 30.0, 0.1, "or_greater") var debris_speed: float = _default(&"debris_speed", 3.2)
## Seconds a piece lives.
@export_range(0.05, 4.0, 0.01) var debris_life: float = _default(&"debris_life", 0.9)

@export_group("Sparks")
## White-hot streaks per hit at `sparks` = 1. Of the three Lite surfaces only metal has any.
@export_range(0, 24, 1) var spark_count: int = _default(&"spark_count", 14):
	set(value):
		spark_count = clampi(value, 0, 24)
		rebuild()
@export_range(0.0, 40.0, 0.1, "or_greater") var spark_speed: float = _default(&"spark_speed", 5.5)
@export_range(0.02, 2.0, 0.01) var spark_life: float = _default(&"spark_life", 0.42)

@export_group("Dust")
## Puffs of powder per hit at `dust_amount` = 1.
@export_range(0, 20, 1) var dust_count: int = _default(&"dust_count", 10):
	set(value):
		dust_count = clampi(value, 0, 20)
		rebuild()
## Size of one puff in metres.
@export_range(0.01, 2.0, 0.01, "or_greater") var dust_size: float = _default(&"dust_size", 0.19)
## Multiplies every surface's own dust amount, for a scene that wants less of it.
@export_range(0.0, 2.0, 0.01) var dust_scale: float = _default(&"dust_scale", 1.0)

@export_group("Flash")
## Draw the short bright bloom at the hit point.
@export var bloom: bool = _default(&"bloom", true):
	set(value):
		bloom = value
		rebuild()
## Seconds the bloom lasts.
@export_range(0.01, 0.5, 0.005) var bloom_time: float = _default(&"bloom_time", 0.07)
## Multiplies every surface's bloom size.
@export_range(0.0, 4.0, 0.01) var bloom_scale: float = _default(&"bloom_scale", 1.0)
## Multiplies every surface's ring: the faint dust ring of a concrete hit.
@export_range(0.0, 4.0, 0.01) var ring_scale: float = _default(&"ring_scale", 1.0)

## Emitted for every hit, with the ring slot it went into.
signal hit_added(slot: int)

var _dust: ShaderMaterial
var _debris: ShaderMaterial
var _splinters: ShaderMaterial
var _sparks: ShaderMaterial
var _core: ShaderMaterial
var _hits: int = 0
var _last_slot: int = -1
var _last_surface: StringName = &"concrete"
var _last_position: Vector3 = Vector3.ZERO
var _built_debris: int = 0
var _built_sparks: int = 0
var _built_dust: int = 0
var _built_slots: int = 0
var _rows_dirty: bool = true
# Read out of the rows once per upload, never per frame.
var _row_light: PackedFloat32Array = PackedFloat32Array()
var _row_dur: PackedFloat32Array = PackedFloat32Array()
var _longest: float = 1.2
# Effect time at which the last hit pushed into the ring will be finished. The node stays
# visible until then, so a wood hit that runs for 1.2 s is not cut off by a metal hit that
# was over in 0.9 s.
var _end_time: float = -1.0
var _end_clock: float = 0.0
# One pending hit, set by burst() and read by _on_trigger(), so a burst never allocates.
var _p_pos: Vector3 = Vector3.ZERO
var _p_normal: Vector3 = Vector3.UP
var _p_surface: StringName = &"concrete"
var _p_strength: float = 1.0
var _p_delay: float = 0.0
var _has_pending: bool = false


func _class_defaults() -> Dictionary:
	return {
		&"amount": 1.0,
		&"time_scale": 1.0,
		&"autoplay": true,
		&"fade_time": 0.0,
		&"preview_interval": 1.3,
		# Lite builds four live slots. The full pack ships 16 and allows 32, which is what a
		# weapon on full auto needs: at four, a held trigger drops hits.
		&"max_concurrent": 4,
		&"wind": Vector3.ZERO,
		&"light_enabled": true,
		&"light_energy": 1.6,
		&"light_range": 1.4,
		&"default_surface": &"concrete",
		&"size": 1.0,
		&"strength_scale": 1.0,
		# Look 2 (2026-10-11): bigger, more and longer-lived. At the old figures (8 chips of
		# 4.5 cm, 10 sparks for 0.3 s, 6 puffs of 0.2 m) a hit was a cluster of white
		# grains that filled a tenth of the frame at the demo's own distance.
		&"debris_count": 10,
		&"debris_size": 0.06,
		&"debris_speed": 3.2,
		&"debris_life": 0.9,
		&"spark_count": 14,
		&"spark_speed": 5.5,
		&"spark_life": 0.42,
		&"dust_count": 10,
		&"dust_size": 0.19,
		&"dust_scale": 1.0,
		&"bloom": true,
		&"bloom_time": 0.07,
		&"bloom_scale": 1.0,
		&"ring_scale": 1.0,
	}


func is_one_shot() -> bool:
	return true


func get_duration() -> float:
	if _end_time < 0.0:
		# Nothing has been pushed yet (the editor preview's first frame).
		return _duration_for(_longest)
	# The trigger time is now minus the age the base class is counting, so the length the
	# base compares against is however much of the newest hit's life is still to run.
	var t0: float = get_time() - maxf(get_age(), 0.0)
	return maxf(_end_time - t0, 0.05)


## How long a hit on a row of `duration` seconds takes to finish, including the layers that
## outlive the dust (each shader stretches its own elements, which is why the factors are
## above 1).
func _duration_for(row_duration: float) -> float:
	var dust: float = row_duration * 1.35
	var deb: float = debris_life * 1.4 if debris_count > 0 else 0.0
	var spk: float = spark_life * 1.4 if spark_count > 0 else 0.0
	return maxf(dust, maxf(deb, maxf(spk, bloom_time))) + 0.05


func _extent() -> Vector3:
	var r: float = maxf(debris_speed * debris_life, spark_speed * spark_life) + size * 1.5
	return Vector3(r, r, r)


# ---------------------------------------------------------------- API

## One hit. `position` and `normal` are world space, `surface` is &"concrete", &"metal" or
## &"wood" (or &"" for `default_surface`), `strength` scales the whole thing. `delay` holds
## the hit back by that many seconds without any CPU work in between. Returns the ring slot.
func burst(position: Vector3, normal: Vector3, surface: StringName = &"",
		strength: float = 1.0, delay: float = 0.0) -> int:
	_p_pos = position
	var n: Vector3 = normal
	_p_normal = n.normalized() if n.length() > 0.0001 else Vector3.UP
	_p_surface = surface if surface != &"" else default_surface
	_p_strength = maxf(strength, 0.0)
	_p_delay = maxf(delay, 0.0)
	_has_pending = true
	trigger()
	return _last_slot


## Hits this node has shown since the last reset().
func get_hit_count() -> int:
	return _hits


func get_last_slot() -> int:
	return _last_slot


func get_last_surface() -> StringName:
	return _last_surface


func get_last_position() -> Vector3:
	return _last_position


## Slots holding a live hit.
func get_live_count() -> int:
	return shots().live_count()


## The ids this build knows. Lite: concrete, metal, wood.
static func get_surface_ids() -> Array[StringName]:
	return IDS.duplicate()


## Seconds a hit on `surface` lasts, for a caller that wants to free something afterwards.
func duration_of(surface: StringName) -> float:
	return num(_row_of(surface), "duration", 1.0)


# ---------------------------------------------------------------- rows

## One field of a row as a float. A dictionary read gives a Variant, and passing that to
## float() is exactly what the strict typed-warning check forbids, so the value goes through
## a typed variable instead.
static func num(row: Dictionary, key: String, fallback: float) -> float:
	if not row.has(key):
		return fallback
	var out: float = fallback
	out = row[key]
	return out


## One field of a row as a colour, the same way.
static func col(row: Dictionary, key: String, fallback: Color) -> Color:
	if not row.has(key):
		return fallback
	var out: Color = fallback
	out = row[key]
	return out


## Row index `surface` gets in the shader arrays, or 0 (concrete) for an id Lite does not
## know, so a typo in a surface name shows a concrete hit instead of nothing at all.
static func index_for(surface: StringName) -> int:
	var i: int = IDS.find(surface)
	return i if i >= 0 else 0


static func _row_of(surface: StringName) -> Dictionary:
	var out: Dictionary = ROWS[IDS[index_for(surface)]]
	return out


## The three rows as the five `vec4` arrays muzzlux_surfaces.gdshaderinc reads, padded out to
## MAX_ROWS with concrete. Built once per material, not per hit.
static func pack_rows() -> Array[PackedVector4Array]:
	var a: PackedVector4Array = PackedVector4Array()
	var b: PackedVector4Array = PackedVector4Array()
	var c: PackedVector4Array = PackedVector4Array()
	var d: PackedVector4Array = PackedVector4Array()
	var e: PackedVector4Array = PackedVector4Array()
	a.resize(MAX_ROWS)
	b.resize(MAX_ROWS)
	c.resize(MAX_ROWS)
	d.resize(MAX_ROWS)
	e.resize(MAX_ROWS)
	for i in MAX_ROWS:
		var id: StringName = IDS[i] if i < IDS.size() else IDS[0]
		var r: Dictionary = ROWS[id]
		var dbg: Color = col(r, "debris", Color.WHITE)
		var dst: Color = col(r, "dust", Color.WHITE)
		a[i] = Vector4(dbg.r, dbg.g, dbg.b, num(r, "chips", 0.0))
		b[i] = Vector4(dst.r, dst.g, dst.b, num(r, "dust_amount", 0.0))
		c[i] = Vector4(num(r, "sparks", 0.0), num(r, "dust_rise", 0.0),
			num(r, "along", 0.0), num(r, "gravity", 1.0))
		d[i] = Vector4(num(r, "hole", 1.0), num(r, "hole_style", 0.0),
			num(r, "light", 0.0), num(r, "duration", 1.0))
		e[i] = Vector4(num(r, "ring", 0.0), num(r, "ring_speed", 1.0),
			num(r, "bloom", 0.0), num(r, "debris_size", 1.0))
	return [a, b, c, d, e]


## Longest `duration` in the rows, so the node knows how long its one-shot lasts even when
## the next hit is on a different material than the last one.
static func longest_duration() -> float:
	var best: float = 0.3
	for id: StringName in IDS:
		var r: Dictionary = ROWS[id]
		best = maxf(best, num(r, "duration", 1.0))
	return best


# ---------------------------------------------------------------- internals

func _on_trigger() -> void:
	if not _has_pending:
		# A bare trigger() (the editor preview, or Muzzlux.impact's fallback) means "hit the
		# node's own spot, facing the way the node faces".
		var t: Transform3D = global_transform
		_p_pos = t.origin
		var n: Vector3 = t.basis.z
		_p_normal = n.normalized() if n.length() > 0.0001 else Vector3.UP
		_p_surface = default_surface
		_p_strength = 1.0
		_p_delay = 0.0
	_has_pending = false
	if _row_dur.is_empty():
		_push_rows()
	var sid_i: int = index_for(_p_surface)
	var sid: float = float(sid_i)
	var roll: float = rng.randf_range(0.0, TAU)
	# push() is called instead of the base class's helper because this node packs the hit
	# **normal** into b.xyz and the row index into c.z itself.
	var slot: int = shots().push(_p_pos, _p_normal, get_time(), _p_strength * strength_scale,
		roll, size, sid, _p_delay)
	_last_slot = slot
	_last_surface = _p_surface
	_last_position = _p_pos
	_hits += 1
	# When this hit will be done, in effect time. The newest hit never shortens the node's
	# life.
	var dur: float = _duration_for(
		_row_dur[sid_i] if sid_i >= 0 and sid_i < _row_dur.size() else _longest)
	var until: float = get_time() + _p_delay + dur
	_end_time = maxf(_end_time, until) if _end_time >= 0.0 else until
	_end_clock = get_time()
	hit_added.emit(slot)


func _on_reset() -> void:
	_hits = 0
	_last_slot = -1
	_has_pending = false
	_rows_dirty = true
	_end_time = -1.0
	_end_clock = 0.0


func _debris_total() -> int:
	return count_for(debris_count) if debris_count > 0 else 0


func _spark_total() -> int:
	return count_for(spark_count) if spark_count > 0 else 0


func _dust_total() -> int:
	return count_for(dust_count) if dust_count > 0 else 0


func _build() -> void:
	_built_slots = max_concurrent
	_built_debris = _debris_total()
	_built_sparks = _spark_total()
	_built_dust = _dust_total()
	_dust = null
	_debris = null
	_splinters = null
	_sparks = null
	_core = null
	# The dust goes down first, with normal blending: it is the dark layer the bright part of
	# the hit sits on, and it is what makes an impact read on a white wall.
	if _built_dust > 0:
		_dust = make_layer(SH_DUST, MuzzluxMeshes.quads(_built_slots * _built_dust), -1)
	if _built_debris > 0:
		_debris = make_layer(SH_DEBRIS,
			MuzzluxMeshes.chips(_built_slots * _built_debris, seed_value), 0)
		# Wood is the one material that throws long pieces instead of grit, so it gets a mesh
		# of its own. Both layers are built: a single manager is hit on several materials.
		_splinters = make_layer(SH_SPLINTERS,
			MuzzluxMeshes.splinters(_built_slots * maxi(_built_debris - 2, 2), seed_value + 7),
			0)
	if bloom:
		_core = make_layer(SH_CORE, MuzzluxMeshes.quads(_built_slots * CORE_PER_SHOT), 1)
	if _built_sparks > 0:
		_sparks = make_layer(SH_SPARKS,
			MuzzluxMeshes.strips(_built_slots * _built_sparks, 4), 2)
	_rows_dirty = true


func _tick(_delta: float) -> void:
	if _built_slots != max_concurrent or _built_debris != _debris_total() \
			or _built_sparks != _spark_total() or _built_dust != _dust_total():
		rebuild()
		return
	var s: float = world_scale()
	# The effect clock wraps once an hour; the end time has to follow it or the node would
	# look as if every live hit were an hour in the future and blink out.
	if get_time() < _end_clock - 1000.0 and _end_time >= 0.0:
		_end_time -= 3600.0
	_end_clock = get_time()
	if _rows_dirty or Engine.is_editor_hint():
		_push_rows()
	if _dust != null:
		_dust.set_shader_parameter("per_shot", _built_dust)
		_dust.set_shader_parameter("puff_size", dust_size * s)
		_dust.set_shader_parameter("puff_speed", 1.2 * s)
		_dust.set_shader_parameter("dust_scale", dust_scale)
	if _debris != null:
		_debris.set_shader_parameter("per_shot", _built_debris)
		_debris.set_shader_parameter("chip_size", debris_size * s)
		_debris.set_shader_parameter("chip_speed", debris_speed * s)
		_debris.set_shader_parameter("chip_life", debris_life)
		_debris.set_shader_parameter("gravity", 9.8 * s)
	if _splinters != null:
		var sp_per: int = maxi(_built_debris - 2, 2)
		_splinters.set_shader_parameter("per_shot", sp_per)
		_splinters.set_shader_parameter("splinter_len", debris_size * 3.6 * s)
		_splinters.set_shader_parameter("splinter_speed", debris_speed * 0.65 * s)
		_splinters.set_shader_parameter("splinter_life", debris_life * 1.25)
		_splinters.set_shader_parameter("gravity", 9.8 * s)
	if _sparks != null:
		_sparks.set_shader_parameter("per_shot", _built_sparks)
		_sparks.set_shader_parameter("spark_speed", spark_speed * s)
		_sparks.set_shader_parameter("spark_life", spark_life)
		_sparks.set_shader_parameter("spark_width", 0.016 * size * s)
		_sparks.set_shader_parameter("trail", 0.42 * s)
		_sparks.set_shader_parameter("gravity", 9.8 * s)
	if _core != null:
		_core.set_shader_parameter("per_shot", CORE_PER_SHOT)
		_core.set_shader_parameter("bloom_time", bloom_time)
		_core.set_shader_parameter("bloom_scale", bloom_scale * s)
		_core.set_shader_parameter("ring_scale", ring_scale)
		_core.set_shader_parameter("depth_offset", 0.004 * s)
	set_light_level(_light_now(), COL_LIGHT)


## Uploads the surface rows. Done once, not per hit: the rows are the same for every shot and
## a uniform array upload per round would undo the point of the slot ring.
func _push_rows() -> void:
	_rows_dirty = false
	var rows: Array[PackedVector4Array] = pack_rows()
	_longest = longest_duration()
	_row_light.resize(rows[3].size())
	_row_dur.resize(rows[3].size())
	for i in rows[3].size():
		_row_light[i] = rows[3][i].z
		_row_dur[i] = rows[3][i].w
	for k in layer_count():
		var m: ShaderMaterial = get_layer_material(k)
		if m == null:
			continue
		m.set_shader_parameter("surf_a", rows[0])
		m.set_shader_parameter("surf_b", rows[1])
		m.set_shader_parameter("surf_c", rows[2])
		m.set_shader_parameter("surf_d", rows[3])
		m.set_shader_parameter("surf_e", rows[4])


## Brightness of the impact light: the brightest live hit, scaled by that surface's own
## `light`, so a hit on wood barely lights the wall and a hit on steel does.
func _light_now() -> float:
	if not light_enabled:
		return 0.0
	var ring: MuzzluxShots = shots()
	var best: float = 0.0
	for i in ring.hard_cap:
		var a: Vector4 = ring.get_a(i)
		if a.w < -900.0:
			continue
		var c: Vector4 = ring.c[i]
		var age: float = get_time() - a.w - c.w
		if age < 0.0 or age > bloom_time * 1.6:
			continue
		if _row_light.is_empty():
			continue
		var idx: int = clampi(int(c.z), 0, _row_light.size() - 1)
		var lit: float = _row_light[idx]
		if lit <= 0.0:
			continue
		var t: float = age / maxf(bloom_time * 1.6, 0.0001)
		best = maxf(best, lit * (1.0 - t) * (1.0 - t) * ring.b[i].w)
	return best * effective_amount()
