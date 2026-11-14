// EDGEFLUX debris: small tumbling chips thrown by ground slams and shattered shields.
// Same mesh layout and motion as edgeflux_streaks (burst mode), drawn as solid shards.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_disabled, skip_vertex_transform, shadows_disabled;

#include "res://addons/edgeflux_fx/shaders/edgeflux_common.gdshaderinc"

uniform vec3 origin = vec3(0.0);
uniform vec3 origin_b = vec3(0.0);
uniform vec3 emit_dir = vec3(0.0, 1.0, 0.0);
uniform float spread = 0.9;
uniform float speed_min = 2.0;
uniform float speed_max = 5.0;
uniform float life_min = 0.6;
uniform float life_max = 1.1;
uniform float gravity = 14.0;
uniform float drag = 0.6;
uniform float age = 100.0;
uniform float size = 0.08;
uniform float seed = 0.0;
uniform float count_fraction : hint_range(0.0, 1.0) = 1.0;
uniform float scale = 1.0;
uniform float floor_y = 0.0;
// Glowing edge that cools over the first part of the life.
uniform float heat = 1.0;
// Radial spawn offset around the origin (ground slams spawn on a ring).
uniform float ring = 0.0;

uniform vec4 glow_color : source_color = vec4(0.4, 0.7, 1.0, 1.0);
uniform vec4 outline_color : source_color = vec4(0.05, 0.05, 0.07, 1.0);
uniform float glow_energy = 1.4;

varying vec2 v_uv;
varying float v_life;
varying float v_alive;
varying float v_shape;

void vertex() {
	float id = UV2.x;
	float h0 = ef_hash(id * 1.731 + seed * 3.17);
	float h1 = ef_hash(id * 2.519 + seed * 1.91 + 7.0);
	float h2 = ef_hash(id * 3.887 + seed * 0.73 + 13.0);
	float h4 = ef_hash(id * 7.411 + seed * 1.37 + 23.0);
	float h5 = ef_hash(id * 9.203 + seed * 0.51 + 29.0);
	float h6 = ef_hash(id * 4.77 + seed * 2.9 + 31.0);
	float lt = mix(life_min, life_max, h4);
	vec3 dir = ef_cone(emit_dir, spread, h1, h2);
	vec3 flat_dir = normalize(vec3(dir.x, 0.0, dir.z) + vec3(1e-4, 0.0, 0.0));
	vec3 p0 = mix(origin, origin_b, h6) + flat_dir * ring * scale;
	vec3 v0 = dir * mix(speed_min, speed_max, h5) * scale;
	vec3 g = vec3(0.0, -gravity * scale, 0.0);
	vec3 p = ef_motion(p0, v0, g, drag, age);
	p.y = max(p.y, floor_y + size * scale * 0.4);
	float life = age / lt;
	float alive = step(h0, count_fraction) * step(life, 1.0);
	v_life = clamp(life, 0.0, 1.0);
	v_alive = alive;
	v_shape = h1;
	float sz = size * scale * (0.5 + h5) * (1.0 - smoothstep(0.7, 1.0, life));
	float rot = age * (h2 - 0.5) * 18.0 + h1 * 6.28;
	vec2 q = UV * vec2(2.0, 1.0) - vec2(1.0, 0.0);
	q = vec2(q.x * cos(rot) - q.y * sin(rot), q.x * sin(rot) + q.y * cos(rot));
	vec3 c = (VIEW_MATRIX * vec4(p, 1.0)).xyz;
	VERTEX = alive > 0.5 ? c + vec3(q * sz, 0.0) : vec3(0.0, 0.0, 1.0);
	NORMAL = vec3(0.0, 0.0, 1.0);
	v_uv = UV * vec2(2.0, 1.0) - vec2(1.0, 0.0);
}

void fragment() {
	vec2 q = abs(v_uv);
	float shard = max(q.x * (0.8 + v_shape * 0.4) + q.y * 0.6, q.y * 1.1);
	if (shard > 0.95 || v_alive < 0.5) {
		discard;
	}
	float edge = smoothstep(0.55, 0.95, shard);
	float hot = heat * (1.0 - smoothstep(0.0, 0.22, v_life));
	ALBEDO = mix(outline_color.rgb, glow_color.rgb * glow_energy, clamp(hot * (0.45 + 0.35 * edge), 0.0, 1.0));
}
