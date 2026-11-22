shader_type spatial;
render_mode unshaded, shadows_disabled;

uniform float visible_depth = 14.0;
uniform bool surface_open = true;
uniform bool flat_surface = false;
uniform bool pouring_stream = false;
uniform vec2 pool_half_size = vec2(0.0);
uniform float pool_feather = 0.0;
uniform float pool_height = 0.0;

varying vec3 local_pos;
varying vec3 local_normal;

float hash(vec2 cell) {
	return fract(sin(dot(cell, vec2(31.6, 90.4))) * 41287.91);
}

void vertex() {
	local_pos = VERTEX;
	local_normal = NORMAL;
	if (pouring_stream) {
		float ripple = sin(VERTEX.y * 9.2 + TIME * 5.0) * 0.06;
		VERTEX.xz = VERTEX.xz * (1.0 + ripple) + vec2(sin(VERTEX.y * 4.2 + TIME * 3.2) * 0.023, 0.0);
	} else if (surface_open && NORMAL.y > 0.5) {
		float wave = sin(VERTEX.x * 1.2 + VERTEX.z * 1.8 + TIME * 3.4);
		wave += sin(VERTEX.x * 2.9 - VERTEX.z * 3.4 + TIME * 4.3) * 0.46;
		if (pool_feather > 0.0) {
			vec2 inset = pool_half_size - abs(VERTEX.xz);
			float ripple_x = 0.18 + 0.12 * sin(VERTEX.z * 2.9 + TIME * 3.0) + 0.045 * sin(VERTEX.z * 6.1 - TIME * 2.1);
			float ripple_z = 0.24 + 0.16 * sin(VERTEX.x * 2.1 - TIME * 2.6);
			float edge = smoothstep(0.0, pool_feather, min(inset.x - ripple_x, inset.y - ripple_z));
			VERTEX.y += wave * 0.055 * edge - (pool_height + 0.025) * (1.0 - edge);
		} else {
			VERTEX.y += wave * 0.055;
		}
	}
}

void fragment() {
	bool top = local_normal.y > 0.5;
	if ((!flat_surface && !pouring_stream && local_pos.y < 7.0 - visible_depth) || (top && !surface_open) || (!top && (flat_surface || pool_feather > 0.0))) {
		discard;
	}
	vec2 field = (top ? local_pos.xz : local_pos.xy) * vec2(1.85, 2.75);
	if (pouring_stream) {
		field = local_pos.xy * vec2(15.0, 2.4) + vec2(local_pos.z * 5.0, TIME * 3.0);
	}
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
	float crust = smoothstep(0.03, 0.25, next - first);
	float shimmer = 0.5 + 0.5 * sin(field.x * 4.6 - field.y * 1.7 + TIME * 5.0);
	vec3 hot = mix(vec3(0.98, 0.21, 0.014), vec3(1.0, 0.63, 0.10), shimmer);
	vec3 coal = vec3(0.28, 0.024, 0.008) * (0.78 + shimmer * 0.48);
	vec3 glow = mix(hot, coal, crust * 0.78);
	if (!top && !pouring_stream) {
		float depth = 7.0 - local_pos.y;
		float crest = surface_open ? exp(-depth * 2.4) : 0.0;
		float body = 0.55 * exp(-depth * 0.34) + 0.09;
		glow *= body + 0.45 * crest;
		glow += vec3(0.69, 0.20, 0.018) * crest * (0.45 + shimmer * 0.38);
	}
	ALBEDO = glow;
	EMISSION = glow * 0.94;
}
