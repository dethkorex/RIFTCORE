// EDGEFLUX weapon trail body, shared by the additive and the solid variant.
// Mesh: UV.x = age (0 = newest sample at the blade, 1 = oldest), UV.y = 0 at the base, 1 at the tip.

#include "res://addons/edgeflux_fx/shaders/edgeflux_common.gdshaderinc"

// 0 = glow, 1 = energy, 2 = soft, 3 = arcane.
uniform int style = 0;
// Older parts shrink toward the tip, which gives the crescent shape.
uniform float taper : hint_range(0.0, 1.0) = 0.75;
uniform float edge_width : hint_range(0.0, 0.5) = 0.1;
uniform float fade_power = 1.6;
uniform float time = 0.0;
uniform float seed = 0.0;
uniform float intensity = 1.0;
// Fraction of the blade covered (from the tip down).
uniform float coverage : hint_range(0.05, 1.0) = 0.8;

uniform vec4 core_color : source_color = vec4(1.0);
uniform vec4 glow_color : source_color = vec4(0.4, 0.7, 1.0, 1.0);
uniform vec4 tail_color : source_color = vec4(0.1, 0.2, 0.8, 1.0);
uniform vec4 outline_color : source_color = vec4(0.03, 0.05, 0.15, 1.0);
uniform float core_energy = 2.0;
uniform float glow_energy = 1.4;

struct EfTrail {
	float mask;
	float edge;
	float body;
	float age;
	float y;
};

EfTrail ef_trail(vec2 uv) {
	EfTrail o;
	float age = clamp(uv.x, 0.0, 1.0);
	float y = (uv.y - (1.0 - coverage)) / max(coverage, 0.001);
	float cut = taper * pow(age, 0.8);
	float yy = (y - cut) / max(1.0 - cut, 0.001);
	float inside = smoothstep(0.0, 0.18, yy) * step(0.0, y);
	float fade = pow(1.0 - age, fade_power);
	o.mask = inside * fade;
	o.edge = exp(-(1.0 - yy) / max(edge_width, 0.002)) * smoothstep(1.0, 0.6, age) * step(0.0, yy);
	float b = pow(clamp(yy, 0.0, 1.0), 2.0) * 1.5;
	if (style == 1) {
		float n = ef_noise(vec2(age * 14.0 - time * 7.0 + seed, yy * 6.0));
		float n2 = ef_noise(vec2(age * 30.0 - time * 11.0, yy * 13.0 + seed));
		b *= 0.25 + 1.5 * n * n + 0.6 * n2 * n2;
	} else if (style == 2) {
		b = exp(-pow((yy - 0.7) * 2.4, 2.0)) * 0.9;
	} else if (style == 3) {
		vec2 g = vec2(age * 22.0, yy * 8.0);
		vec2 cell = floor(g);
		vec2 f = fract(g) - 0.5;
		float hs = ef_hash2(cell + seed);
		float tw = 0.5 + 0.5 * sin(time * 9.0 + hs * 40.0);
		float star = step(0.82, hs) * exp(-dot(f, f) * 40.0) * tw * 3.0;
		b = b * (0.55 + 0.45 * ef_fbm(vec2(age * 6.0 - time * 2.0, yy * 3.0 + seed))) + star;
	}
	o.body = b;
	o.age = age;
	o.y = clamp(yy, 0.0, 1.0);
	return o;
}
