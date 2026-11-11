shader_type spatial;
render_mode unshaded;

varying float level;

void vertex() {
	level = VERTEX.y;
}

void fragment() {
	float edge = pow(1.0 - abs(dot(normalize(NORMAL), VIEW)), 2.4);
	float scan = smoothstep(0.78, 0.99, sin(level * 105.0 - TIME * 1.3));
	ALBEDO = vec3(0.045, 0.16, 0.25) + vec3(0.09, 0.51, 0.68) * edge + vec3(0.017, 0.08, 0.09) * scan;
}
