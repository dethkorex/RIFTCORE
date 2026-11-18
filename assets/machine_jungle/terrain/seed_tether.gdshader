shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

void fragment() {
	float braid = sin(UV.x * 58.0 - TIME * 7.2) * 0.22;
	float strands = 1.0 - smoothstep(0.025, 0.10, abs(abs(UV.y - 0.5) - abs(braid)));
	float glow = 1.0 - smoothstep(0.04, 0.44, abs(UV.y - 0.5));
	float flow = smoothstep(0.45, 1.0, sin(UV.x * 22.0 - TIME * 6.0));
	ALBEDO = mix(vec3(0.12, 0.48, 0.18), vec3(0.63, 1.0, 0.22), flow);
	ALPHA = glow * 0.16 + strands * (0.35 + flow * 0.44);
}
