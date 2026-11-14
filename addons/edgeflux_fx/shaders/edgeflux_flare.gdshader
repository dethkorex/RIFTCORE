// EDGEFLUX flare: glows, stars, rings and clash streaks on a quad.
// billboard = true faces the camera; false keeps the quad on its local XY plane (rings on a surface).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, skip_vertex_transform, shadows_disabled, fog_disabled;

#include "res://addons/edgeflux_fx/shaders/edgeflux_common.gdshaderinc"

uniform bool billboard = true;
// 0 = soft glow, 1 = star, 2 = ring, 3 = clash cross (long horizontal streak).
uniform int shape = 0;
uniform float size = 1.0;
uniform float aspect = 1.0;
uniform float rotation = 0.0;
// Billboards are pulled this far toward the camera so the surface they sit on does not cut them.
uniform float pull = 0.3;
uniform float rays = 6.0;
uniform float ray_sharpness = 24.0;
uniform float ray_length : hint_range(0.0, 1.0) = 1.0;
uniform float core_size : hint_range(0.0, 1.0) = 0.12;
uniform float ring_radius : hint_range(0.0, 1.0) = 0.6;
uniform float ring_width : hint_range(0.0, 0.5) = 0.06;
// Breaks rings and rays into uneven pieces.
uniform float breakup : hint_range(0.0, 1.0) = 0.3;
uniform float seed = 0.0;
uniform float intensity = 0.0;

uniform vec4 core_color : source_color = vec4(1.0);
uniform vec4 glow_color : source_color = vec4(0.4, 0.7, 1.0, 1.0);
uniform vec4 tail_color : source_color = vec4(0.1, 0.2, 0.8, 1.0);
uniform float core_energy = 2.0;
uniform float glow_energy = 1.4;

void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	float c = cos(rotation);
	float sn = sin(rotation);
	vec2 q = VERTEX.xy * vec2(aspect, 1.0);
	q = vec2(q.x * c - q.y * sn, q.x * sn + q.y * c);
	if (billboard) {
		vec3 center = (MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
		bool ortho = PROJECTION_MATRIX[3][3] > 0.5;
		vec3 to_cam = ortho ? vec3(0.0, 0.0, 1.0) : normalize(-center);
		float pl = min(pull * s * size, max(-center.z - 0.05, 0.0) * 0.5);
		VERTEX = center + to_cam * pl + vec3(q * size * s, 0.0);
		NORMAL = vec3(0.0, 0.0, 1.0);
	} else {
		VERTEX = (MODELVIEW_MATRIX * vec4(q * size, 0.0, 1.0)).xyz;
		NORMAL = normalize((MODELVIEW_MATRIX * vec4(0.0, 0.0, 1.0, 0.0)).xyz);
	}
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float edge = smoothstep(1.0, 0.82, r);
	float core = exp(-r * r / max(core_size * core_size, 1e-4));
	float halo = exp(-r * 3.2) * 0.55;
	float body = 0.0;
	if (shape == 1) {
		float ray = pow(abs(cos(a * rays * 0.5)), ray_sharpness);
		float jitter = mix(1.0, 0.35 + 0.65 * ef_hash(floor((a + 3.1416) / 6.2832 * rays + 0.5) + seed), breakup);
		float len = ray_length * jitter;
		body = ray * smoothstep(len, 0.0, r) * 1.4 + halo;
	} else if (shape == 2) {
		float n = mix(1.0, ef_noise(vec2(a * 3.0 + seed, seed * 1.7)) * 1.6, breakup);
		float d = (r - ring_radius) / max(ring_width, 0.001);
		body = exp(-d * d) * n + exp(-r * 2.5) * 0.08;
		core *= 0.0;
	} else if (shape == 3) {
		float hs = exp(-abs(p.y) * 38.0) * pow(max(1.0 - abs(p.x), 0.0), 1.5);
		float vs = exp(-abs(p.x) * 30.0 * aspect) * pow(max(1.0 - abs(p.y), 0.0), 3.0) * 0.6;
		body = hs + vs + halo * 0.8;
	} else {
		body = halo * 1.6;
	}
	vec3 col = core_color.rgb * core_energy * core + mix(tail_color.rgb, glow_color.rgb, clamp(body, 0.0, 1.0)) * glow_energy * body;
	ALBEDO = col * intensity * edge;
}
