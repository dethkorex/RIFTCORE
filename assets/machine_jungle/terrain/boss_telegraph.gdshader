shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 tint : source_color;
uniform float progress : hint_range(0.0, 1.0);
uniform float stripe_count = 7.0;
uniform float direction = 0.0;

void fragment() {
	vec2 edge = min(UV, 1.0 - UV);
	float rails = 1.0 - smoothstep(0.019, 0.064, edge.y);
	float ends = 1.0 - smoothstep(0.004, 0.024, edge.x);
	float lines = smoothstep(0.72, 0.92, fract(UV.x * stripe_count + abs(UV.y - 0.5) * 1.1 - TIME * direction * 2.0));
	float sweeping = 1.0 - smoothstep(0.035, 0.095, abs(UV.y - progress));
	ALBEDO = tint.rgb * (0.75 + lines * 0.35 + max(ends, rails) * 0.48);
	EMISSION = tint.rgb * (0.34 + max(ends, rails) * 0.42);
	ALPHA = (0.24 + 0.11 * progress + sweeping * 0.15 + lines * 0.17 + max(ends, rails) * 0.48) * tint.a;
}
