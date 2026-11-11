shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform vec4 tint : source_color = vec4(0.22, 0.82, 0.4, 1.0);
uniform int mark = 0;

void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float angle = mark == 1 ? -0.46 : (mark == 2 ? 0.36 : -0.16);
	vec2 q = mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle))) * p;
	q.y /= mark == 0 ? 0.63 : 0.72;
	float distance_to_center = length(q);
	float azimuth = atan(q.y, q.x);
	float spin = (mark == 1 ? 2.3 : 1.25) * TIME;
	float segment = pow(0.5 + 0.5 * cos(azimuth * (mark == 2 ? 6.0 : 3.0) - spin), 3.0);
	float stroke = 1.0 - smoothstep(0.012, 0.039, abs(distance_to_center - 0.73));
	float haze = exp(-pow((distance_to_center - 0.73) * 17.0, 2.0)) * 0.10;
	float spark = pow(0.5 + 0.5 * cos(azimuth - spin), 78.0);
	float band = 1.0 - smoothstep(0.019, 0.067, abs(distance_to_center - 0.73));
	ALBEDO = mix(tint.rgb, vec3(0.95, 0.98, 1.0), 0.34 + 0.46 * spark);
	ALPHA = stroke * (0.12 + 0.61 * segment) + haze + band * spark * 0.85;
}
