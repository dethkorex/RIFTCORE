shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled;
uniform vec4 saber_color : source_color = vec4(.12,.82,1.,1.);
void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float light = pow(facing, 2.9) * .34;
	ALBEDO = saber_color.rgb;
	EMISSION = saber_color.rgb * .55;
	ALPHA = light;
}
