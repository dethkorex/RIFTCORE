// Billboard puffs of a blast: the fireball that cools into smoke, the smoke itself and the
// dust the blast lifts off the ground. One quad per puff; the element index, the seed and the
// burst age give every position, so the mesh never changes. Premultiplied alpha: the hot puffs
// add light, the smoke and dust cover.
shader_type spatial;
render_mode unshaded, blend_premul_alpha, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

#include "res://addons/blastlux_fx/shaders/blastlux_noise.gdshaderinc"

uniform int seed = 1;
uniform float time = 0.0;
uniform float level = 1.0;
uniform float age = -1.0;
uniform vec3 em_origin;
uniform vec3 em_x = vec3(1.0, 0.0, 0.0);
uniform vec3 em_y = vec3(0.0, 1.0, 0.0);
uniform vec3 em_z = vec3(0.0, 0.0, 1.0);
uniform vec3 wind;
uniform float pixel_angle = 0.002;

// 0 = one-shot burst driven by `age`, 1 = loop driven by `time` (smoke columns).
uniform int mode = 0;
// 0 fireball (hot, cools to smoke), 1 smoke, 2 dust (ground skirt, flat and wide).
uniform int kind = 0;
// 0 sphere, 1 flat ring on the ground, 2 column (a tall thin box).
uniform int shape = 0;
uniform float shape_size = 0.5;
uniform vec3 spawn_offset;
uniform float lifetime = 1.6;
uniform float lifetime_var = 0.35;
uniform float spawn_window = 0.05;
uniform float delay = 0.0;
uniform float speed = 6.0;
uniform float speed_var = 0.45;
// 0 hemisphere up, 1 full sphere, 2 outward along the ground, 3 straight up.
uniform int spread_mode = 0;
uniform float spread = 0.8;
uniform float drag = 4.0;
uniform float buoyancy = 1.2;
uniform float turbulence = 0.2;
uniform float ground_y = -100000.0;
uniform float size_start = 0.5;
uniform float size_end = 1.2;
uniform float size_var = 0.35;
uniform float size_curve = 0.4;
uniform float spin = 0.8;
uniform float heat = 1.3;
uniform float heat_var = 0.3;
uniform float cool_rate = 1.4;
uniform float opacity = 0.85;
uniform float fade_in = 0.03;
uniform float fade_out = 0.45;
uniform float erosion = 0.5;
uniform float noise_scale = 1.4;
uniform float softness = 0.45;
uniform float intensity = 1.0;
// Burst only: pull the puffs into a stem and a rolling cap.
uniform float mushroom = 0.0;
uniform float mushroom_height = 6.0;
// Light from the fire below that keeps the underside of smoke lit after the puff itself has
// cooled (a rolling cap, a flak puff at night): strength and the seconds it takes to die down.
uniform float under_glow = 0.0;
uniform float under_glow_time = 1.5;
// A faint pale rim on the edge of a smoke puff, so a dark cloud still reads against a night sky.
uniform float rim = 0.0;
// Multiplier on the smoke grey (a cap lit by the moon is lighter than a ground puff).
uniform float smoke_lift = 1.0;
// Fire only: flame tongues licking out of the edge of each puff (0 = round) and how hard the
// edge of the opaque core is (0 = soft, 1 = a crisp silhouette).
uniform float tongue = 1.0;
uniform float hard_edge = 1.0;
// Fire only: how opaque the hot core is (a gas flash is a thin sheet you see through).
uniform float fire_alpha = 0.95;
// 1 = cartoon: flat colour steps and a dark outline, round puffs, no noise in the body.
uniform int toon = 0;

uniform vec4 col_core = vec4(1.0, 0.93, 0.7, 1.0);
uniform vec4 col_hot = vec4(1.0, 0.5, 0.1, 1.0);
uniform vec4 col_cool = vec4(0.75, 0.14, 0.02, 1.0);
uniform vec4 col_smoke = vec4(0.17, 0.15, 0.14, 0.85);
uniform vec4 col_dust = vec4(0.42, 0.36, 0.28, 0.8);
uniform float emission = 2.4;

varying vec2 v_q;
varying vec3 v_seed;
varying float v_heat;
varying float v_env;
varying float v_f;
varying vec2 v_light;
varying float v_tt;

vec3 spawn_local(vec4 h) {
	if (shape == 1) {
		float a = h.y * BX_TAU;
		return vec3(cos(a), 0.0, sin(a)) * shape_size * (0.6 + 0.4 * h.x) + vec3(0.0, (h.z - 0.5) * shape_size * 0.2, 0.0);
	} else if (shape == 2) {
		return vec3((h.x - 0.5) * shape_size * 0.5, h.z * shape_size * 2.0, (h.y - 0.5) * shape_size * 0.5);
	}
	float u = h.x * 2.0 - 1.0;
	float a = h.y * BX_TAU;
	float s = sqrt(max(1.0 - u * u, 0.0));
	return vec3(s * cos(a), u, s * sin(a)) * shape_size * pow(h.z, 0.33);
}

void vertex() {
	uint idx = uint(VERTEX.x + 0.5);
	vec4 r = bx_rand4(idx, uint(seed), 0u);
	vec4 r2 = bx_rand4(idx, uint(seed), 1u);
	float s = (length(em_x) + length(em_y) + length(em_z)) / 3.0;
	mat3 B = mat3(em_x, em_y, em_z);
	vec3 up = vec3(0.0, 1.0, 0.0);
	float life = lifetime * (1.0 + (r.x * 2.0 - 1.0) * lifetime_var);
	float t;
	float f;
	float alive;
	uint key = idx;
	if (mode == 1) {
		float ph = time / life + r.y;
		float cyc = floor(ph);
		f = fract(ph);
		t = f * life;
		key = idx * 7919u + uint(int(mod(cyc, 65536.0)));
		vec4 hc = bx_rand4(key, uint(seed), 5u);
		alive = smoothstep(hc.w - 0.08, hc.w + 0.02, level);
	} else {
		float start = delay + r.y * spawn_window;
		t = age - start;
		f = t / max(life, 0.001);
		alive = (age >= 0.0 && t >= 0.0 && f < 1.0) ? 1.0 : 0.0;
	}
	vec4 h = bx_rand4(key, uint(seed), 2u);
	vec4 h2 = bx_rand4(key, uint(seed), 3u);
	vec3 local0 = spawn_local(h) + spawn_offset;
	vec3 p0 = em_origin + B * local0;
	float u = h2.x * 2.0 - 1.0;
	float a = h2.y * BX_TAU;
	float sq = sqrt(max(1.0 - u * u, 0.0));
	vec3 rd = vec3(sq * cos(a), u, sq * sin(a));
	vec3 dir;
	if (spread_mode == 1) {
		dir = rd;
	} else if (spread_mode == 2) {
		vec2 radial = normalize(local0.xz + vec2(h2.x - 0.5, h2.y - 0.5) * 0.001);
		dir = normalize(vec3(radial.x, (h2.z - 0.35) * spread, radial.y));
	} else if (spread_mode == 3) {
		dir = normalize(up + rd * spread * 0.3);
	} else {
		dir = normalize(mix(up, vec3(rd.x, abs(rd.y), rd.z), spread));
	}
	float spd = speed * (1.0 + (h2.z * 2.0 - 1.0) * speed_var) * s;
	vec3 v0 = normalize(B * dir) * spd;
	float tt = max(t, 0.0);
	vec3 p = p0 + v0 * bx_drag_dist(tt, drag);
	p += up * buoyancy * s * 0.5 * tt * tt / (1.0 + drag * tt * 0.5);
	p += wind * tt * min(tt * 2.0, 1.0);
	p += bx_curl(p0 * 1.3 / s + vec3(0.0, -tt * 0.6, 0.0) + r2.xyz * 13.0) * turbulence * s * tt;
	if (mode == 0 && mushroom > 0.0) {
		float H = mushroom_height * s * (1.0 - exp(-tt / 1.1));
		vec3 pm;
		float am = h.y * BX_TAU;
		vec3 radial = cos(am) * normalize(em_x) + sin(am) * normalize(em_z);
		if (r2.w < 0.32) {
			pm = em_origin + up * H * h.x * 0.9 + radial * H * (0.05 + 0.07 * h.z);
		} else {
			float R = H * 0.42;
			float rr = H * 0.24 * (0.55 + 0.45 * h.z);
			float th = h.x * BX_TAU + tt * 1.6;
			pm = em_origin + up * (H + sin(th) * rr) + radial * (R + cos(th) * rr);
		}
		pm += wind * tt * 0.5;
		p = mix(p, pm, smoothstep(0.0, 0.9, tt) * mushroom);
	}
	float sz = mix(size_start, size_end, pow(clamp(f, 0.0, 1.0), size_curve)) * s * (1.0 + (r2.z * 2.0 - 1.0) * size_var);
	if (mode == 1) {
		sz *= mix(0.55, 1.0, level);
	}
	// A fire puff sits on the floor, not half under it: the floor used to cut its billboard to a
	// flat-bottomed block (2026-10-31 blind check). Dust and smoke may hug the ground.
	p.y = max(p.y, ground_y + sz * (kind == 0 ? 0.6 : 0.25));

	float temp = heat * (1.0 + (r2.y * 2.0 - 1.0) * heat_var) - cool_rate * tt;
	v_heat = temp;
	v_tt = tt;
	v_f = clamp(f, 0.0, 1.0);
	v_env = alive * smoothstep(0.0, max(fade_in, 0.001), f) * (1.0 - smoothstep(1.0 - fade_out, 1.0, f));
	v_seed = vec3(r.zw * 37.0, r2.x * 19.0);

	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 to_cam = cam - p;
	float dist = max(length(to_cam), 0.001);
	float w = max(sz, dist * pixel_angle * 1.5);
	v_env *= clamp(sz / w, 0.0, 1.0) * smoothstep(0.25 * s, 0.75 * s, dist);
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	vec3 vup = INV_VIEW_MATRIX[1].xyz;
	vec2 c = UV * 2.0 - 1.0;
	float ang = r.z * BX_TAU + spin * tt * (r2.x * 2.0 - 1.0);
	float ca = cos(ang);
	float sa = sin(ang);
	vec2 rc = vec2(c.x * ca - c.y * sa, c.x * sa + c.y * ca);
	vec3 offs = right * rc.x * w + vup * rc.y * w;
	vec2 wu = vec2(dot(up, right), dot(up, vup));
	v_light = vec2(wu.x * ca + wu.y * sa, -wu.x * sa + wu.y * ca);
	v_q = c;
	VERTEX = alive > 0.0 ? p + offs : em_origin;
	NORMAL = to_cam / dist;
}

void fragment() {
	vec2 q = v_q;
	vec3 nc = vec3(q * noise_scale + v_seed.xy, v_seed.z + time * 0.35);
	vec2 warp = vec2(bx_vnoise(nc * 0.9), bx_vnoise(nc * 0.9 + 7.3)) - 0.5;
	vec2 qw = q + warp * 0.6;
	float n = bx_fbm(nc + vec3(warp * 1.5, 0.0), 3);
	float d = length(qw);
	if (toon == 1) {
		d = length(q) * (0.82 + 0.2 * bx_vnoise(vec3(q * 1.6 + v_seed.xy, v_seed.z)));
	} else if (kind == 0 && tongue > 0.0) {
		// Flame tongues: the outline is pushed out in a few narrow lobes that lean upward and
		// crawl, so a fireball has a licking, torn edge instead of a cotton-ball rim.
		float ang = atan(q.y, q.x);
		float lobes = bx_fbm(vec3(cos(ang) * 2.6 + v_seed.x, sin(ang) * 2.6 + v_seed.y, v_seed.z + v_tt * 2.2), 3);
		float lick = smoothstep(0.42, 0.85, lobes);
		lick = lick * sqrt(lick) * (0.65 + 0.55 * smoothstep(-0.4, 0.9, q.y));
		d = d / (1.0 + tongue * 0.55 * lick * smoothstep(0.25, 0.7, v_heat));
	}
	float base = smoothstep(0.0, softness + 0.01, clamp(1.0 - d, 0.0, 1.0));
	float v = base * (0.25 + n * 1.25);
	float th = 0.22 + erosion * v_f * 0.5;
	float dens = smoothstep(th, th + 0.55, v);
	// Smoke puffs are filled lumps: a lower, softer threshold and a fuller alpha profile, so a
	// cloud of them reads as one mass and not as rings or cauliflower (2026-10-31 blind check 2).
	float v_s = base * (0.5 + n * 0.9);
	float th_s = 0.14 + erosion * v_f * 0.35;
	float dens_s = smoothstep(th_s, th_s + 0.4, v_s);
	float env = v_env;

	// Fake lighting on the puff: the side toward world up is lit.
	// A blurred normal: the puff is lit as a soft mound, not as a hard sphere with a dark rim.
	vec3 nq = normalize(vec3(qw * 0.5, sqrt(max(1.0 - 0.3 * d * d, 0.0))));
	vec3 L = normalize(vec3(v_light, 0.6));
	float lit = clamp(dot(nq, L) * 0.5 + 0.5, 0.0, 1.0);

	vec3 cool = bx_lin(col_cool.rgb);
	vec3 hot = bx_lin(col_hot.rgb);
	vec3 core = bx_lin(col_core.rgb);
	vec3 smoke_c = bx_lin(col_smoke.rgb) * smoke_lift;
	vec3 dust_c = bx_lin(col_dust.rgb);
	vec3 rim_c = bx_lin(vec3(0.5, 0.54, 0.62));
	float under_k = under_glow * exp(-v_tt / max(under_glow_time, 0.01));
	float rim_k = rim * smoothstep(0.5, 0.95, d) * (0.5 + 0.5 * n) * lit;
	vec3 under_c = mix(hot, vec3(0.5, 0.25, 0.08), 0.35);

	// The centre of a hot puff stays yellow while its edge cools to orange, so a fireball reads
	// as fire and not as a flat red shape (2026-10-31 blind check).
	float hp = (v_heat + 0.45 * (1.0 - d) * smoothstep(0.2, 1.0, v_heat)) * (0.35 + 0.75 * dens) * (0.7 + 0.5 * n);
	// The cool end of the ramp leans orange and the dim end fades out instead of lingering as a
	// red glow: a cooling puff turns into grey smoke, not a red cotton ball (2026-10-31).
	vec3 cool_c = mix(cool, hot, 0.55);
	vec3 flame = bx_ramp(clamp(hp, 0.0, 1.1), cool_c, hot, core) * emission * intensity * dens * smoothstep(0.12, 0.5, hp);
	float shade = mix(0.6, 1.1, lit) * (0.65 + 0.7 * n);
	// `add` is light the puff adds (premultiplied by nature); `cover` is the colour of what it
	// hides, with coverage `a`. The colour-space conversion happens before the premultiply.
	vec3 add = vec3(0.0);
	vec3 cover = vec3(0.0);
	float a = 0.0;
	if (kind == 1) {
		// Smoke: a dark grey, not black; the side toward the ground is lit by the fireball while
		// the puff is still warm, and the edge thins out.
		float shade_s = mix(1.25, 1.75, lit) * (0.7 + 0.6 * n);
		float under = 1.0 - lit;
		float fire_lit = (smoothstep(0.05, 0.3, v_heat) + under_k) * (0.12 + 0.88 * under * under);
		cover = smoke_c * shade_s + under_c * fire_lit * 0.16;
		cover = mix(cover, rim_c * (0.6 + 0.6 * n), rim_k);
		float edge = smoothstep(0.0, 0.7, 1.0 - d);
		a = dens_s * col_smoke.a * opacity * mix(0.6, 1.0, edge) * (1.0 + 0.4 * exp(-v_tt * 1.5));
		// Compatibility composites in sRGB space, where stacked dark covers come out as a pale
		// haze (smoke mean 72 against 52 on Forward+, 2026-10-31): the cover is darkened there.
		if (OUTPUT_IS_SRGB) {
			// Only dark smoke stacks into a haze; a white mist or a green cloud keeps its colour.
			cover *= mix(0.28, 0.85, smoothstep(0.03, 0.35, dot(smoke_c, vec3(0.3, 0.55, 0.15))));
			a *= 0.85;
		}
	} else if (kind == 2) {
		cover = dust_c * shade;
		a = dens * col_dust.a * opacity;
		// The dust skirt stacks the same way on Compatibility (a pale haze over the yard).
		if (OUTPUT_IS_SRGB) {
			cover *= mix(0.4, 0.85, smoothstep(0.05, 0.4, dot(dust_c, vec3(0.3, 0.55, 0.15))));
			a *= 0.85;
		}
	} else {
		float is_hot = smoothstep(0.35, 0.8, v_heat);
		float glow_part = smoothstep(0.3, 0.85, hp);
		float billow = (0.45 + 0.9 * n) * mix(0.55, 1.0, lit) * (0.6 + 0.4 * base);
		// Once cooled the fireball puff is smoke too: the same grey, lit from below, thinner.
		float shade_f = mix(1.25, 1.75, lit) * (0.7 + 0.6 * n);
		float under_f = 1.0 - lit;
		float fire_lit_f = (smoothstep(0.05, 0.3, v_heat) + under_k) * (0.12 + 0.88 * under_f * under_f);
		cover = smoke_c * shade_f + under_c * fire_lit_f * 0.16;
		cover = mix(cover, rim_c * (0.6 + 0.6 * n), rim_k);
		float edge_f = smoothstep(0.0, 0.7, 1.0 - d);
		float smoke_a = dens_s * col_smoke.a * opacity * 0.75 * mix(0.6, 1.0, edge_f);
		// Fresh smoke (the first second after the fire goes out) is dense and dark, not a haze.
		smoke_a *= 1.0 + 0.6 * exp(-v_tt * 1.2);
		if (OUTPUT_IS_SRGB) {
			cover *= mix(0.28, 0.85, smoothstep(0.03, 0.35, dot(smoke_c, vec3(0.3, 0.55, 0.15))));
			smoke_a *= 0.85;
		}
		float hotness = is_hot * glow_part;
		// The fireball is a solid, bright body: an opaque core (the inner 80 % of the puff) in the
		// flame colour, with only a little added light on top. The wall never shows through the
		// middle of a blast (2026-10-31 blind check 3: "the colour drained and the wall showed").
		// A hard edge: the core ends in a narrow band (blind check 4: soft rims read as cotton).
		float core_k = 1.0 - smoothstep(mix(0.6, 0.8, hard_edge), mix(0.95, 0.87, hard_edge), d);
		vec3 fire_c = bx_ramp(clamp(hp + 0.25 * core_k, 0.0, 1.1), cool_c, hot, core) * (1.3 + 0.7 * glow_part) * intensity;
		float fire_a = is_hot * core_k * fire_alpha * mix(0.75, 1.0, dens);
		cover = mix(cover, fire_c, is_hot);
		add = flame * billow * hotness * mix(1.0, 0.25, lit) * 0.45;
		a = max(smoke_a * (1.0 - hotness * 0.5), fire_a);
	}
	if (toon == 1) {
		// Flat cel steps inside a dark outline; the hot puffs step from core to hot to cool.
		float body = 1.0 - step(0.86, d);
		float line = step(0.74, d) * body;
		vec3 flat_c;
		if (kind == 0 && v_heat > 0.25) {
			float hv = v_heat + 0.35 * (1.0 - d);
			flat_c = hv > 0.95 ? core : (hv > 0.6 ? hot : cool);
			flat_c *= 1.4;
		} else {
			flat_c = (kind == 2 ? dust_c : smoke_c) * (lit > 0.55 ? 1.25 : 0.85);
		}
		vec3 ink = bx_lin(vec3(0.08, 0.05, 0.05));
		cover = mix(flat_c, ink, line);
		add = vec3(0.0);
		a = body * (kind == 0 ? 1.0 : opacity);
	}
	float a_out = clamp(a * env, 0.0, 1.0);
	// Light and cover are encoded apart and the cover is premultiplied after (bx_cover_out).
	ALBEDO = bx_add_out(add * env, OUTPUT_IS_SRGB) + bx_cover_out(cover, OUTPUT_IS_SRGB) * a_out;
	ALPHA = a_out;
}
