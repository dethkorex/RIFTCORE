shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;
void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float r = length(p);
	float aa = max(0.012, fwidth(r));
	float rim = 1.0 - smoothstep(0.043, 0.043 + aa, abs(r - 0.82));
	float inner = 1.0 - smoothstep(0.020, 0.020 + aa, abs(r - 0.63));
	float stripe = smoothstep(0.20, 0.44, fract((p.x + p.y) * 7.5 + TIME * 0.66));
	float pulse = 0.68 + 0.27 * sin(TIME * 14.0);
	float fill = (1.0 - smoothstep(0.56, 0.69, r)) * stripe;
	ALBEDO = mix(vec3(0.85, 0.13, 0.05), vec3(1.0, 0.47, 0.22), rim);
	ALPHA = clamp(rim * pulse + inner * 0.55 + fill * 0.26, 0.0, 0.94);
}
