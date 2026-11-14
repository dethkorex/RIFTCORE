// EDGEFLUX weapon trail, solid variant: flat bands and a crisp outline.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

#include "res://addons/edgeflux_fx/shaders/edgeflux_trail.gdshaderinc"

void fragment() {
	EfTrail o = ef_trail(UV);
	float m = step(0.35, o.mask);
	vec3 col = mix(glow_color.rgb, tail_color.rgb, step(0.55, o.age));
	col = mix(col, core_color.rgb, step(0.8, o.y) * step(o.age, 0.6));
	col = mix(col, outline_color.rgb, step(o.y, 0.12));
	ALBEDO = col;
	ALPHA = m * clamp(intensity, 0.0, 1.0);
}
