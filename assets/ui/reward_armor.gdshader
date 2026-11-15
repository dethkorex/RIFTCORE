shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled;

uniform vec4 suit_color : source_color = vec4(0.2, 0.6, 1.0, 1.0);
uniform sampler2D base_armor : source_color, filter_linear_mipmap;

void fragment() {
	vec3 paint = texture(base_armor, UV).rgb;
	float chroma = max(paint.g, paint.b) - paint.r;
	float alloy = smoothstep(0.015, 0.13, chroma);
	float powered = alloy * smoothstep(0.20, 0.60, paint.g);
	float edge = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 2.4);
	ALBEDO = suit_color.rgb * (0.23 + 0.28 * edge + 0.64 * powered);
	EMISSION = suit_color.rgb * (0.07 * edge + 0.55 * powered);
	ALPHA = max(0.09 + edge * 0.19, 0.77 * alloy + 0.22 * powered);
}
