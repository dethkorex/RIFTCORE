// EDGEFLUX weapon trail, additive glow variant.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

#include "res://addons/edgeflux_fx/shaders/edgeflux_trail.gdshaderinc"

void fragment() {
	EfTrail o = ef_trail(UV);
	vec3 body = mix(glow_color.rgb, tail_color.rgb, clamp(o.age * 1.3 + (1.0 - o.y) * 0.4, 0.0, 1.0)) * glow_energy;
	vec3 col = body * o.body + core_color.rgb * core_energy * o.edge;
	ALBEDO = col * o.mask * intensity;
}
