shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;

uniform int mode = 0;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float heat : hint_range(0.0, 1.0) = 0.0;
uniform float direction = 1.0;
uniform float span = 2.0;
uniform vec4 tint : source_color = vec4(1.0, 0.23, 0.06, 1.0);

float line(float value, float center, float half_width) {
	return 1.0 - smoothstep(half_width, half_width + 0.012, abs(value - center));
}

void fragment() {
	vec2 point = UV * 2.0 - 1.0;
	vec2 edge = abs(point);
	float envelope = (1.0 - smoothstep(0.90, 1.0, edge.x)) * (1.0 - smoothstep(0.83, 1.0, edge.y));
	float near_rail = line(edge.y, 0.78, 0.059);
	float far_rail = line(edge.x, 0.92, 0.046);
	float pace = 0.8 + 0.2 * sin(progress * 18.0);
	float hot = max(progress, heat);
	float pattern;
	if (mode == 3) {
		float u = direction > 0.0 ? UV.x : 1.0 - UV.x;
		float sweep = u * max(span / 1.52, 1.0) - progress * 2.55;
		float tip = fract(sweep + 0.33 * edge.y);
		pattern = line(tip, 0.44, 0.119) * (1.0 - smoothstep(0.42, 0.70, edge.y));
	} else if (mode == 1) {
		float channels = line(fract((point.y + 1.0) * 2.5), 0.50, 0.096);
		float traveling_heat = smoothstep(0.12, 0.87, fract(UV.x * 1.7 - progress * 1.42 + point.y * 0.2));
		pattern = channels * (0.44 + 0.56 * traveling_heat);
	} else {
		float winding = point.x * 5.45 + point.y * 2.7 + sin(point.y * 7.1 + floor(UV.x * 4.0) * 1.6) * 0.31;
		pattern = line(fract(winding), 0.48, 0.074) * (0.58 + hot * 0.42);
	}
	float edge_bolts = line(fract((UV.x + 0.015) * max(span * 1.7, 5.0)), 0.40, 0.09) * line(edge.y, 0.75, 0.09);
	float trim = max(near_rail * 0.83, far_rail * 0.88) + edge_bolts * 0.32;
	float signal_strength = max(trim, pattern * (0.72 + hot * 0.28));
	float mask = envelope * (0.14 + signal_strength * 0.82);
	float brightness = (0.52 + pace * 0.16 + hot * 0.52) * (0.65 + 0.56 * pattern);
	vec3 warm_edge = mix(tint.rgb, vec3(1.0, 0.69, 0.26), 0.70);
	vec3 color = mix(tint.rgb * 0.42, warm_edge, clamp(signal_strength * 1.35, 0.0, 1.0));
	ALBEDO = color;
	EMISSION = color * brightness * (1.4 + heat * 0.8);
	ALPHA = min(mask * (0.84 + 0.16 * hot), 0.93);
}
