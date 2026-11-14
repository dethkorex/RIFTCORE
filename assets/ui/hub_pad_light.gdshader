shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform vec4 tint : source_color = vec4(0.20, 1.0, 0.80, 1.0);
varying float height;

void vertex() {
	height = clamp((VERTEX.y + 1.325) / 2.65, 0.0, 1.0);
}

void fragment() {
	float stripe = pow(0.5 + 0.5 * cos(height * 31.0 - TIME * 7.2), 6.0);
	float bars = pow(0.5 + 0.5 * cos(UV.x * 75.398 + TIME * 0.7), 14.0);
	float raster = stripe * (0.43 + 0.57 * bars);
	ALBEDO = mix(tint.rgb, vec3(0.92, 1.0, 1.0), raster * 0.65);
	ALPHA = (0.097 + 0.29 * raster + 0.11 * bars) * pow(1.0 - height, 1.34);
}
