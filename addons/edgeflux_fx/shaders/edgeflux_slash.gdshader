// EDGEFLUX slash, additive glow variant.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

#include "res://addons/edgeflux_fx/shaders/edgeflux_slash.gdshaderinc"

void fragment() {
	EfSlash o = ef_slash(UV, UV2);
	vec3 body = mix(glow_color.rgb, tail_color.rgb, clamp(o.r * 0.8 + (1.0 - o.s) * 0.6, 0.0, 1.0)) * glow_energy;
	float body_a = o.mask * (0.45 + 0.75 * (1.0 - o.r)) * o.n * (0.45 + 0.75 * o.s);
	vec3 col = body * body_a + core_color.rgb * core_energy * o.edge * o.mask;
	ALBEDO = col * intensity;
}
