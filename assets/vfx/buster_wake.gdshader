shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform vec4 ion_color : source_color = vec4(0.21, 0.8, 1.0, 1.0);

void fragment() {
	float along = UV.x;
	float width = mix(0.11, 0.94, sqrt(along));
	float off_axis = abs(UV.y * 2.0 - 1.0) / width;
	float halo = 1.0 - smoothstep(0.12, 1.0, off_axis);
	float filament = 1.0 - smoothstep(0.0, 0.28, off_axis);
	float flow = 0.84 + 0.16 * sin(along * 28.0 - TIME * 32.0);
	ALBEDO = mix(ion_color.rgb, vec3(1.0), filament * 0.24);
	ALPHA = smoothstep(0.0, 0.68, along) * (halo * 0.26 + filament * 0.66) * flow;
}
