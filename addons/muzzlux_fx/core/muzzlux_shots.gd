class_name MuzzluxShots
extends RefCounted
## The per-hit slot ring every MUZZLUX effect draws from.
##
## Lite version: the two longer rings the full pack keeps (128 bullet holes and 64 shell
## cases, both measured against the renderers' uniform-array limits in step 0) are not here,
## because neither of those effects is.
##
## A shot is three `vec4`s. They live in uniform arrays that the vertex shader reads, so
## firing is two or three array writes and **nothing is instanced, allocated or stepped on
## the CPU per shot**. Slot `capacity` wraps around: shot 17 of a 16-slot ring overwrites
## slot 1, which is why full auto neither allocates nor stutters.
##
## The uniform arrays are always uploaded at their full `hard_cap` length, because a shader's
## array size is fixed when it compiles. `capacity` only decides how far the ring walks
## before it wraps, so `max_concurrent` can be changed at runtime without a recompile.
##
## Slot layout, matching muzzlux_shots.gdshaderinc:
##   a = vec4(origin.xyz, start_time)
##   b = vec4(direction.xyz, strength)
##   c = vec4(roll, size, surface_id, flags)

## Hard cap for a shot ring. The shader include declares its arrays at this size.
const SHOT_CAP: int = 32

var capacity: int = 16
var hard_cap: int = SHOT_CAP
var a: PackedVector4Array = PackedVector4Array()
var b: PackedVector4Array = PackedVector4Array()
var c: PackedVector4Array = PackedVector4Array()

var _next: int = 0
var _pushed: int = 0
var _revision: int = 0


func _init(p_capacity: int = 16, p_hard_cap: int = SHOT_CAP) -> void:
	hard_cap = maxi(p_hard_cap, 1)
	a.resize(hard_cap)
	b.resize(hard_cap)
	c.resize(hard_cap)
	set_capacity(p_capacity)
	clear()


## Changes how many slots the ring walks through. Clamped to 1..hard_cap.
func set_capacity(p_capacity: int) -> void:
	var want: int = clampi(p_capacity, 1, hard_cap)
	if want == capacity:
		return
	capacity = want
	_next = _next % capacity
	_revision += 1


## Zeroes every slot. `start_time` of -1000 keeps a slot out of the way: every effect's
## shader treats a shot older than its own lifetime as finished.
func clear() -> void:
	for i in hard_cap:
		a[i] = Vector4(0.0, 0.0, 0.0, -1000.0)
		b[i] = Vector4(0.0, 0.0, -1.0, 0.0)
		c[i] = Vector4(0.0, 1.0, 0.0, 0.0)
	_next = 0
	_pushed = 0
	_revision += 1


## Writes one shot and returns the slot it went into.
func push(origin: Vector3, direction: Vector3, start_time: float, strength: float = 1.0,
		roll: float = 0.0, size: float = 1.0, surface_id: float = 0.0,
		flags: float = 0.0) -> int:
	var i: int = _next
	a[i] = Vector4(origin.x, origin.y, origin.z, start_time)
	b[i] = Vector4(direction.x, direction.y, direction.z, strength)
	c[i] = Vector4(roll, size, surface_id, flags)
	_next = (i + 1) % capacity
	_pushed += 1
	_revision += 1
	return i


## Overwrites one slot that was already pushed, for a shot whose end point is only known
## later (a tracer that has arrived, a hole that is fading out).
func write(slot: int, p_a: Vector4, p_b: Vector4, p_c: Vector4) -> void:
	if slot < 0 or slot >= hard_cap:
		return
	a[slot] = p_a
	b[slot] = p_b
	c[slot] = p_c
	_revision += 1


func get_a(slot: int) -> Vector4:
	return a[slot] if slot >= 0 and slot < hard_cap else Vector4.ZERO


## Slots that hold a shot right now: everything after the ring has wrapped once.
func live_count() -> int:
	return mini(_pushed, capacity)


## Every push since the last clear(), so a test can see that nothing leaked.
func pushed_total() -> int:
	return _pushed


## The slot the next push() will use.
func next_slot() -> int:
	return _next


## Moves every live slot's start time by `delta`. The effect clock wraps once an hour; without
## this the shots already in the ring would look like they are in the future and blink out.
func shift_time(delta: float) -> void:
	for i in hard_cap:
		var s: Vector4 = a[i]
		if s.w > -900.0:
			a[i] = Vector4(s.x, s.y, s.z, s.w + delta)
	_revision += 1


## Goes up on every write. An effect uploads the arrays only when this changed, so a frame
## with no new shot costs no uniform traffic at all.
func revision() -> int:
	return _revision


## Uploads the three arrays and the ring length to one material.
func apply_to(mat: ShaderMaterial) -> void:
	apply_to_named(mat, "shot")


## The same, under another uniform name, for a shader whose arrays are not called shot_*.
func apply_to_named(mat: ShaderMaterial, prefix: String) -> void:
	mat.set_shader_parameter(prefix + "_a", a)
	mat.set_shader_parameter(prefix + "_b", b)
	mat.set_shader_parameter(prefix + "_c", c)
	mat.set_shader_parameter(prefix + "_capacity", capacity)
