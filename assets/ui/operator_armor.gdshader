shader_type spatial;

uniform sampler2D artwork : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 armor : source_color;
uniform vec4 trim : source_color;

void fragment() {
	vec3 source = texture(artwork, UV).rgb;
	float value = dot(source, vec3(0.2126, 0.7152, 0.0722));
	float chroma = max(source.b, source.g) - source.r;
	float powered = smoothstep(0.025, 0.18, chroma);
	float panel = smoothstep(0.04, 0.62, value);
	vec3 shell = mix(vec3(0.008), armor.rgb, panel) * (0.65 + 0.52 * panel);
	ALBEDO = mix(shell, trim.rgb * (0.10 + value * 0.93), powered);
	EMISSION = trim.rgb * powered * smoothstep(0.18, 0.56, value) * 0.52;
	METALLIC = 0.48;
	ROUGHNESS = 0.49;
}
