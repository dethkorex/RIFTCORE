// MUZZLUX wood splinters. A round in a plank does not throw grit, it tears long thin pieces
// that spin end over end, and that tumble is most of what tells a buyer "that is wood" in a
// single frame. Drawn over MuzzluxMeshes.splinters(), which stands each wedge along +Y.
//
// This layer draws nothing for any hit whose crater style is not wood (3), so a manager that
// is hit on concrete, steel and wood in the same second only pays for the wood.
//
// Look 2 (2026-10-11): longer (3.6 x the chip size, was 3.1), thinner (0.16 of the length,
// was 0.22) and slower (0.65 x the chip speed, was 0.8), so the pieces stay inside the frame
// a hit is judged in and read as sticks rather than as grit; the dust row of `wood` is
// warmer too, so the puff is tan and not grey.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, shadows_disabled;

#include "res://addons/muzzlux_fx/shaders/muzzlux_noise.gdshaderinc"
#include "res://addons/muzzlux_fx/shaders/muzzlux_shots.gdshaderinc"
#include "res://addons/muzzlux_fx/shaders/muzzlux_surfaces.gdshaderinc"

uniform int seed = 1;
uniform float level = 1.0;
uniform int per_shot = 5;
// Length of a splinter in metres at strength 1.
uniform float splinter_len = 0.11;
// How thin it is, as a share of its length.
// The wedge mesh is 0.1..0.28 of its length wide already, so this is close to 1: at the
// first value (0.22) a splinter was under a centimetre wide and vanished at GIF size.
uniform float splinter_thin = 0.9;
uniform float splinter_speed = 3.4;
uniform float splinter_life = 0.95;
uniform float gravity = 9.8;
uniform vec4 col_debris : source_color = vec4(0.56, 0.38, 0.20, 1.0);

varying float v_fade;
varying float v_shade;
varying vec3 v_tint;

void vertex() {
	float element = mx_element(UV2);
	float per = float(max(per_shot, 1));
	int slot = mx_slot_of(element, per);
	float sub = element - floor(element / per) * per;
	MxShot s = mx_shot(slot);
	float age = mx_shot_age(s) - s.flags;
	MxSurface sf = mx_surface(s.surface);
	float salt = s.t0 * 11.03 + float(seed) * 0.031 + sub * 27.3;
	float amount = sf.chips * mx_is_style(sf.style, 3.0);
	float kept = step(sub, amount * per - 0.5);
	float life = splinter_life * (0.6 + 0.8 * mx_hash11(salt + 2.1));
	v_fade = 0.0;
	v_shade = 0.0;
	v_tint = sf.debris;
	if (age < 0.0 || age > life || amount <= 0.001 || kept < 0.5) {
		VERTEX = mx_hide();
	} else {
		vec3 n = normalize(length(s.dir) > 0.0001 ? s.dir : vec3(0.0, 1.0, 0.0));
		vec3 rnd = mx_unit_from_index(sub * 11.0 + 3.0, salt);
		vec3 dir = normalize(n + rnd * 0.62);
		float sp = splinter_speed * s.strength * (0.45 + 1.0 * mx_hash11(salt + 5.5));
		vec3 p = mx_free_flight(s.origin + n * 0.004, dir * sp, age, gravity * sf.gravity, 1.3);
		float t = age / max(life, 0.0001);
		// End over end around an axis across the splinter, not along it: a stick that spins
		// about its own length reads as a static needle.
		vec3 axis = normalize(cross(dir, rnd + vec3(0.07, 0.13, 0.05)));
		mat3 rot = mx_rot_axis(axis, age * (9.0 + 9.0 * mx_hash11(salt + 7.1)));
		float ln = splinter_len * s.size * s.strength * (0.6 + 0.8 * mx_hash11(salt + 3.7));
		// The mesh stands along +Y from 0 to 1, so the centre is pulled back half a length;
		// without that the splinter would spin around its blunt end.
		vec3 local = vec3(VERTEX.x * ln * splinter_thin, (VERTEX.y - 0.5) * ln,
			VERTEX.z * ln * splinter_thin);
		// Lay it down along its flight direction, then tumble.
		mat3 lay = mx_basis_from_normal(dir);
		VERTEX = p + rot * (lay * local);
		NORMAL = rot * (lay * NORMAL);
		v_fade = (1.0 - smoothstep(0.6, 1.0, t)) * level;
		// Lit from above and behind, as the chips are (muzzlux_impact_debris): the faces
		// the viewer sees are dark, so a splinter is a dark stick against the plank.
		vec3 to_cam = normalize(CAMERA_POSITION_WORLD - VERTEX);
		vec3 light = normalize(vec3(0.0, 0.7, 0.0) - to_cam * 0.9);
		v_shade = clamp(dot(normalize(rot * (lay * NORMAL)), light), -1.0, 1.0) * 0.5 + 0.5;
	}
}

void fragment() {
	// Wood is darker on its torn faces than on its surface; the UV.y of the wedge runs from
	// its base to its tip, so the tip is left paler as if it had split off clean.
	vec3 base = mix(v_tint * 0.7, mix(v_tint, col_debris.rgb, 0.3), UV.y);
	ALBEDO = base * (0.04 + 1.1 * v_shade * v_shade);
	ALPHA = clamp(v_fade, 0.0, 1.0);
}
