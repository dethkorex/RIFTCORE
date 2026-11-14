// MUZZLUX impact debris: the solid pieces a round knocks out. Concrete spall, metal flakes,
// clods of soil, grains of sand, water droplets and glass shards are all this one shader over
// MuzzluxMeshes.chips(), with the surface row deciding how many fly, how big they are
// (`debris_size`), how far they skid along the surface instead of leaving it, and how hard
// gravity pulls them down.
//
// Wood is the exception: it throws long splinters that spin, so it has a mesh and a shader of
// its own (muzzlux_impact_splinters). This layer skips any hit whose crater style is wood.
//
// Lit by a single fixed direction instead of the scene's lights, so a chip reads the same in
// a dark room and under a noon sun, on all three renderers, with nothing to set up.
//
// Look 2 (2026-10-11): the chips were 4.5 cm tetrahedra that drew as white grains. They are
// now stretched into angular shards (each its own aspect), a third larger, with a wider
// spread of sizes so a hit has two or three big chunks and a scatter of small ones; glass
// shards are flat plates that catch a specular glint as they turn (the "glitter"), water
// droplets are small and pale, soil clods are big and dark.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, shadows_disabled;

#include "res://addons/muzzlux_fx/shaders/muzzlux_noise.gdshaderinc"
#include "res://addons/muzzlux_fx/shaders/muzzlux_shots.gdshaderinc"
#include "res://addons/muzzlux_fx/shaders/muzzlux_surfaces.gdshaderinc"

uniform int seed = 1;
uniform float level = 1.0;
uniform int per_shot = 10;
// Longest edge of a chip in metres at strength 1, before the surface's debris_size.
uniform float chip_size = 0.06;
// Metres per second a chip leaves at.
uniform float chip_speed = 5.0;
// Seconds a chip lives. It fades over the last third.
uniform float chip_life = 0.9;
// Metres per second squared pulling the chips down, before the surface's own gravity.
uniform float gravity = 9.8;
uniform vec4 col_debris : source_color = vec4(0.62, 0.60, 0.56, 1.0);

varying float v_fade;
varying float v_shade;
varying float v_glint;
varying float v_glass;
varying vec3 v_tint;

void vertex() {
	float element = mx_element(UV2);
	float per = float(max(per_shot, 1));
	int slot = mx_slot_of(element, per);
	float sub = element - floor(element / per) * per;
	MxShot s = mx_shot(slot);
	float age = mx_shot_age(s) - s.flags;
	MxSurface sf = mx_surface(s.surface);
	float salt = s.t0 * 9.17 + float(seed) * 0.023 + sub * 31.1;
	// style 3 is wood; its splinters are drawn by the other layer.
	float is_wood = mx_is_style(sf.style, 3.0);
	float amount = sf.chips * (1.0 - is_wood);
	float kept = step(sub, amount * per - 0.5);
	float life = chip_life * (0.6 + 0.8 * mx_hash11(salt + 1.7));
	float is_glass = mx_is_style(sf.style, 4.0);
	v_fade = 0.0;
	v_shade = 0.0;
	v_glint = 0.0;
	v_glass = is_glass;
	v_tint = sf.debris;
	if (age < 0.0 || age > life || amount <= 0.001 || kept < 0.5) {
		VERTEX = mx_hide();
	} else {
		vec3 n = normalize(length(s.dir) > 0.0001 ? s.dir : vec3(0.0, 1.0, 0.0));
		mat3 sb = mx_surface_basis(n, s.roll);
		vec3 rnd = mx_unit_from_index(sub * 7.0 + 5.0, salt);
		// `along` turns the cone from "off the wall" into "across the wall": a round that
		// skips off a steel plate throws its flakes along the plate, not back at the shooter.
		vec3 flat_dir = normalize(sb * vec3(1.0, rnd.y * 0.8, 0.08 + 0.2 * abs(rnd.z)));
		vec3 out_dir = normalize(n + rnd * 0.8);
		vec3 dir = normalize(mix(out_dir, flat_dir, clamp(sf.along, 0.0, 1.0)));
		// Glass drops more than it flies: a plate of glass has no spring in it.
		float sp = chip_speed * s.strength * (0.35 + 1.15 * mx_hash11(salt + 4.9))
			* mix(1.0, 0.3, is_glass);
		// A short free flight with a little drag. No bounce: a chip fades before it lands,
		// and a shell casing is the thing in this pack that bounces.
		vec3 p = mx_free_flight(s.origin + n * 0.004, dir * sp, age,
			gravity * sf.gravity, 1.6);
		float t = age / max(life, 0.0001);
		// Tumble. Glass shards spin slower and flatter, which is what makes them read as
		// plates of glass falling rather than grit flying.
		float spin = mix(12.0, 5.0, is_glass) * (0.5 + mx_hash11(salt + 6.3));
		mat3 rot = mx_rot_axis(normalize(rnd + vec3(0.11, 0.07, 0.03)), age * spin);
		// Two or three big pieces and a scatter of small ones: the size spread is squared,
		// so most chips sit at the small end and a few jump to the top.
		float big = mx_hash11(salt + 2.9);
		float dsz = sf.debris_size > 0.01 ? sf.debris_size : 1.0;
		float sz = chip_size * s.size * s.strength * dsz * (0.4 + 1.3 * big * big);
		// An angular shard, not a grain: each chip has its own aspect.
		vec3 local = VERTEX * sz
			* vec3(1.0 + 0.9 * mx_hash11(salt + 5.1), 0.55 + 0.5 * mx_hash11(salt + 7.7), 1.0);
		local.z *= mix(1.0, 0.22, is_glass);
		VERTEX = p + rot * local;
		vec3 wn = normalize(rot * NORMAL);
		NORMAL = wn;
		v_fade = (1.0 - smoothstep(0.65, 1.0, t)) * level;
		// One light, from above and from behind the chip as seen from the camera. The faces
		// a viewer sees are then the shadowed ones, and a chip reads as a dark fleck with a
		// lit top edge against any wall - which is how debris reads in life (it is a
		// silhouette against the lit surface it came off). The first version lit it from
		// the camera's side, and every chip was a pale grain.
		vec3 to_cam = normalize(CAMERA_POSITION_WORLD - VERTEX);
		vec3 light = normalize(vec3(0.0, 0.7, 0.0) - to_cam * 0.9);
		v_shade = clamp(dot(wn, light), -1.0, 1.0) * 0.5 + 0.5;
		// The glint: the mirror of the light towards the camera. Only glass is polished
		// enough to flash; other debris keeps a faint sheen.
		vec3 refl = reflect(-light, wn);
		v_glint = pow(max(dot(refl, to_cam), 0.0), 14.0);
	}
}

void fragment() {
	vec3 base = mix(v_tint, col_debris.rgb, 0.25);
	// A wide range between the dark and the lit face: a chip is a solid, and the only thing
	// that says so in one frame is its own shading.
	// Linear light: the face the viewer sees has to go down to a few percent to show
	// as a dark fleck on screen against a mid-grey wall.
	vec3 c = base * (0.02 + 1.1 * v_shade * v_shade);
	// A plate of glass is lit through: pale on both sides, and the glint on top of that.
	c = mix(c, base * 0.8, v_glass * 0.85);
	// Glass: a pale plate with a hard white flash when it catches the light, and a little
	// see-through, so the shards glitter as they fall instead of reading as grey grit.
	float flash = v_glint * mix(0.25, 0.8, v_glass);
	c = mix(c, vec3(1.0), clamp(flash, 0.0, 1.0));
	ALBEDO = c;
	ALPHA = clamp(v_fade * mix(1.0, 0.9 + 0.2 * v_glint, v_glass), 0.0, 1.0);
}
