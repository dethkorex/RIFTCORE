// MUZZLUX impact core: the two things that sit exactly at the hit point.
//
//   sub 0  the bloom - a short bright flash the instant the round lands. `bloom` in the
//          surface row is its size in metres, and it is 0 for soil, sand and water, which
//          is correct: a round into wet mud does not flash.
//   sub 1  the ring - a circle that spreads *on* the hit surface. A water ripple, an energy
//          weapon's scorch, and a faint dust ring for the solid materials. `ring` and
//          `ring_speed` in the surface row drive it.
//
// Two quads per hit, one shader. The ring is aligned to the hit normal and pushed off the
// surface by the same measured offset the bullet holes use (step 0 probe (a): a normal
// offset alone is enough on every renderer; see muzzlux_holes.gdshader).
//
// Premultiplied alpha, for the same reason as the muzzle flash (step 7): a purely additive
// hit flash cannot be seen on a pale wall, and the white room demo scene is in the pack to
// prove that it can. The bloom's cool halo hides a little of the wall; its white middle does
// not. The ring stays effectively additive, because a ripple does not block anything.
shader_type spatial;
render_mode unshaded, blend_premul_alpha, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://addons/muzzlux_fx/shaders/muzzlux_noise.gdshaderinc"
#include "res://addons/muzzlux_fx/shaders/muzzlux_shots.gdshaderinc"
#include "res://addons/muzzlux_fx/shaders/muzzlux_surfaces.gdshaderinc"

uniform int seed = 1;
uniform float level = 1.0;
// Always 2: the bloom and the ring.
uniform int per_shot = 2;
// Seconds the bloom lasts. Short on purpose - this is a flash, not a fire.
uniform float bloom_time = 0.07;
// Multiplies every surface's bloom size.
uniform float bloom_scale = 1.0;
// Multiplies every surface's ring strength.
uniform float ring_scale = 1.0;
// How far off the surface the ring sits, metres. Measured in step 0 probe (a).
uniform float depth_offset = 0.004;
uniform vec4 col_core : source_color = vec4(1.0, 0.99, 0.96, 1.0);
uniform vec4 col_mid : source_color = vec4(1.0, 0.63, 0.20, 1.0);
uniform vec4 col_falloff : source_color = vec4(0.46, 0.12, 0.04, 1.0);
uniform float emission = 2.4;
// How much of the wall the cool edge of the hit flash hides, 0..1. See the note at the top.
uniform float soot = 0.45;

varying float v_fade;
varying float v_kind;
varying float v_edge;
varying vec3 v_tint;

void vertex() {
	float element = mx_element(UV2);
	float per = float(max(per_shot, 1));
	int slot = mx_slot_of(element, per);
	float sub = element - floor(element / per) * per;
	MxShot s = mx_shot(slot);
	float age = mx_shot_age(s) - s.flags;
	MxSurface sf = mx_surface(s.surface);
	float is_ring = step(0.5, sub);
	float ring_amount = sf.ring * ring_scale;
	float bloom_size = sf.bloom * bloom_scale * s.size * s.strength;
	// The ring lives much longer than the bloom: a ripple on water is still spreading long
	// after the splash itself has gone.
	float ring_life = max(sf.duration * 0.8, 0.2);
	float life = mix(bloom_time, ring_life, is_ring);
	float amount = mix(step(0.0001, bloom_size), ring_amount, is_ring);
	v_fade = 0.0;
	v_kind = is_ring;
	v_edge = 0.0;
	v_tint = sf.dust;
	if (age < 0.0 || age > life || amount <= 0.001) {
		VERTEX = mx_hide();
	} else {
		float t = age / max(life, 0.0001);
		vec3 n = normalize(length(s.dir) > 0.0001 ? s.dir : vec3(0.0, 1.0, 0.0));
		if (is_ring < 0.5) {
			// The bloom faces the camera and grows a little as it dies.
			vec3 p = s.origin + n * depth_offset;
			mat3 bb = mx_billboard_basis(p, CAMERA_POSITION_WORLD, s.roll);
			float sz = bloom_size * (0.75 + 0.6 * t);
			VERTEX = p + bb * vec3(VERTEX.x * sz, VERTEX.y * sz, 0.0);
			v_fade = mx_flash_curve(t, 0.18) * level;
		} else {
			// The ring lies on the surface and spreads outward. The quad is built at the
			// radius the ring has reached, so the band stays one pixel-ish wide instead of
			// growing thicker as it goes - that is what makes it read as a ripple.
			mat3 sb = mx_surface_basis(n, s.roll);
			float r = (0.06 + sf.ring_speed * ring_life * t) * s.size * s.strength;
			vec3 p = s.origin + n * depth_offset;
			VERTEX = p + sb * vec3(VERTEX.x * r * 2.0, VERTEX.y * r * 2.0, 0.0);
			v_fade = (1.0 - smoothstep(0.1, 1.0, t)) * level * clamp(ring_amount, 0.0, 1.5);
			// How wide the bright band is as a share of the radius. Thin from the first
			// frame: a wide band reads as a glowing donut rather than as a ripple, and that
			// donut was the loudest thing in the first screenshot of all nine hits.
			v_edge = clamp(0.12 / (1.0 + 3.0 * t), 0.03, 0.14);
		}
	}
}

void fragment() {
	vec2 p = UV - vec2(0.5);
	float r = length(p) * 2.0;
	float a;
	vec3 c;
	// How much of the wall this pixel hides. Only the bloom's cool edge does; the ring is a
	// ripple of light and hides nothing, so it stays at 0 and behaves exactly as before.
	float hide = 0.0;
	if (v_kind < 0.5) {
		// A colourless centre with the palette colour only in the falloff - the same rule as
		// the muzzle flash. A tinted hot centre stops a hit reading as a hit.
		float core = 1.0 - smoothstep(0.0, 0.55, r);
		float halo = 1.0 - smoothstep(0.2, 1.0, r);
		float h = clamp(core * 1.1, 0.0, 1.0);
		c = mx_heat_ramp(h, col_falloff.rgb, col_mid.rgb, col_core.rgb);
		c *= mix(0.9, emission, h * h);
		// Step 7: the halo used to be 0.35 across the whole quad, which on a 0.5 m test panel
		// washed concrete, metal, wood and glass into the same warm blob for the tenth of a
		// second a hit is brightest - exactly the frame a buyer judges "can I tell what I
		// shot". Down to 0.2, and the surface's own debris and dust carry the identity.
		a = clamp(core * 0.85 + halo * 0.2, 0.0, 1.0);
		hide = (1.0 - h) * soot;
	} else {
		// One band at the rim of the quad, broken up a little so it is not a perfect circle.
		float wob = 0.9 + 0.2 * mx_vnoise2(p * 9.0 + vec2(13.0, 7.0));
		float band = 1.0 - smoothstep(0.0, v_edge, abs(r * wob - 0.92));
		// Mostly the material's own dust colour, and well below white: this is additive, so
		// a ring near col_core blows out to a white circle on every material.
		c = mix(v_tint, col_core.rgb, 0.12) * 0.45;
		a = clamp(band, 0.0, 1.0);
	}
	float cover = clamp(a * v_fade, 0.0, 1.0);
	ALBEDO = c * cover;
	ALPHA = clamp(cover * hide, 0.0, 1.0);
}
