shader_type spatial;
uniform float damage : hint_range(0.0, 1.0) = 0.0;
varying vec3 stone_at;

vec3 jitter(vec3 cell) {
	return fract(sin(vec3(dot(cell, vec3(127.1, 311.7, 77.9)),
		dot(cell, vec3(269.5, 183.3, 211.1)),
		dot(cell, vec3(113.5, 271.9, 124.6)))) * 43758.5453);
}

void vertex() {
	stone_at = VERTEX;
}

void fragment() {
	vec3 point = stone_at * 4.3;
	vec3 base_cell = floor(point);
	vec3 local = fract(point);
	float near_cell = 8.0;
	float next_cell = 8.0;
	float grain = 0.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			for (int z = -1; z <= 1; z++) {
				vec3 offset = vec3(float(x), float(y), float(z));
				vec3 random = jitter(base_cell + offset);
				vec3 delta = offset + 0.17 + random * 0.66 - local;
				float d = dot(delta, delta);
				if (d < near_cell) {
					next_cell = near_cell;
					near_cell = d;
					grain = random.x;
				} else {
					next_cell = min(next_cell, d);
				}
			}
		}
	}
	float seam = next_cell - near_cell;
	float extent = step(grain * 0.82 + 0.10, damage);
	float crack = (1.0 - smoothstep(damage * 0.055, 0.024 + damage * 0.086, seam)) * extent;
	float heat = (1.0 - smoothstep(0.007, 0.016 + damage * 0.040, seam)) * extent;
	float ash = fract(sin(dot(floor(stone_at * 92.0), vec3(127.1, 311.7, 59.3))) * 43758.5453);
	float strata = sin(stone_at.y * 39.0 + sin(stone_at.x * 16.0) * 1.6) * 0.5 + 0.5;
	vec3 rock = mix(vec3(0.033, 0.020, 0.014), vec3(0.225, 0.121, 0.075), grain * 0.61 + ash * 0.16 + strata * 0.13);
	ALBEDO = mix(rock, vec3(0.25, 0.068, 0.020), crack);
	EMISSION = vec3(1.5, 0.19, 0.022) * heat * (0.30 + damage * 1.70);
	ROUGHNESS = 0.87;
}
