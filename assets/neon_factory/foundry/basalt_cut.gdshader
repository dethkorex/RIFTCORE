shader_type spatial;

// World-space joints run continuously across neighbouring faces of each rock cut.
uniform sampler2D basalt : source_color, repeat_enable, filter_linear_mipmap;
varying vec3 rock_position;
varying vec3 rock_normal;

void vertex() {
	rock_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	rock_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

float noise_at(vec2 p) {
	vec2 cell = floor(p);
	vec2 t = smoothstep(vec2(0.0), vec2(1.0), fract(p));
	vec4 phase = dot(cell, vec2(37.1, 71.7)) + vec4(0.0, 37.1, 71.7, 108.8);
	vec4 values = fract(sin(phase) * 13837.5);
	return mix(mix(values.x, values.y, t.x), mix(values.z, values.w, t.x), t.y);
}

void fragment() {
	vec3 w = abs(normalize(rock_normal));
	vec2 p = rock_position.xy;
	if (w.y > max(w.x, w.z)) {
		p = rock_position.xz;
	} else if (w.x > w.z) {
		p = rock_position.zy;
	}
	float relief = noise_at(p * 1.8) * 0.18 + noise_at(p * 7.2) * 0.038;
	vec2 fracture = vec2(p.x * 0.76 + p.y * 0.17, p.y * 1.12 - p.x * 0.10);
	fracture.y += noise_at(p * 0.66) * 0.65 + relief;
	float row = floor(fracture.y);
	fracture.x += sin(row * 33.18) * 2.1 + noise_at(p * 0.9) * 0.42;
	vec2 uv = fract(fracture);
	vec2 edge = min(uv, 1.0 - uv);
	float joint = smoothstep(0.009, 0.077, min(edge.x, edge.y));
	float facet = noise_at(floor(fracture) * 1.97);
	float grain = texture(basalt, p * 0.38).r;
	vec3 stone = mix(vec3(0.075, 0.061, 0.059), vec3(0.26, 0.20, 0.16), facet * 0.56 + relief + grain * 0.22);
	ALBEDO = stone * mix(0.51, 1.0, joint);
	ROUGHNESS = mix(0.95, 0.79, facet);
	float bump = joint * 0.032 + relief * 0.074;
	vec3 along_x = cross(dFdy(VERTEX), NORMAL);
	vec3 along_y = cross(NORMAL, dFdx(VERTEX));
	float area = dot(dFdx(VERTEX), along_x);
	NORMAL = normalize(NORMAL - sign(area) * (along_x * dFdx(bump) + along_y * dFdy(bump)) / max(abs(area), 0.000001));
}
