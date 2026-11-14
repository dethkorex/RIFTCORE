// EDGEFLUX slash, solid variant: flat colour bands with a crisp outline (cartoon / cel-shaded games).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

#include "res://addons/edgeflux_fx/shaders/edgeflux_slash.gdshaderinc"

void fragment() {
	EfSlash o = ef_slash(UV, UV2);
	float m = step(0.5, o.mask);
	vec3 col = glow_color.rgb;
	col = mix(col, core_color.rgb, step(UV.y, o.band * 0.28) * step(0.25, o.s));
	col = mix(col, outline_color.rgb, step(0.78, o.r));
	ALBEDO = col * mix(1.0, intensity, 0.5);
	ALPHA = m * clamp(intensity, 0.0, 1.0);
}
