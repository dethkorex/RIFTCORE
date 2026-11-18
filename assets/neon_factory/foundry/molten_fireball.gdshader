shader_type spatial;
render_mode unshaded, depth_prepass_alpha, shadows_disabled;

uniform vec4 flame_tint : source_color = vec4(1.0, 0.24, 0.07, 1.0);
uniform bool wake = false;
varying vec3 local_position;

float hash(vec3 point) {
	return fract(sin(dot(point, vec3(21.27, 93.11, 46.77))) * 31791.137);
}

float noise(vec3 point) {
	vec3 cell = floor(point);
	vec3 part = fract(point);
	part = part * part * (3.0 - 2.0 * part);
	return mix(
		mix(mix(hash(cell), hash(cell + vec3(1, 0, 0)), part.x),
			mix(hash(cell + vec3(0, 1, 0)), hash(cell + vec3(1, 1, 0)), part.x), part.y),
		mix(mix(hash(cell + vec3(0, 0, 1)), hash(cell + vec3(1, 0, 1)), part.x),
			mix(hash(cell + vec3(0, 1, 1)), hash(cell + vec3(1, 1, 1)), part.x), part.y),
		part.z
	);
}

void vertex() {
	local_position = VERTEX;
	if (wake) {
		float taper = smoothstep(-0.87, 0.42, VERTEX.y);
		VERTEX.xz *= 0.4 + taper * 0.65;
	}
}

void fragment() {
	vec3 flow = local_position * vec3(11.5, 7.0, 11.5) + vec3(0.0, TIME * 13.0, 0.0);
	float turbulence = noise(flow) * 0.68 + noise(flow * 2.35) * 0.32;
	float facing = max(dot(normalize(NORMAL), VIEW), 0.0);
	float hot = smoothstep(0.24, 0.78, turbulence + 0.13 * facing);
	vec3 color = mix(flame_tint.rgb * 0.32, vec3(1.0, 0.67, 0.14), hot);
	if (wake) {
		float length_fade = smoothstep(-0.87, 0.30, local_position.y);
		color = mix(flame_tint.rgb * 0.14, color, length_fade);
		ALPHA = length_fade * facing * smoothstep(0.28, 0.75, turbulence) * 0.9;
	} else {
		ALPHA = 1.0;
	}
	ALBEDO = color;
	EMISSION = color * (0.72 + hot * 0.64);
}
