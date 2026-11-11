shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float remaining : hint_range(0.0, 1.0) = 1.0;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	vec3 color = vec3(0.023, 0.038, 0.074);
	if (UV.x < 0.025 || UV.x > 0.975 || UV.y < 0.13 || UV.y > 0.87) {
		color = vec3(0.20, 0.26, 0.38);
	} else if (UV.x <= 0.025 + 0.95 * remaining) {
		color = mix(vec3(0.95, 0.095, 0.17), vec3(1.0, 0.52, 0.16), smoothstep(0.22, 0.82, remaining));
	}
	ALBEDO = color;
}
