shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform float seed = 0.0;
uniform float intensity : hint_range(0.0, 1.0) = 1.0;

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	vec4 n = fract(sin(vec4(dot(i, vec2(127.1, 311.7))) + vec4(0.0, 127.1, 311.7, 438.8)) * 43758.5453);
	return mix(mix(n.x, n.y, f.x), mix(n.z, n.w, f.x), f.y);
}

void fragment() {
	float y = 1.0 - UV.y;
	float flow = TIME * 5.2 + seed;
	float billow = noise2(vec2(UV.x * 4.8, y * 5.0 - flow));
	float detail = noise2(vec2(UV.x * 11.0 + billow * 0.7, y * 12.0 - flow * 1.7));
	float axis = UV.x - 0.5 + sin(y * 16.0 - flow * 2.1) * 0.064 * y;
	float width = mix(0.34, 0.09, y) + (billow - 0.45) * 0.22;
	float flame = 1.0 - smoothstep(width - 0.04, width + 0.07, abs(axis));
	float crest = 1.0 - smoothstep(0.54 + billow * 0.24, 0.83 + detail * 0.14, y);
	float heat = clamp((1.0 - y) * 0.64 + billow * 0.28 - abs(axis) * 0.85, 0.0, 1.0);
	ALBEDO = mix(vec3(1.22, 0.105, 0.012), vec3(1.92, 0.79, 0.19), smoothstep(0.12, 0.68, heat));
	ALPHA = flame * crest * (0.45 + detail * 0.51) * intensity;
}
