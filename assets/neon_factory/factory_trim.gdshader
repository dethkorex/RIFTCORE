shader_type spatial;
uniform sampler2D trim : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 tint : source_color = vec4(0.14, 0.18, 0.29, 1.0);
uniform float band = 1.0;
uniform float strength : hint_range(0.0, 1.0) = 0.5;
varying vec3 local_at;
varying vec3 local_normal;
vec3 detail(vec2 p) {
	vec2 mapped = vec2(fract(p.x * 0.34), (band + 0.08 + 0.84 * fract(p.y * 0.92)) * 0.25);
	return textureGrad(trim, mapped, dFdx(p) * vec2(0.34, 0.1932), dFdy(p) * vec2(0.34, 0.1932)).rgb;
}
void vertex() {
	local_at = VERTEX;
	local_normal = NORMAL;
}
void fragment() {
	vec3 w = pow(abs(normalize(local_normal)), vec3(6.0));
	w /= max(0.001, w.x + w.y + w.z);
	vec3 pat = detail(local_at.zy) * w.x + detail(local_at.xz) * w.y + detail(local_at.xy) * w.z;
	float luma = dot(pat, vec3(0.3, 0.59, 0.11));
	ALBEDO = tint.rgb * mix(1.0, 0.64 + luma * 1.65, strength) + pat * strength * 0.10;
	ROUGHNESS = clamp(0.55 - luma * 0.26, 0.34, 0.68);
	METALLIC = 0.43;
}
