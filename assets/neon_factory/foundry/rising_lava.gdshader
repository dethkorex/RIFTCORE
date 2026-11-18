shader_type spatial;
render_mode unshaded, shadows_disabled;

uniform float visible_depth = 14.0;
uniform bool surface_open = true;

varying vec3 local_pos;
varying vec3 local_normal;

float hash(vec2 cell) {
	return fract(sin(dot(cell, vec2(31.6, 90.4))) * 41287.91);
}

void vertex() {
	local_pos = VERTEX;
	local_normal = NORMAL;
	if (surface_open && VERTEX.y > 6.99) {
		float wave = sin(VERTEX.x * 1.2 + VERTEX.z * 1.8 + TIME * 3.4);
		wave += sin(VERTEX.x * 2.9 - VERTEX.z * 3.4 + TIME * 4.3) * 0.46;
		VERTEX.y += wave * 0.055;
	}
}

void fragment() {
	bool top = local_normal.y > 0.5;
	if (local_pos.y < 7.0 - visible_depth || (top && !surface_open)) {
		discard;
	}
	vec2 field = (top ? local_pos.xz : local_pos.xy) * vec2(1.85, 2.75);
	field += vec2(TIME * 0.48, sin(field.x * 0.62 + TIME * 1.9) * 0.27 + TIME * 0.36);
	field += vec2(
		sin(field.y * 1.3 + TIME * 2.7) * 0.28,
		sin(field.x * 0.97 - TIME * 2.1) * 0.33);
	vec2 base = floor(field);
	vec2 part = fract(field);
	float first = 8.0;
	float next = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 cell = vec2(float(x), float(y));
			vec2 offset = vec2(hash(base + cell), hash(base + cell + vec2(23.5, 5.8)));
			float d = length(cell + offset - part);
			next = min(next, max(first, d));
			first = min(first, d);
		}
	}
	float crust = smoothstep(0.03, 0.22, next - first);
	float shimmer = 0.5 + 0.5 * sin(field.x * 4.6 - field.y * 1.7 + TIME * 5.0);
	float rim = surface_open ? smoothstep(6.78, 6.98, local_pos.y) : 0.0;
	vec3 hot = mix(vec3(1.0, 0.17, 0.009), vec3(1.0, 0.67, 0.10), shimmer);
	vec3 coal = vec3(0.31, 0.030, 0.007) * (0.75 + shimmer * 0.5);
	vec3 glow = mix(hot, coal, crust * 0.89);
	if (!top) {
		glow *= 0.32 + 0.68 * rim;
		glow += vec3(1.0, 0.29, 0.02) * rim * 0.78;
	}
	ALBEDO = glow;
	EMISSION = glow * 0.94;
}
