// MUZZLUX impact sparks: the white-hot streaks a round strikes off steel. Short-lived,
// curving, and bright enough to be the thing that tells a player "that was metal" - the one
// effect in the pack that is allowed to be pure additive light, because a real spark is a
// burning fleck of steel and has no dark side.
//
// Drawn over MuzzluxMeshes.strips(): each spark is a ribbon whose tail lags behind its head,
// so the curve of the flight shows as a curved streak instead of a straight line.
//
// `along` in the surface row is what makes a ricochet off a steel plate look different from a
// hit into a steel block: at along = 1 the fan lies in the plate's own plane and points the
// way the round skidded (the shot's roll; MuzzluxGun3D pins it for a glancing hit).
//
// Look 2 (2026-10-11): the first version's streaks were 6 mm wide with a 0.22 m trail and
// half gravity, which at any demo distance drew as a few short dashes. Now: wider head, a
// longer trail that thins to nothing, full gravity so the fan droops into arcs, a wider
// spread of speeds so some sparks die at the hit and some fly a metre, and a cold ramp for
// the few glints a glass hit throws (they take the surface's own dust colour instead of
// orange).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://addons/muzzlux_fx/shaders/muzzlux_noise.gdshaderinc"
#include "res://addons/muzzlux_fx/shaders/muzzlux_shots.gdshaderinc"
#include "res://addons/muzzlux_fx/shaders/muzzlux_surfaces.gdshaderinc"

uniform int seed = 1;
uniform float level = 1.0;
uniform int per_shot = 14;
uniform float spark_speed = 9.0;
uniform float spark_life = 0.42;
// Width of a streak at its head in metres.
uniform float spark_width = 0.011;
// Metres of trail behind the head at full speed.
uniform float trail = 0.42;
uniform float gravity = 9.8;
uniform vec4 col_core : source_color = vec4(1.0, 0.99, 0.96, 1.0);
uniform vec4 col_mid : source_color = vec4(1.0, 0.63, 0.20, 1.0);
uniform vec4 col_falloff : source_color = vec4(0.46, 0.12, 0.04, 1.0);
uniform float emission = 2.4;

varying float v_fade;
varying float v_heat;
varying float v_side;
varying vec3 v_mid;
varying vec3 v_fall;

void vertex() {
	float element = mx_element(UV2);
	float per = float(max(per_shot, 1));
	int slot = mx_slot_of(element, per);
	float sub = element - floor(element / per) * per;
	MxShot s = mx_shot(slot);
	float age = mx_shot_age(s) - s.flags;
	MxSurface sf = mx_surface(s.surface);
	float salt = s.t0 * 13.37 + float(seed) * 0.041 + sub * 19.7;
	float amount = sf.sparks;
	float kept = step(sub, amount * per - 0.5);
	// A wide spread of lives: a third of the sparks are gone in a tenth of a second, a few
	// fly for the whole life. That is what thins a fan out instead of switching it off.
	float life = spark_life * (0.25 + 1.15 * mx_hash11(salt + 1.3));
	// Below 0.6 of a row's worth of sparks they are cold glints (glass ships 0.5).
	float cold = 1.0 - step(0.6, amount);
	life *= mix(1.0, 1.5, cold);
	// Glass and the like throw a few cold glints, not burning steel: below half a row's
	// worth of sparks (0.6) the ramp runs through the surface's own colour (`cold` above).
	v_fade = 0.0;
	v_heat = 0.0;
	v_side = UV.x;
	v_mid = mix(col_mid.rgb, sf.dust, cold);
	v_fall = mix(col_falloff.rgb, sf.dust * 0.55, cold);
	if (age < 0.0 || age > life || amount <= 0.001 || kept < 0.5) {
		VERTEX = mx_hide();
	} else {
		vec3 n = normalize(length(s.dir) > 0.0001 ? s.dir : vec3(0.0, 1.0, 0.0));
		mat3 sb = mx_surface_basis(n, s.roll);
		vec3 rnd = mx_unit_from_index(sub * 13.0 + 7.0, salt);
		// The ricochet fan: along the plate, around the skid heading (the basis x axis),
		// about 35 degrees wide, with a little lift off the plate so it is not a line.
		vec3 fan = normalize(sb * vec3(1.0, rnd.y * 0.35, 0.1 + 0.3 * abs(rnd.z)));
		// The block hit: a cone off the surface, about 40 degrees half-angle. Wider and the
		// sparks of one hit are all over the next panel of a test wall; a round into a
		// steel block throws most of its sparks back along the normal anyway.
		vec3 out_dir = normalize(n + rnd * 0.8);
		vec3 dir = normalize(mix(out_dir, fan, clamp(sf.along, 0.0, 1.0)));
		// A glint of glass is a slow, short flick, not a jet of burning steel.
		// A ricochet fan is slower than the cone off a block: the round has lost most of
		// its energy skidding, and a fan that stays within half a metre of the hit is the
		// one a viewer can read as "it glanced off".
		float sp = spark_speed * s.strength * (0.25 + 1.1 * mx_hash11(salt + 3.1))
			* mix(1.0, 0.45, cold) * mix(1.0, 0.8, clamp(sf.along, 0.0, 1.0));
		// UV.y runs 0 at the tail to 1 at the head, so a vertex samples the flight at a time
		// a little behind the head. That is the whole trick: the ribbon traces the path the
		// spark actually took, curve and all, with no CPU work and no trail node.
		float lag = (1.0 - UV.y) * trail * mix(1.0, 0.3, cold) / max(sp, 0.001);
		float ta = max(age - lag, 0.0);
		vec3 p = mx_free_flight(s.origin + n * 0.004, dir * sp, ta, gravity, 2.2);
		// Width across the ribbon, turned to face the camera so it never goes edge-on. The
		// velocity at this point of the path, not the launch direction, so the ribbon stays
		// tangent to the arc gravity bends it into.
		vec3 vel = dir * sp * exp(-2.2 * ta) - vec3(0.0, gravity * ta, 0.0);
		vec3 to_cam = normalize(CAMERA_POSITION_WORLD - p);
		vec3 side = normalize(cross(normalize(vel + vec3(0.0001, 0.0, 0.0)), to_cam)
			+ vec3(0.0001, 0.0, 0.0));
		float w = spark_width * s.size * (0.6 + 0.8 * mx_hash11(salt + 9.1))
			* mix(0.15, 1.0, UV.y * UV.y);
		VERTEX = p + side * (UV.x - 0.5) * 2.0 * w;
		float t = age / max(life, 0.0001);
		// Bright from the first frame, then a fast fall: a spark cools, it does not fade in.
		v_fade = (1.0 - t) * (1.0 - t * 0.6) * level * clamp(amount, 0.0, 1.5);
		// Hottest at the head and at the start of the life.
		v_heat = clamp(UV.y * (1.0 - t * 0.7), 0.0, 1.0);
	}
}

void fragment() {
	// Across the ribbon: a hot line with a soft edge.
	float across = 1.0 - smoothstep(0.2, 1.0, abs(v_side - 0.5) * 2.0);
	vec3 c = mx_heat_ramp(v_heat, v_fall, v_mid, col_core.rgb);
	// `unshaded` ignores EMISSION, so the brightness goes into ALBEDO - and only into the
	// hot part, as in muzzlux_muzzle_flame: multiplying the whole ramp by `emission` clips
	// the mid orange to white and the spark loses its colour.
	ALBEDO = c * mix(1.3, emission, v_heat);
	ALPHA = clamp(across * v_fade, 0.0, 1.0);
}
