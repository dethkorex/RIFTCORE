shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform bool overhead = false;
varying vec3 station_pos;

void vertex() {
	station_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Window light falls off across the deck. Neighboring bays bounce
	// cyan and violet into the clear coat on either side of the centerline.
	float bay = floor(station_pos.x / 4.5 + 0.5);
	float across = station_pos.x - bay * 4.5;
	float band = exp(-across * across * 1.35);
	vec3 bounce = mix(vec3(0.012, 0.043, 0.059), vec3(0.036, 0.012, 0.057), mod(bay, 2.0));
	float z = station_pos.z;
	float falloff = overhead ? (0.27 + 0.52 * exp(-0.29 * (z - 1.0) * (z - 1.0)))
			: (0.29 + 0.71 * exp(-0.24 * (z - 2.6) * (z - 2.6)));
	float brush = sin(z * 21.3 + sin(station_pos.x * 3.4)) * sin(z * 12.6);
	vec3 enamel = overhead ? vec3(0.034, 0.043, 0.084) : vec3(0.046, 0.060, 0.115);
	ALBEDO = enamel * (0.83 + 0.17 * falloff + 0.016 * brush) + bounce * band * falloff;
	METALLIC = 0.23;
	ROUGHNESS = 0.46 + 0.024 * brush;
}
