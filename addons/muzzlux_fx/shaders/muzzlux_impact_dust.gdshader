// MUZZLUX impact dust: the cloud a round throws off the material it hit. One shader draws all
// nine of them, because the difference between a cone of concrete powder, a column of soil, a
// low puff of sand, a thin jet of water and a grey mist is three numbers in the surface row
// (`dust_amount`, `dust_rise`, `gravity`), not a branch and not a second node.
//
// Normal blending and a low render priority on purpose: this is the layer that gives the
// bright part of a hit a dark edge, which is what lets an impact read on a white wall with no
// glow post-process anywhere in the pack.
//
// Look 2 (2026-10-11): the first version was a radial falloff times a little noise, and on
// screen every puff was a white disc - the "cluster of round blobs" the user rejected. A puff
// is now a *noise-shaped* billow: the radius itself is pushed in and out by fBm so the outline
// is lumpy, the inside has dense and thin parts, and a fixed light direction gives it a lit
// top and a shadowed underside, so it reads as a volume. Columns (soil, water) stretch their
// quads along world up and keep the roll at zero; hanging puffs (sand, powder) stay round.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://addons/muzzlux_fx/shaders/muzzlux_noise.gdshaderinc"
#include "res://addons/muzzlux_fx/shaders/muzzlux_shots.gdshaderinc"
#include "res://addons/muzzlux_fx/shaders/muzzlux_surfaces.gdshaderinc"

uniform int seed = 1;
uniform float level = 1.0;
// Puffs per hit. The mesh holds shot_capacity * per_shot quads.
uniform int per_shot = 8;
// Size of one puff in metres at strength 1, before the surface row scales it.
uniform float puff_size = 0.3;
// Metres per second a puff leaves the surface at.
uniform float puff_speed = 1.9;
// Multiplies every surface's dust_amount, so a buyer can thin the whole thing down.
uniform float dust_scale = 1.0;
uniform vec3 wind = vec3(0.0, 0.0, 0.0);
uniform vec4 col_smoke : source_color = vec4(0.58, 0.57, 0.55, 0.42);

varying float v_fade;
varying float v_grain;
varying float v_age;
varying float v_rise;
varying vec3 v_tint;

void vertex() {
	float element = mx_element(UV2);
	float per = float(max(per_shot, 1));
	int slot = mx_slot_of(element, per);
	float sub = element - floor(element / per) * per;
	MxShot s = mx_shot(slot);
	// s.flags is this node's delay: the gun pushes the hit the moment it fires and lets the
	// shader hold it back until the round has flown, so a tracer in the air costs no CPU.
	float age = mx_shot_age(s) - s.flags;
	MxSurface sf = mx_surface(s.surface);
	float salt = s.t0 * 5.31 + float(seed) * 0.013 + sub * 13.7;
	float amount = sf.dust_amount * dust_scale;
	float rise = clamp(sf.dust_rise, 0.0, 1.0);
	float life = sf.duration * (0.55 + 0.75 * mx_hash11(salt));
	v_fade = 0.0;
	v_grain = 0.0;
	v_age = 0.0;
	v_rise = rise;
	v_tint = sf.dust;
	// One puff of the set is dropped as `amount` falls, so a sand hit shows all of them and a
	// metal hit (0.3) shows two or three. Checked against sub, not against a random, so the
	// same hit always drops the same puffs.
	float kept = step(sub, amount * per - 0.5);
	if (age < 0.0 || age > life || amount <= 0.001 || kept < 0.5) {
		VERTEX = mx_hide();
	} else {
		float t = age / max(life, 0.0001);
		vec3 n = normalize(length(s.dir) > 0.0001 ? s.dir : vec3(0.0, 1.0, 0.0));
		vec3 up = vec3(0.0, 1.0, 0.0);
		// A cone around the hit normal, tightened as dust_rise goes up: concrete powder
		// spreads wide off the wall, a water jet is a narrow column.
		vec3 rnd = mx_unit_from_index(sub * 3.0 + 1.0, salt + s.roll);
		float spread = mix(1.3, 0.14, rise);
		vec3 cone = normalize(n + rnd * spread);
		// A low cloud (sand, powder) spreads sideways and settles rather than climbing: its
		// up component is squashed, so the burst is wider than it is tall. A column keeps it.
		cone.y *= mix(0.15, 1.0, rise);
		cone = normalize(cone);
		vec3 dir = normalize(mix(cone, up, rise * 0.85));
		// The puffs of a column leave at staggered speeds so they string out along it; the
		// puffs of a hanging cloud leave at nearly the same speed and stay a cloud.
		float stagger = mix(0.5 + 0.8 * mx_hash11(salt + 3.3),
			0.3 + 1.3 * (sub + 0.5) / per, rise);
		float sp = puff_speed * s.strength * stagger * mix(0.7, 1.3, rise);
		// Slows down as it expands, then the wind carries it. The rise-and-fall of a column
		// of soil is the same formula with gravity left in; powder settles slowly.
		float travel = sp * life * (1.0 - exp(-t * 2.4)) / 2.4;
		vec3 p = s.origin + dir * travel + wind * (age * 0.6);
		p.y -= 0.5 * mix(0.45, 2.2, rise) * sf.gravity * age * age;
		// The roll stays within a few degrees of zero for every puff: the quad's +y is world
		// up, so the stretch below stands a column up and, more important, the lit top and
		// the shadowed underside painted in fragment() stay the right way up. The first
		// version rolled hanging puffs at random, and a cloud lit from a different side in
		// every puff has no underside at all, which is why nothing dark survived on a white
		// wall. Variety comes from the noise offsets instead.
		float roll = (mx_hash11(salt + 21.7) - 0.5) * 0.5 * (1.0 - rise);
		mat3 bb = mx_billboard_basis(p, CAMERA_POSITION_WORLD, roll);
		// Two thirds of its size on the first frame and nearly triple by the end: dust
		// does not grow into existence, and the brightest frame of the hit is the one that
		// has to read against a wall.
		// `col` is how much of a column this is, `low` how much of a hanging cloud: a
		// column's puffs are narrow and stand up (soil, water), a cloud's are a little
		// wider than tall (sand, powder); in between (rise 0.2..0.4) they are round.
		float col = smoothstep(0.4, 1.0, rise);
		float low = 1.0 - smoothstep(0.0, 0.35, rise);
		float sz = puff_size * s.size * s.strength * (0.55 + 0.9 * t)
			* (0.65 + 0.7 * mx_hash11(salt + 8.1)) * mix(1.0, 0.55, col);
		vec2 stretch = vec2(mix(1.0, 1.35, low), mix(1.0, 2.6, col) * mix(1.0, 0.65, low));
		VERTEX = p + bb * vec3(VERTEX.x * sz * stretch.x, VERTEX.y * sz * stretch.y, 0.0);
		// Hangs, then thins. `sand` is the extreme: a long duration and a late fade, which is
		// what "a low puff that hangs and drifts" means in numbers.
		float hold = mix(0.12, 0.6, 1.0 - rise);
		v_fade = (1.0 - smoothstep(hold, 1.0, t)) * level * clamp(amount, 0.0, 1.5)
			* smoothstep(0.0, 0.05, t);
		v_grain = mx_hash11(salt + 17.3);
		v_age = age;
	}
}

void fragment() {
	vec2 p = UV - vec2(0.5);
	float r = length(p) * 2.0;
	// The outline: the radius is pushed in and out by low-frequency noise that drifts with
	// age, so the edge is lumpy and slowly boils instead of staying a circle.
	float lump = mx_fbm(vec3(p * 2.3 + v_grain * 9.0, v_age * 0.7 + v_grain * 3.0), 3);
	float rr = r + (lump - 0.5) * 0.7;
	float shape = 1.0 - smoothstep(0.3, 0.86, rr);
	// The inside: dense and thin parts, finer than the outline.
	float grain = mx_fbm(vec3(p * 4.6 + v_grain * 23.0, v_age * 1.1), 3);
	float dens = smoothstep(0.22, 0.7, grain);
	// One fixed light from the top left: a lit cap and a shadowed underside. That gradient
	// is what makes a flat quad read as a volume of dust, and the shadowed side is the
	// dark edge the hit needs against a white wall.
	// A column (v_rise near 1) is lit from above, so more of each tall puff is underside.
	float lit = clamp(0.5 + 1.1 * (p.y * mix(0.9, 1.4, v_rise) - p.x * 0.3) - 0.3 * r,
		0.08, 1.0);
	// The figures are linear light (the shader output is converted to sRGB on the way to
	// the screen): a lit top of half the row colour is already a pale 0.7 on screen, and
	// the underside has to go down to a twentieth of it to read as dark against a wall
	// that is itself a mid grey. Measured in look 2: at 0.3 x the "shadow" of concrete
	// powder was brighter on screen than the dim-range panel it was in front of.
	vec3 shadow = v_tint * 0.04 + col_smoke.rgb * 0.015;
	vec3 c = mix(shadow, v_tint * 0.5, clamp(lit * (0.4 + 0.6 * dens), 0.0, 1.0));
	ALBEDO = c;
	ALPHA = clamp(shape * (0.3 + 0.7 * dens) * v_fade * 0.8, 0.0, 0.85);
}
