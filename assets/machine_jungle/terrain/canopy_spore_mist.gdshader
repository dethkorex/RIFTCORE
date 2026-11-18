shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 spores : source_color = vec4(0.62, 0.89, 0.22, 1.0);
uniform float drift = 0.0;
uniform float density = 0.46;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 base = floor(p);
	vec2 f = smoothstep(vec2(0.0), vec2(1.0), fract(p));
	return mix(mix(hash(base), hash(base + vec2(1.0, 0.0)), f.x),
		mix(hash(base + vec2(0.0, 1.0)), hash(base + vec2(1.0)), f.x), f.y);
}

void fragment() {
	vec2 wind = vec2(UV.x * 24.0 - TIME * 0.64 + drift, UV.y * 3.0 + TIME * 0.24);
	float clouds = noise(wind) * 0.65 + noise(wind * 2.13 + vec2(5.0, 0.0)) * 0.35;
	float top = 0.28 - clouds * 0.23;
	float body = smoothstep(top, top + 0.32, UV.y) * (1.0 - smoothstep(0.66, 1.0, UV.y));
	float sides = smoothstep(0.0, 0.10, UV.x) * (1.0 - smoothstep(0.90, 1.0, UV.x));
	ALBEDO = spores.rgb * mix(0.65, 1.1, clouds);
	ALPHA = body * sides * smoothstep(0.10, 0.89, clouds) * density;
}
