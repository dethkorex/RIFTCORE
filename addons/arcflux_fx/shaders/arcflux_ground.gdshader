// ARCFLUX ground mark: one flat quad that combines an additive flash, an expanding ring,
// a darkened scorch and glowing embers. Uses premultiplied alpha so dark and additive
// parts can live in the same draw call on every renderer.
shader_type spatial;
render_mode unshaded, blend_premul_alpha, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 core_color : source_color = vec4(0.86, 0.93, 1.0, 1.0);
uniform vec4 glow_color : source_color = vec4(0.24, 0.52, 1.0, 1.0);
uniform vec4 ember_color : source_color = vec4(1.0, 0.55, 0.25, 1.0);
uniform float core_energy = 5.0;
uniform float glow_energy = 2.2;
uniform float intensity = 1.0;
// Radial flash in the middle of the quad.
uniform float flash = 0.0;
uniform float flash_size : hint_range(0.05, 1.0) = 0.6;
// Ring at radius ring_radius (0..1 of the quad half size).
uniform float ring = 0.0;
uniform float ring_radius : hint_range(0.0, 1.0) = 0.5;
uniform float ring_width : hint_range(0.005, 0.5) = 0.06;
uniform float ring_breakup : hint_range(0.0, 1.0) = 0.5;
// Scorch darkening and embers.
uniform float scorch = 0.0;
uniform float scorch_size : hint_range(0.05, 1.0) = 0.8;
uniform float embers = 0.0;
uniform float seed = 0.0;
uniform float phase = 0.0;

float af_hash2(vec2 p) {
	p = mod(p, 1024.0);
	return fract(sin(dot(p, vec2(41.37, 289.13)) + 7.31) * 31718.927);
}

float af_noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = af_hash2(i);
	float b = af_hash2(i + vec2(1.0, 0.0));
	float c = af_hash2(i + vec2(0.0, 1.0));
	float d = af_hash2(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float af_fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.55;
	for (int i = 0; i < 4; i++) {
		v += af_noise2(p) * amp;
		p = p * 2.07 + vec2(5.3, 9.1);
		amp *= 0.5;
	}
	return v / 1.03125;
}

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float ang = atan(q.y, q.x);
	vec2 sp = vec2(seed * 7.1, seed * 3.3);
	float n = af_fbm(q * 3.0 + sp);
	vec3 add = vec3(0.0);
	float alpha = 0.0;

	if (flash > 0.0) {
		float f = exp(-(r * r) / (flash_size * flash_size) * 3.0);
		add += (glow_color.rgb * glow_energy * f + core_color.rgb * core_energy * pow(f, 6.0) * 0.3) * flash;
	}
	if (ring > 0.0) {
		float dr = abs(r - ring_radius) / ring_width;
		float band = exp(-dr * dr * 2.0);
		vec2 circ = vec2(cos(ang), sin(ang)) * 2.5;
		float brk = mix(1.0, smoothstep(0.25, 0.75, af_fbm(circ + vec2(ring_radius * 4.0) + sp + phase)), ring_breakup);
		float inner = smoothstep(0.0, ring_radius, r) * 0.25 * step(r, ring_radius);
		add += (glow_color.rgb * glow_energy * (band + inner) + core_color.rgb * core_energy * pow(band, 4.0) * 0.4) * brk * ring;
	}
	if (scorch > 0.0 || embers > 0.0) {
		float rr = r / scorch_size;
		float radial = af_fbm(q * 2.0 / scorch_size + sp) * 0.35;
		float mask = 1.0 - smoothstep(0.35 + n * 0.3, 1.0 + radial * 0.3, rr);
		float cracks = pow(1.0 - abs(af_fbm(q * 4.0 / scorch_size + sp * 1.7) * 2.0 - 1.0), 14.0) * (1.0 - smoothstep(0.2, 0.9, rr));
		alpha = max(alpha, scorch * clamp(mask * (0.75 + 0.25 * n), 0.0, 0.92));
		float hot = pow(clamp(1.0 - rr * 1.25, 0.0, 1.0), 2.0) * (0.5 + n) + cracks * 0.8;
		float flick = 0.8 + 0.2 * af_noise2(vec2(phase * 3.0, seed));
		add += mix(ember_color.rgb, glow_color.rgb, 0.25) * hot * embers * glow_energy * flick;
	}
	float edge = 1.0 - smoothstep(0.9, 1.0, r);
	ALBEDO = add * intensity * edge;
	ALPHA = alpha * edge;
}
