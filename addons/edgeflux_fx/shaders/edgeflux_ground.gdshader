// EDGEFLUX ground mark: expanding ring, radial cracks and a dark dent, on a 2x2 plane (local XZ).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

#include "res://addons/edgeflux_fx/shaders/edgeflux_common.gdshaderinc"

uniform float ring_radius : hint_range(0.0, 1.2) = 0.5;
uniform float ring_width : hint_range(0.0, 0.5) = 0.08;
uniform float ring_strength = 1.0;
uniform float crack_count = 9.0;
// How far the cracks reach (0..1 of the plane radius).
uniform float crack_reach : hint_range(0.0, 1.0) = 0.8;
uniform float crack_width : hint_range(0.0, 0.1) = 0.018;
// Glow inside the cracks; cools to the dark outline colour as it drops.
uniform float crack_glow : hint_range(0.0, 2.0) = 1.0;
uniform float dent : hint_range(0.0, 1.0) = 0.6;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float seed = 0.0;
uniform float intensity = 1.0;

uniform vec4 core_color : source_color = vec4(1.0);
uniform vec4 glow_color : source_color = vec4(0.4, 0.7, 1.0, 1.0);
uniform vec4 outline_color : source_color = vec4(0.03, 0.05, 0.15, 1.0);
uniform float core_energy = 2.0;
uniform float glow_energy = 1.4;

float ef_cracks(vec2 p, float count, float reach, float w, float s) {
	float r = length(p);
	float a = atan(p.y, p.x) / 6.28318 + 0.5;
	float bend = (ef_noise(vec2(r * 6.0, s)) - 0.5) * 0.9 / count + (ef_noise(vec2(r * 22.0, s + 3.0)) - 0.5) * 0.25 / count;
	float k = (a + bend) * count;
	float id = floor(k);
	float len = reach * (0.45 + 0.55 * ef_hash(id + s * 13.0));
	float d = abs(fract(k) - 0.5) * 6.28318 * r / count;
	float taper = w * clamp(1.0 - r / max(len, 0.001), 0.0, 1.0) * (0.6 + 0.8 * ef_hash(id * 3.1 + s));
	return (1.0 - smoothstep(taper * 0.5, taper, d)) * step(0.04, r);
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float main = ef_cracks(p, crack_count, crack_reach, crack_width, seed);
	float side = ef_cracks(p * 1.0 + vec2(0.013), crack_count * 2.3, crack_reach * 0.55, crack_width * 0.6, seed + 5.0);
	float cracks = max(main, side * 0.8);
	float d = (r - ring_radius) / max(ring_width, 0.001);
	float ring = exp(-d * d) * ring_strength * (0.6 + 0.4 * ef_noise(vec2(atan(p.y, p.x) * 4.0, seed)));
	float hole = dent * smoothstep(0.35, 0.0, r) * (0.7 + 0.3 * ef_noise(p * 8.0 + seed));
	vec3 hot = mix(glow_color.rgb * glow_energy, core_color.rgb * core_energy, clamp(crack_glow - 0.6, 0.0, 1.0));
	vec3 crack_col = mix(outline_color.rgb, hot, clamp(crack_glow, 0.0, 1.0));
	vec3 col = outline_color.rgb;
	float a = hole * 0.75;
	col = mix(col, crack_col, cracks);
	a = max(a, cracks * 0.95);
	col = mix(col, mix(glow_color.rgb * glow_energy, core_color.rgb, 0.25), clamp(ring, 0.0, 1.0));
	a = max(a, clamp(ring, 0.0, 1.0) * 0.85);
	ALBEDO = col * mix(1.0, intensity, 0.5);
	ALPHA = clamp(a * fade * smoothstep(1.0, 0.9, r), 0.0, 1.0);
}
