shader_type spatial;
render_mode unshaded, shadows_disabled;
uniform sampler2D trim : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(0.08, 0.13, 0.23, 1.0);
varying vec3 world_at;
void vertex() {
	world_at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 facade = vec2(world_at.x + world_at.z * 0.43, world_at.y);
	vec2 uv = vec2(fract(facade.x * 0.24), 0.29 + 0.18 * fract(facade.y * 0.51));
	vec3 atlas = textureGrad(trim, uv, dFdx(facade) * vec2(0.24, 0.0918), dFdy(facade) * vec2(0.24, 0.0918)).rgb;
	float panel = smoothstep(0.08, 0.17, fract(facade.y * 0.43));
	float haze = smoothstep(12.0, 36.0, -world_at.z);
	ALBEDO = mix(tint.rgb * (0.63 + panel * 0.31) + atlas * 0.19, vec3(0.038, 0.080, 0.18), haze * 0.42);
}
