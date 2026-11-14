shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.85, 0.16, 0.42, 1.0);
uniform bool live = false;

void fragment() {
	vec2 p = abs(UV * 2.0 - 1.0);
	float edge = max(p.x, p.y);
	float stroke = smoothstep(0.80, 0.87, edge) * (1.0 - smoothstep(0.965, 1.0, edge));
	float band = smoothstep(0.46, 0.66, fract(UV.x * 7.0 + UV.y * 3.0 - TIME * (live ? 2.0 : 0.90)));
	float pulse = 0.82 + 0.18 * cos(TIME * 8.0);
	vec3 color = live ? tint.rgb : vec3(1.0, 0.66, 0.18);
	ALBEDO = mix(color, vec3(1.0, 0.91, 0.74), stroke * 0.63);
	ALPHA = (0.12 + 0.32 * band + 0.54 * stroke) * pulse * (1.0 - smoothstep(0.97, 1.0, edge));
}
