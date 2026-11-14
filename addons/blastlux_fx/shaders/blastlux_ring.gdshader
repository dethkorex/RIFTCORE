// The flat parts of a blast: the flash disc, the shock ring that runs over the ground and the
// pressure disc that stands in the air. One quad; `age` drives the radius and the fade.
shader_type spatial;
render_mode unshaded, blend_premul_alpha, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

#include "res://addons/blastlux_fx/shaders/blastlux_noise.gdshaderinc"

uniform int seed = 1;
uniform float age = -1.0;
uniform vec3 em_origin;
uniform vec3 em_x = vec3(1.0, 0.0, 0.0);
uniform vec3 em_y = vec3(0.0, 1.0, 0.0);
uniform vec3 em_z = vec3(0.0, 0.0, 1.0);

// 0 = flat on the emitter's ground plane, 1 = facing the camera.
uniform int facing = 0;
// 0 flash disc (adds light), 1 ground shock ring (a faint dust band, no glow), 2 pressure disc in
// the air (thin translucent ring, adds a little light), 3 hard bright shell (plasma, implosion),
// 4 flare (a flashbang: a wide horizontal streak and thin rays), 5 rune circle on the ground
// (arcane), 6 void core (a black disc with a bright rim that grows while light is pulled in).
uniform int kind = 0;
uniform float delay = 0.0;
uniform float radius = 4.0;
// Metres per second the ring front travels (kind 1 / 2).
uniform float wave_speed = 14.0;
uniform float duration = 0.6;
uniform float thickness = 0.3;
uniform float height_offset = 0.04;
uniform float intensity = 1.0;
// World-space shift of the quad (a grounded flash disc is lifted so the floor does not cut it).
uniform vec3 offset = vec3(0.0);

uniform vec4 col_core = vec4(1.0, 0.93, 0.7, 1.0);
uniform vec4 col_hot = vec4(1.0, 0.5, 0.1, 1.0);
uniform vec4 col_dust = vec4(0.42, 0.36, 0.28, 0.8);
uniform float emission = 2.4;

varying vec2 v_q;
varying float v_r;
varying float v_t;

void vertex() {
	float s = (length(em_x) + length(em_y) + length(em_z)) / 3.0;
	float t = age - delay;
	v_t = t / max(duration, 0.001);
	float r;
	if (kind == 0 || kind == 4) {
		r = radius * s * (0.6 + 0.4 * smoothstep(0.0, 1.0, v_t));
	} else if (kind == 3) {
		r = radius * s * (1.0 - (1.0 - v_t) * (1.0 - v_t) * (1.0 - v_t));
		r = max(r, 0.0);
	} else if (kind == 5) {
		r = radius * s * (0.85 + 0.15 * smoothstep(0.0, 0.25, v_t));
	} else if (kind == 6) {
		r = radius * s * smoothstep(0.0, 1.0, v_t);
	} else {
		r = min(wave_speed * s * max(t, 0.0), radius * s);
	}
	v_r = r;
	float R = r + thickness * s * 2.0 + 0.001;
	if (kind == 4) {
		R = r * 3.2;
	}
	vec2 c = UV * 2.0 - 1.0;
	vec3 p;
	if (facing == 1) {
		p = em_origin + offset + (INV_VIEW_MATRIX[0].xyz * c.x + INV_VIEW_MATRIX[1].xyz * c.y) * R;
	} else {
		p = em_origin + normalize(em_y) * height_offset * s + (normalize(em_x) * c.x + normalize(em_z) * c.y) * R;
	}
	v_q = c * R;
	bool on = age >= 0.0 && t >= 0.0 && v_t < 1.0;
	VERTEX = on ? p : em_origin;
	NORMAL = normalize(INV_VIEW_MATRIX[3].xyz - p);
}

void fragment() {
	float s = (length(em_x) + length(em_y) + length(em_z)) / 3.0;
	float d = length(v_q);
	float ang = atan(v_q.y, v_q.x);
	float n = bx_fbm(vec3(cos(ang) * 2.0, sin(ang) * 2.0, float(seed % 97) + v_t * 2.0), 3);
	// The pressure disc in the air spreads and thins as it runs (not a solid donut).
	float th = thickness * s * (0.6 + 0.8 * n) * (kind == 2 ? 1.0 + 1.2 * v_t : 1.0);
	float fade = 1.0 - smoothstep(0.0, 1.0, v_t);
	vec3 core = bx_lin(col_core.rgb);
	vec3 hot = bx_lin(col_hot.rgb);
	vec3 dust = bx_lin(col_dust.rgb);
	vec3 add = vec3(0.0);
	vec3 cover = vec3(0.0);
	float a = 0.0;
	if (kind == 3) {
		// A thin, crisp shell: bright rim, a little light inside, breaking up as it fades.
		float x = (d - v_r) / max(thickness * s, 0.001);
		float rim = exp(-x * x * 6.0) * smoothstep(0.25, 0.6, n + 0.35 * (1.0 - v_t));
		float inside = step(d, v_r) * 0.12 * (1.0 - v_t);
		add = mix(hot, core, rim) * (rim * 1.6 + inside) * emission * intensity * fade;
	} else if (kind == 4) {
		// Flashbang flare: a white ball, a long thin horizontal streak and six faint rays.
		vec2 qq = v_q / max(v_r, 0.001);
		float ball = exp(-dot(qq, qq) * 2.2);
		float streak = exp(-qq.y * qq.y * 160.0) * exp(-abs(qq.x) * 0.9);
		float ray_a = cos(ang * 6.0 + float(seed % 7));
		float rays = pow(max(ray_a, 0.0), 40.0) * exp(-length(qq) * 1.2) * 0.6;
		float k = pow(max(fade, 0.0), 1.2);
		add = mix(hot, core, 0.85) * (ball * 2.2 + streak * 1.6 + rays) * emission * intensity * k;
	} else if (kind == 5) {
		// Rune circle: two rings, ticks and broken glyph arcs between them, flaring on and fading.
		float rr = d / max(v_r, 0.001);
		float w = thickness * s / max(v_r, 0.001);
		float e1 = (rr - 1.0) / max(w * 0.25, 0.001);
		float r1 = exp(-e1 * e1);
		float e2 = (rr - 0.78) / max(w * 0.18, 0.001);
		float r2 = exp(-e2 * e2);
		float e3 = (rr - 0.89) / max(w * 0.12, 0.001);
		float ticks = step(0.82, fract(ang * 6.0 / 3.14159)) * step(0.8, rr) * step(rr, 0.98);
		float glyph = step(0.55, bx_vnoise(vec3(ang * 5.0, 1.0, float(seed % 13)))) * exp(-e3 * e3);
		float on = smoothstep(0.0, 0.08, v_t) * (1.0 - smoothstep(0.55, 1.0, v_t));
		add = mix(hot, core, 0.4) * (r1 + r2 * 0.8 + ticks * 0.6 + glyph * 0.9) * emission * intensity * on * 0.8;
	} else if (kind == 6) {
		// Void core: covers black, a thin bright rim; it shrinks to nothing as it ends.
		float rr = d / max(v_r, 0.001);
		float body = 1.0 - smoothstep(0.86, 1.0, rr);
		float e4 = (rr - 0.93) / 0.07;
		float rim = exp(-e4 * e4);
		float k = 1.0 - smoothstep(0.85, 1.0, v_t);
		a = body * 0.96 * k;
		cover = vec3(0.004, 0.0, 0.008);
		add = mix(hot, core, 0.6) * rim * emission * intensity * k * 0.9;
	} else if (kind == 0) {
		float disc_t = d / max(v_r, 0.001);
		float disc = exp(-disc_t * disc_t * 3.0);
		add = mix(hot, core, disc) * disc * emission * intensity * pow(max(fade, 0.0), 1.5);
	} else {
		float x = (d - v_r) / max(th, 0.001);
		// The front is sharp on the outside and trails off behind.
		float band = exp(-x * x * 3.0) * step(x, 0.6) + exp(-max(-x, 0.0) * 1.6) * step(x, 0.0) * 0.35;
		band *= 0.7 + 0.6 * n;
		if (kind == 1) {
			// A faint dust band only: the old hot inner edge read as a red target on the floor
			// (blind check 4). The heat ripple layer carries the wave on Forward+ and Mobile.
			a = band * col_dust.a * fade * intensity * 0.45;
			cover = dust * (0.6 + 0.5 * n);
		} else {
			float glow = band * fade * intensity * 0.38 * (1.0 - 0.5 * v_t);
			add = mix(hot, core, 0.5) * glow * emission * 0.3;
			a = glow * 0.28;
		}
	}
	float a_out = clamp(a, 0.0, 1.0);
	ALBEDO = bx_add_out(add, OUTPUT_IS_SRGB) + bx_cover_out(cover, OUTPUT_IS_SRGB) * a_out;
	ALPHA = a_out;
}
