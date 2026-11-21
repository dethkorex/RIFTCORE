shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled, depth_draw_never;
uniform vec4 shield_tint : source_color = vec4(0.12, 0.65, 1.0, 1.0);

void fragment() {
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.1);
	float sweep = pow(max(0.0, cos((UV.y - TIME * 0.26) * 12.566)), 24.0);
	ALBEDO = shield_tint.rgb * (1.0 + rim * 1.4);
	ALPHA = 0.045 + rim * 0.82 + sweep * (0.035 + rim * 0.11);
}
