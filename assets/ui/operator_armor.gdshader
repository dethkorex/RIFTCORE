shader_type spatial;
render_mode specular_schlick_ggx;

uniform sampler2D artwork : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D detail_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_normal = false;
uniform float detail_strength = 1.0;
uniform vec4 armor : source_color;
uniform vec4 trim : source_color;
uniform vec4 light_color : source_color;

void fragment() {
	vec3 source = texture(artwork, UV).rgb;
	vec3 pigment = OUTPUT_IS_SRGB ? source : pow(max(source, vec3(0.0)), vec3(1.0 / 2.2));
	float value = dot(pigment, vec3(0.2126, 0.7152, 0.0722));
	float outer_panel = smoothstep(0.22, 0.60, value) * smoothstep(0.16, 0.46, pigment.r);
	float inset_panel = smoothstep(0.045, 0.21, pigment.b - pigment.r) * smoothstep(0.14, 0.37, pigment.b);
	float lit = smoothstep(0.24, 0.58, pigment.g) * smoothstep(0.12, 0.33, pigment.g - pigment.r)
		* smoothstep(0.24, 0.63, pigment.b);
	float outer_detail = mix(0.48, 1.06, smoothstep(0.19, 0.91, value));
	float inset_detail = mix(0.32, 1.02, smoothstep(0.12, 0.53, pigment.b));
	vec3 joints = mix(vec3(0.027), vec3(0.095), smoothstep(0.04, 0.48, value));
	vec3 painted = mix(joints, trim.rgb * inset_detail, inset_panel);
	painted = mix(painted, armor.rgb * outer_detail, outer_panel);
	ALBEDO = mix(painted, light_color.rgb * 0.72, lit);
	EMISSION = light_color.rgb * lit * 0.74;
	METALLIC = mix(0.16, 0.48, max(outer_panel * 0.54, inset_panel));
	ROUGHNESS = mix(0.63, 0.31, max(outer_panel * 0.85, inset_panel));
	if (has_normal) {
		NORMAL_MAP = texture(detail_normal, UV).rgb;
		NORMAL_MAP_DEPTH = detail_strength;
	}
}
