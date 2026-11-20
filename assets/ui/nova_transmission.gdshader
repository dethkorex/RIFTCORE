shader_type canvas_item;

uniform float strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 drone = texture(TEXTURE, UV);
	float noise = fract(sin(dot(floor(UV * vec2(36.0, 56.0)), vec2(12.9898, 78.233))) * 43758.5453);
	float scan = abs(UV.y - (1.06 - strength * 1.12));
	float edge = (1.0 - smoothstep(0.02, 0.17, scan)) * (1.0 - strength);
	float dissolve = smoothstep(noise - 0.15, noise + 0.15, mix(-0.15, 1.15, strength));
	float flicker = 0.5 + 0.5 * sin(UV.y * 330.0 - TIME * 26.0);
	vec3 signal = vec3(0.18, 0.95, 1.0);
	vec3 result = mix(drone.rgb, signal, edge * 0.75 + (1.0 - strength) * 0.28);
	result += signal * flicker * edge * 0.7;
	COLOR = vec4(result, drone.a * dissolve);
}
