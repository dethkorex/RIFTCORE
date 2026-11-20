shader_type canvas_item;

uniform float surge : hint_range(0.0, 1.0) = 0.0;

float fissure(vec2 uv, float x, float start, float end, float lean) {
	float y = (uv.y - start) / (end - start);
	float edge = abs(uv.x - x - y * lean - 0.029 * sin(17.0 * y) - 0.009 * sin(61.0 * y));
	float visible = step(0.0, y) * step(y, 1.0) * step(y, surge);
	return visible * exp(-edge * 120.0);
}

void fragment() {
	float split = fissure(UV, 0.47, 0.15, 0.89, 0.07);
	split += 0.70 * fissure(UV, 0.49, 0.44, 0.75, -0.24);
	split += 0.62 * fissure(UV, 0.51, 0.52, 0.82, 0.18);
	vec3 glow = mix(vec3(0.97, 0.20, 0.12), vec3(1.0, 0.93, 0.68), clamp(split, 0.0, 1.0));
	COLOR = vec4(glow, clamp(split * 0.88, 0.0, 0.93));
}
