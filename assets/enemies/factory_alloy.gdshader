shader_type spatial;

uniform vec4 alloy : source_color = vec4(0.24, 0.29, 0.36, 1.0);
uniform vec4 coating : source_color = vec4(0.13, 0.19, 0.26, 1.0);
varying vec3 local_position;

float hash(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	vec2 cell = floor(UV * vec2(700.0, 45.0));
	float machining = hash(cell);
	float chips = step(0.985, hash(floor(UV * 170.0)));
	float panel = smoothstep(0.24, 0.29, abs(local_position.y));
	float grooves = 1.0 - smoothstep(0.009, 0.02, abs(fract(UV.y * 4.0) - 0.5));
	vec3 base = mix(alloy.rgb, coating.rgb, panel * 0.55 + grooves * 0.24);
	ALBEDO = base * (0.80 + machining * 0.20) + vec3(chips * 0.095);
	METALLIC = 0.64;
	ROUGHNESS = 0.40 + machining * 0.16;
}
