// MUZZLUX shot slots and ballistics. Include this in any shader that draws something a shot
// produced: the flash, the tracer, the impact, the debris, the casing.
//
// The ring is three uniform arrays written by MuzzluxShots (core/muzzlux_shots.gd):
//   shot_a[i] = vec4(origin.xyz, start_time)     start_time < -900 means "empty slot"
//   shot_b[i] = vec4(direction.xyz, strength)
//   shot_c[i] = vec4(roll, size, surface_id, flags)
// A slot is overwritten when the ring wraps, so an effect never allocates per shot and a
// held trigger costs the same as a single round.
//
// MX_SHOTS is the compile-time length of the arrays and the hard cap on `max_concurrent`.
// MuzzluxShots.SHOT_CAP must stay equal to it.

#include "res://addons/muzzlux_fx/shaders/muzzlux_place.gdshaderinc"

#define MX_SHOTS 32

uniform vec4 shot_a[MX_SHOTS];
uniform vec4 shot_b[MX_SHOTS];
uniform vec4 shot_c[MX_SHOTS];
// How many slots the ring currently walks through, 1..MX_SHOTS.
uniform int shot_capacity = 16;
// Seconds since the effect started, the same clock start_time is stamped with.
uniform float mx_time = 0.0;

struct MxShot {
	vec3 origin;
	vec3 dir;
	float t0;
	float strength;
	float roll;
	float size;
	float surface;
	float flags;
};

MxShot mx_shot(int i) {
	int k = clamp(i, 0, MX_SHOTS - 1);
	vec4 a = shot_a[k];
	vec4 b = shot_b[k];
	vec4 c = shot_c[k];
	MxShot s;
	s.origin = a.xyz;
	s.t0 = a.w;
	s.dir = b.xyz;
	s.strength = b.w;
	s.roll = c.x;
	s.size = c.y;
	s.surface = c.z;
	s.flags = c.w;
	return s;
}

// Seconds this shot has been alive, or -1 when the slot is empty or the shot is in the
// future. Every effect compares this against its own lifetime and draws nothing when it is
// out of range, which is how a degenerate quad is collapsed instead of being clipped.
float mx_shot_age(MxShot s) {
	if (s.t0 < -900.0) {
		return -1.0;
	}
	float age = mx_time - s.t0;
	return age < 0.0 ? -1.0 : age;
}

// Which slot an element belongs to. `per_shot` elements share one shot, so 48 chips over a
// 16-slot ring is 3 chips per impact.
int mx_slot_of(float element, float per_shot) {
	return int(floor(element / max(per_shot, 1.0))) % max(shot_capacity, 1);
}
