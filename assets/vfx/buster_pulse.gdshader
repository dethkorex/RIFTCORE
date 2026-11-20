shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform vec4 ion_color : source_color = vec4(0.28, 0.88, 1.0, 1.0);
uniform float intensity : hint_range(0.0, 1.0) = 0.72;

void fragment() {
	float facing = abs(dot(normalize(VIEW), normalize(NORMAL)));
	ALBEDO = ion_color.rgb * (0.64 + facing * 0.8);
	ALPHA = intensity * smoothstep(0.02, 0.88, facing);
}
