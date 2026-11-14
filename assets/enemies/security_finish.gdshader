shader_type spatial;
uniform sampler2D armor_albedo : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D trim_height : filter_linear_mipmap_anisotropic;
uniform vec4 chassis_coat : source_color = vec4(1.);
uniform float alloy = .26;
uniform float roughness_bias = .53;
uniform float relief : hint_range(0.0, 0.08) = 0.014;
void fragment() {
	vec3 coating = texture(armor_albedo, UV).rgb;
	float height = texture(trim_height, UV).r;
	vec3 n = normalize(NORMAL);
	vec3 dx = dFdx(VERTEX);
	vec3 dy = dFdy(VERTEX);
	vec3 tangent_u = cross(dy, n);
	vec3 tangent_v = cross(n, dx);
	float det = dot(dx, tangent_u);
	vec3 gradient = dFdx(height) * tangent_u + dFdy(height) * tangent_v;
	NORMAL = normalize(max(abs(det), 0.0000001) * n - sign(det) * gradient * relief);
	ALBEDO = coating * chassis_coat.rgb * mix(0.76, 1.02, smoothstep(0.18, 0.64, height));
	METALLIC = alloy;
	ROUGHNESS = clamp(roughness_bias + .10 * (1. - height), .1, .85);
}
