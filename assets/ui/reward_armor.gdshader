shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled;

uniform vec4 suit_color : source_color = vec4(0.2, 0.6, 1.0, 1.0);
varying vec3 surface_position;

void vertex() {
	surface_position = VERTEX;
}

void fragment() {
	float edge = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 2.4);
	float band = smoothstep(0.25, 0.73, sin(surface_position.y * 18.0 + surface_position.x * 8.0));
	ALBEDO = suit_color.rgb * (0.46 + edge * 0.67);
	EMISSION = suit_color.rgb * (0.12 + 0.43 * edge);
	ALPHA = 0.25 + band * 0.10 + edge * 0.24;
}
