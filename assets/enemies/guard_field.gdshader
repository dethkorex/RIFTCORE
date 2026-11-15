shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;

uniform vec4 field_color : source_color = vec4(0.55, 0.30, 0.95, 1.0);
uniform float hit_strength = 0.0;
uniform vec2 hit_origin = vec2(0.5);

float hex_outline(vec2 p) {
	vec2 pitch = vec2(1.0, 1.73205);
	vec2 a = mod(p + pitch * 0.5, pitch) - pitch * 0.5;
	vec2 b = mod(p, pitch) - pitch * 0.5;
	vec2 cell = abs(dot(a,a) < dot(b,b) ? a : b);
	float edge = max(cell.x, dot(cell, vec2(0.5,0.866025)));
	return smoothstep(0.444, 0.493, edge);
}

void fragment() {
	vec2 p = abs(UV * 2.0 - 1.0);
	float panel = max(max(p.x, p.y), 0.62 * (p.x + p.y));
	float coverage = 1.0 - smoothstep(0.974, 1.0, panel);
	float lip = smoothstep(0.919, 0.961, panel) * coverage;
	float line = hex_outline(UV * vec2(9.0, 11.0));
	float band = smoothstep(0.72, 0.97, sin(UV.y * 17.0 - TIME * 3.75));
	float burst_radius = mix(0.74, 0.035, hit_strength);
	float radius = distance(UV * vec2(1.0, 1.14), hit_origin * vec2(1.0, 1.14));
	float shock = (1.0 - smoothstep(0.01, 0.075, abs(radius - burst_radius))) * hit_strength;
	float center = (1.0 - smoothstep(0.00, 0.25, radius)) * hit_strength * hit_strength;
	ALBEDO = field_color.rgb + (lip * 0.59 + shock * 0.9 + center * 1.25) * vec3(0.66, 0.8, 1.0);
	ALPHA = coverage * clamp(0.10 + lip * 0.66 + 0.18 * line + band * 0.075 + 0.53 * shock + 0.74 * center, 0.0, 0.95);
}
