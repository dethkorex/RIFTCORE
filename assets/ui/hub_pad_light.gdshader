shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform vec4 tint : source_color = vec4(0.20, 1.0, 0.80, 1.0);
varying float height;

void vertex() {
	height = clamp((VERTEX.y + 1.125) / 2.25, 0.0, 1.0);
}

void fragment() {
	float stripes = pow(0.5 + 0.5 * cos(height * 34.0 - TIME * 6.4), 9.0);
	ALBEDO = tint.rgb;
	ALPHA = (0.055 + 0.10 * stripes) * pow(1.0 - height, 1.45);
}
