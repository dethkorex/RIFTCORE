shader_type spatial;
uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 tint : source_color = vec4(0.21, 0.27, 0.43, 1.0);
uniform float band = 0.0;
uniform float texture_mix : hint_range(0.0, 1.0) = 0.85;
varying vec3 local_at;
varying vec3 local_normal;
vec3 sample_trim(vec2 p, float vertical) {
	vec2 uv = vec2(p.x * 0.129 + 0.125, fract(p.y * vertical + 0.5) * 0.235 + 0.008 + band * 0.25);
	vec2 scale = vec2(0.129, vertical * 0.235);
	return textureGrad(atlas, uv, dFdx(p) * scale, dFdy(p) * scale).rgb;
}
void vertex() {
	local_at = VERTEX;
	local_normal = NORMAL;
}
void fragment() {
	vec3 weight = pow(abs(normalize(local_normal)), vec3(5.0));
	weight /= max(0.01, weight.x + weight.y + weight.z);
	vec3 surface = sample_trim(local_at.zy, 2.65) * weight.x
	             + sample_trim(local_at.xz, 0.48) * weight.y
	             + sample_trim(local_at.xy, 2.65) * weight.z;
	ALBEDO = mix(tint.rgb, surface * 0.82 + tint.rgb * 0.17, texture_mix);
	METALLIC = 0.31;
	ROUGHNESS = 0.53;
}
