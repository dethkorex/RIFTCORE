shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;

uniform vec4 charge_color : source_color = vec4(1.0, .59, .13, 1.);
uniform float intensity = 1.0;
varying vec3 local_surface;

void vertex() {
	local_surface = VERTEX;
}

void fragment() {
	float rim = pow(1. - clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0., 1.), 2.45);
	float flow = sin(local_surface.y * 31. - TIME * 6.) * .5 + .5;
	float pulse = .64 + .36 * sin(TIME * 8.7);
	ALBEDO = charge_color.rgb * (1.12 + pulse * .32);
	ALPHA = intensity * (.065 + rim * .49 + flow * .075);
}
