// EDGEFLUX slash body, shared by the additive and the solid variant.
// Mesh: UV.x runs along the arc (0..1), UV.y across it (0 = cutting edge, 1 = inner side).
// UV2.x = start delay of the strand, UV2.y = strand index.

#include "res://addons/edgeflux_fx/shaders/edgeflux_common.gdshaderinc"

// Seconds-normalised sweep: the head is at the start at 0 and at the end at 1.
uniform float progress = 2.0;
// Length of the lit part, as a fraction of the arc.
uniform float trail_length : hint_range(0.05, 1.5) = 0.6;
// Thickest point of the crescent, as a fraction of the mesh band.
uniform float thickness : hint_range(0.05, 1.0) = 0.85;
uniform float edge_width : hint_range(0.0, 0.5) = 0.08;
uniform bool flip = false;
// Thick in the middle and thin at both ends (flying crescents) instead of thick at the head.
uniform bool symmetric = false;
// Noise that eats the tail away.
uniform float dissolve : hint_range(0.0, 1.0) = 0.5;
// Fine streaks running along the arc.
uniform float streaks : hint_range(0.0, 1.0) = 0.5;
uniform float time = 0.0;
uniform float seed = 0.0;
uniform float intensity = 1.0;

uniform vec4 core_color : source_color = vec4(1.0);
uniform vec4 glow_color : source_color = vec4(0.4, 0.7, 1.0, 1.0);
uniform vec4 tail_color : source_color = vec4(0.1, 0.2, 0.8, 1.0);
uniform vec4 outline_color : source_color = vec4(0.03, 0.05, 0.15, 1.0);
uniform float core_energy = 2.0;
uniform float glow_energy = 1.4;

struct EfSlash {
	float mask;
	float edge;
	float s;
	float r;
	float band;
	float n;
};

EfSlash ef_slash(vec2 uv, vec2 uv2) {
	EfSlash o;
	float u = flip ? 1.0 - uv.x : uv.x;
	float head = (progress - uv2.x) * (1.0 + trail_length);
	float s = (u - (head - trail_length)) / trail_length;
	float vis = step(0.0, s) * step(s, 1.0);
	float thick = thickness * pow(clamp(s, 0.0, 1.0), 0.55) * smoothstep(1.0, 0.88, s);
	if (symmetric) {
		thick = thickness * pow(max(sin(clamp(s, 0.0, 1.0) * 3.14159), 0.0), 0.6);
	}
	float n = ef_noise(vec2(u * 26.0 + seed * 7.0, uv.y * 5.0 + seed));
	float nd = ef_fbm(vec2(u * 9.0 - time * 1.5 + seed * 3.0, uv.y * 3.0));
	float thick_n = thick * (1.0 - dissolve * 0.6 * (1.0 - s) * nd);
	float mask = vis * (1.0 - smoothstep(thick_n * 0.82, thick_n, uv.y));
	mask *= smoothstep(0.0, mix(0.02, 0.6, dissolve), s - dissolve * 0.35 * nd);
	o.mask = clamp(mask, 0.0, 1.0);
	o.edge = vis * exp(-uv.y / max(edge_width, 0.002)) * smoothstep(0.15, 0.9, s) * smoothstep(1.0, 0.95, s);
	o.s = clamp(s, 0.0, 1.0);
	o.r = uv.y / max(thick_n, 0.001);
	o.band = thick_n;
	o.n = mix(1.0, 0.45 + 1.1 * n, streaks);
	return o;
}
