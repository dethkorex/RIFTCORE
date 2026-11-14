// EDGEFLUX ring wall: an open cylinder that expands and fades (shockwaves, kick rings).
// Mesh: open CylinderMesh of radius 1 and height 1. radius / height are in local units.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

#include "res://addons/edgeflux_fx/shaders/edgeflux_common.gdshaderinc"

uniform float radius = 1.0;
uniform float height = 0.6;
// Inward lean of the top edge (0 = straight wall, negative flares outward).
uniform float lean = -0.3;
uniform float intensity = 0.0;
uniform float seed = 0.0;
uniform float scroll = 0.0;
uniform float streaks : hint_range(0.0, 1.0) = 0.6;

uniform vec4 core_color : source_color = vec4(1.0);
uniform vec4 glow_color : source_color = vec4(0.4, 0.7, 1.0, 1.0);
uniform vec4 tail_color : source_color = vec4(0.1, 0.2, 0.8, 1.0);
uniform float core_energy = 2.0;
uniform float glow_energy = 1.4;

varying float v_h;
varying float v_a;

void vertex() {
	float h = VERTEX.y + 0.5;
	v_h = h;
	v_a = atan(VERTEX.z, VERTEX.x);
	float rr = radius * (1.0 - lean * h);
	VERTEX = vec3(normalize(VERTEX.xz + vec2(1e-5)) * rr, h * height).xzy;
}

void fragment() {
	float n = ef_noise(vec2(v_a * 5.0 + seed, v_h * 2.0 - scroll));
	float n2 = ef_noise(vec2(v_a * 19.0 + seed * 2.0, v_h * 0.8 - scroll * 1.6));
	float st = mix(1.0, 0.3 + 1.2 * n * n2 * 2.0, streaks);
	float base = exp(-v_h * 4.0);
	float hh = clamp(v_h, 0.0, 1.0);
	float body = pow(1.0 - hh, 1.6) * st;
	vec3 col = mix(tail_color.rgb, glow_color.rgb, clamp(1.0 - v_h + n * 0.3, 0.0, 1.0)) * glow_energy * body;
	col += core_color.rgb * base * 0.35;
	ALBEDO = min(col * intensity * (FRONT_FACING ? 1.0 : 0.5), vec3(1.5));
}
