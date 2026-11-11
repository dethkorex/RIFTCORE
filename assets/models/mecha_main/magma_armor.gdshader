shader_type spatial;
uniform sampler2D original : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D original_normal : hint_normal, filter_linear_mipmap;
uniform bool use_normal = false;
void fragment() {
	vec4 base = texture(original, UV);
	float brightness = max(base.r, max(base.g, base.b));
	float blue = smoothstep(0.045, 0.24, max(base.b, base.g) - base.r) * step(base.r, base.b);
	float hot = smoothstep(0.30, 0.83, base.g) * blue;
	vec3 painted = mix(vec3(0.055, 0.043, 0.040), vec3(0.63, 0.145, 0.038), clamp(brightness * 1.21, 0.0, 1.0));
	painted = mix(painted, vec3(1.0, 0.31, 0.06), hot);
	ALBEDO = mix(base.rgb, painted, blue * 0.96);
	EMISSION = vec3(1.0, 0.22, 0.015) * hot * 1.20;
	ROUGHNESS = 0.46;
	METALLIC = 0.25;
	if (use_normal) {
		NORMAL_MAP = texture(original_normal, UV).rgb;
	}
}
