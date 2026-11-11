shader_type spatial;
render_mode unshaded;

uniform vec4 tint : source_color = vec4(0.22, 0.82, 0.4, 1.0);
uniform int mark = 0;

varying vec3 orb_at;

void vertex() {
	orb_at = normalize(VERTEX);
}

void fragment() {
	vec3 normal = normalize(NORMAL);
	float facing = clamp(dot(normal, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - facing, 2.1);
	float left_light = max(dot(normal, normalize(vec3(-0.45, 0.64, 0.62))), 0.0);
	float back_light = max(dot(normal, normalize(vec3(0.62, -0.64, 0.45))), 0.0);
	vec3 p = normalize(orb_at);
	float energy = 0.0;
	if (mark == 0) {
		// Slow, overlapping waves in the health orb.
		energy = pow(0.5 + 0.5 * sin(11.0 * p.y + 2.9 * p.x - TIME * 2.4), 7.0);
	} else if (mark == 1) {
		// Angular branching around the energy core.
		float arc = sin(19.0 * p.y + sin(p.x * 14.0 + TIME * 3.1) * 2.0 + p.z * 5.0);
		energy = pow(0.5 + 0.5 * arc, 13.0);
	} else if (mark == 2) {
		// Small diamond facets leave the center legible for the XP badge.
		vec2 cell = abs(fract(vec2(p.x + p.y, p.x - p.y) * 5.2 + vec2(0.0, TIME * 0.20)) - 0.5);
		energy = 1.0 - smoothstep(0.035, 0.14, min(cell.x, cell.y));
	} else {
		// A molten gold ribbon winds through the currency orb.
		float angle = atan(p.x, p.z);
		energy = pow(0.5 + 0.5 * sin(angle * 3.0 + p.y * 8.3 - TIME * 2.0), 6.0);
	}
	vec3 core = tint.rgb * (0.31 + 0.60 * left_light + 0.35 * facing);
	core += tint.rgb * energy * (0.15 + rim * 0.23);
	if (mark == 2) {
		core = mix(core, mix(tint.rgb, vec3(0.93, 0.78, 1.0), 0.57), pow(facing, 5.0) * 0.57);
	}
	float glint = pow(left_light, 42.0) * 0.89 + pow(back_light, 18.0) * 0.20;
	vec3 edge = mix(tint.rgb, vec3(0.87, 0.95, 1.0), 0.60);
	ALBEDO = core + edge * (rim * 0.70 + glint);
}
