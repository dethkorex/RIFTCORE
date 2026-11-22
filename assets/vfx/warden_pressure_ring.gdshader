shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 heat : source_color = vec4(1.0, 0.44, 0.11, 1.0);
uniform float travel : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float angle = atan(p.y, p.x);
	float radius = length(p);
	float pulse = mix(0.17, 0.91, travel);
	float noise = 0.70 + 0.30 * sin(angle * 13.0 + travel * 6.0);
	float crest = exp(-pow((radius - pulse) / 0.022, 2.0));
	float haze = exp(-pow((radius - pulse + 0.035) / 0.10, 2.0));
	ALBEDO = mix(heat.rgb, vec3(1.0, 0.86, 0.63), crest) * (0.65 + crest * 1.4);
	ALPHA = (0.72 * crest + 0.32 * haze) * noise * (1.0 - smoothstep(0.12, 1.0, travel));
}
