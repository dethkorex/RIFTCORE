shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 tint : source_color = vec4(1.0, 0.2, 0.6, 1.0);
uniform float activity = 0.0;
uniform int style = 0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float fade = (1.0 - smoothstep(0.73, 1.0, abs(p.x))) * (1.0 - smoothstep(0.70, 1.0, abs(p.y)));
	float clock = TIME * (0.35 + activity);
	float veins = sin(20.0 * p.x + 8.0 * p.y + 2.0 * sin(13.0 * p.y - clock * 2.0) + clock);
	float branches = pow(1.0 - abs(veins), 11.0);
	float ripples = pow(0.5 + 0.5 * sin(p.y * 29.0 + sin(p.x * 16.0 + clock) - clock * 4.0), 9.0);
	float seam = 1.0 - smoothstep(0.002, 0.014, abs(abs(p.y) - 0.78));
	float pattern = style == 1 ? ripples : branches;
	ALBEDO = tint.rgb * (0.44 + 0.74 * pattern);
	EMISSION = tint.rgb * (0.22 + activity * 2.1) * pattern;
	ALPHA = fade * (0.06 + pattern * (0.33 + activity * 0.34) + seam * (0.22 + 0.44 * activity));
}
