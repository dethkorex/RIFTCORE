// EDGEFLUX streaks: sparks, converging motes and speed lines.
// The mesh is a set of empty quads (UV = corner, UV2.x = particle index). Every position is
// solved here from the index, the seed and the age, so the CPU only sends a few uniforms.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, skip_vertex_transform, shadows_disabled, fog_disabled;

#include "res://addons/edgeflux_fx/shaders/edgeflux_common.gdshaderinc"

// 0 = burst from a point or a segment, 1 = converge on a centre, 2 = lines along a path.
uniform int mode = 0;
uniform vec3 origin = vec3(0.0);
// Burst: particles start somewhere between origin and origin_b. Path: the end of the path.
uniform vec3 origin_b = vec3(0.0);
uniform vec3 emit_dir = vec3(0.0, 1.0, 0.0);
uniform float spread = 1.2;
uniform float speed_min = 2.0;
uniform float speed_max = 6.0;
uniform float life_min = 0.25;
uniform float life_max = 0.6;
uniform float gravity = 9.8;
uniform float drag = 2.0;
uniform float age = 100.0;
// Emission is spread over this many seconds.
uniform float delay_spread = 0.0;
// Seconds of motion drawn as the streak (burst), or fraction of the path (path).
uniform float streak = 0.04;
uniform float width = 0.03;
uniform float min_pixels = 1.5;
uniform float seed = 0.0;
uniform float count_fraction : hint_range(0.0, 1.0) = 1.0;
uniform float scale = 1.0;
uniform bool use_floor = false;
uniform float floor_y = 0.0;
// Converge mode.
uniform float time = 0.0;
uniform float rate = 1.0;
uniform float radius = 1.5;
uniform float swirl = 2.0;
uniform float level : hint_range(0.0, 1.0) = 1.0;
// Path mode: seconds for a line to cross the path.
uniform float duration = 0.25;
// 0 = even width, 1 = comet (wide head, thin tail).
uniform float taper : hint_range(0.0, 1.0) = 0.6;

uniform vec4 core_color : source_color = vec4(1.0);
uniform vec4 glow_color : source_color = vec4(0.4, 0.7, 1.0, 1.0);
uniform vec4 spark_color : source_color = vec4(0.5, 0.8, 1.0, 1.0);
uniform float core_energy = 2.0;
uniform float glow_energy = 1.4;
uniform float intensity = 1.0;
// How long the white-hot start lasts, as a fraction of the life.
uniform float hot_time : hint_range(0.0, 1.0) = 0.35;

varying vec2 v_uv;
varying float v_life;
varying float v_alive;
varying float v_energy;

void vertex() {
	float id = UV2.x;
	float h0 = ef_hash(id * 1.731 + seed * 3.17);
	float h1 = ef_hash(id * 2.519 + seed * 1.91 + 7.0);
	float h2 = ef_hash(id * 3.887 + seed * 0.73 + 13.0);
	float h3 = ef_hash(id * 5.113 + seed * 2.29 + 19.0);
	float h4 = ef_hash(id * 7.411 + seed * 1.37 + 23.0);
	float h5 = ef_hash(id * 9.203 + seed * 0.51 + 29.0);
	vec3 head = vec3(0.0);
	vec3 tail = vec3(0.0);
	float alive = step(h0, count_fraction);
	float life = 0.0;
	if (mode == 0) {
		float lt = mix(life_min, life_max, h4);
		float t = age - h3 * delay_spread;
		vec3 dir = ef_cone(emit_dir, spread, h1, h2);
		vec3 v0 = dir * mix(speed_min, speed_max, h5) * scale;
		vec3 p0 = mix(origin, origin_b, ef_hash(id * 11.3 + seed));
		vec3 g = vec3(0.0, -gravity * scale, 0.0);
		head = ef_motion(p0, v0, g, drag, max(t, 0.0));
		tail = ef_motion(p0, v0, g, drag, max(t - streak, 0.0));
		if (use_floor) {
			head.y = max(head.y, floor_y + 0.01 * scale);
			tail.y = max(tail.y, floor_y + 0.01 * scale);
		}
		life = t / lt;
		alive *= step(0.0, t) * step(life, 1.0);
	} else if (mode == 1) {
		float ph = fract(time * rate * (0.7 + 0.6 * h4) + h3);
		vec3 dir = ef_cone(emit_dir, spread, h1, h2);
		float r0 = radius * scale * (0.6 + 0.4 * h5);
		float k = 1.0 - ph;
		float k0 = 1.0 - max(ph - streak, 0.0);
		vec3 up = normalize(emit_dir);
		float a = swirl * ph;
		float a0 = swirl * max(ph - streak, 0.0);
		vec3 d1 = dir * cos(a) + cross(up, dir) * sin(a) + up * dot(up, dir) * (1.0 - cos(a));
		vec3 d0 = dir * cos(a0) + cross(up, dir) * sin(a0) + up * dot(up, dir) * (1.0 - cos(a0));
		head = origin + d1 * r0 * k * k;
		tail = origin + d0 * r0 * k0 * k0;
		life = 1.0 - ph;
		alive *= step(h0, level);
	} else {
		vec3 axis = origin_b - origin;
		float len = max(length(axis), 0.0001);
		vec3 a = axis / len;
		vec3 helper = abs(a.y) < 0.95 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
		vec3 u = normalize(cross(a, helper));
		vec3 v = cross(a, u);
		float ang = h1 * 6.28318;
		vec3 off = (u * cos(ang) + v * sin(ang)) * radius * scale * sqrt(h2) + emit_dir * scale * (h5 - 0.5) * spread;
		float t = (age - h3 * delay_spread) / max(duration, 0.001);
		float hs = clamp(1.0 - pow(1.0 - clamp(t, 0.0, 1.0), 2.0), 0.0, 1.0);
		float ts = clamp(1.0 - pow(1.0 - clamp(t - streak, 0.0, 1.0), 2.0), 0.0, 1.0);
		head = origin + axis * hs + off;
		tail = origin + axis * ts + off;
		life = ts;
		alive *= step(0.0, t) * step(ts, 0.999);
	}
	v_life = clamp(life, 0.0, 1.0);
	v_alive = alive;
	vec3 hv = (VIEW_MATRIX * vec4(head, 1.0)).xyz;
	vec3 tv = (VIEW_MATRIX * vec4(tail, 1.0)).xyz;
	vec3 d = hv - tv;
	if (dot(d, d) < 1e-10) {
		d = vec3(0.0, 1e-4, 0.0);
	}
	bool ortho = PROJECTION_MATRIX[3][3] > 0.5;
	vec3 view_dir = ortho ? vec3(0.0, 0.0, -1.0) : normalize(hv);
	vec3 side = cross(d, view_dir);
	float sl = length(side);
	side = sl > 1e-6 ? side / sl : vec3(1.0, 0.0, 0.0);
	float w = width * scale * (1.0 - 0.4 * v_life);
	float px = 2.0 / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y) * (ortho ? 1.0 : max(-hv.z, 0.001));
	float w2 = max(w, min_pixels * px);
	v_energy = clamp(w / w2, 0.15, 1.0);
	vec3 dn = normalize(d);
	vec3 p = mix(tv - dn * w2 * 0.5, hv + dn * w2 * 0.5, UV.x) + side * (UV.y * w2 * 0.5);
	VERTEX = alive > 0.5 ? p : vec3(0.0, 0.0, 1.0);
	NORMAL = vec3(0.0, 0.0, 1.0);
	v_uv = UV;
}

void fragment() {
	float prof = mix(1.0, 0.25 + 0.75 * v_uv.x, taper);
	float across = clamp(1.0 - abs(v_uv.y) / prof, 0.0, 1.0);
	float along = smoothstep(0.0, 0.45, v_uv.x) * smoothstep(1.0, 0.85, v_uv.x);
	float fade = (1.0 - v_life) * (1.0 - v_life);
	float hot = 1.0 - smoothstep(0.0, max(hot_time, 0.001), v_life);
	if (mode == 1) {
		float ph = 1.0 - v_life;
		fade = smoothstep(0.0, 0.25, ph) * smoothstep(1.0, 0.85, ph) * (0.5 + ph) * level;
		hot = ph * ph * ph;
	} else if (mode == 2) {
		fade = 1.0 - v_life;
		hot = 0.4;
	}
	vec3 body = mix(spark_color.rgb, glow_color.rgb, 0.35) * glow_energy;
	vec3 col = mix(body, core_color.rgb * core_energy, max(hot * 0.85, pow(across, 6.0) * 0.6));
	ALBEDO = col * (across * across * along * fade * intensity * v_alive * v_energy);
}
