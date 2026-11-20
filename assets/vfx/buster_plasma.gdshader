shader_type spatial;
render_mode unshaded, cull_back;

uniform vec4 plasma : source_color = vec4(0.16, 0.82, 1.0, 1.0);
varying float longitude;

void vertex() {
	longitude = VERTEX.z;
	VERTEX.xy *= mix(0.72, 1.07, smoothstep(-1.0, 0.34, VERTEX.z));
}

void fragment() {
	float grazing = 1.0 - max(0.0, dot(normalize(NORMAL), normalize(VIEW)));
	float rim = smoothstep(0.28, 0.94, grazing);
	float nose = smoothstep(-0.18, 0.95, longitude);
	float band = pow(0.5 + 0.5 * cos(longitude * 10.0 - TIME * 28.0), 6.0);
	vec3 deep = mix(plasma.rgb * 0.42, vec3(0.018, 0.068, 0.82), 0.48);
	vec3 hot = mix(plasma.rgb, vec3(0.82, 1.0, 1.0), 0.42);
	vec3 body = mix(deep, plasma.rgb, nose * 0.85 + band * 0.13);
	ALBEDO = mix(body, hot, rim * 0.92);
	EMISSION = ALBEDO * (0.38 + rim * 0.78 + nose * 0.24);
}
