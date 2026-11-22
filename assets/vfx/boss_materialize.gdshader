shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.35, 0.85, 1.0, 1.0);
uniform float scan_y;
varying float world_y;

void vertex() {
	world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	float below = scan_y - world_y;
	if (below < 0.0) {
		discard;
	}
	float edge = 1.0 - smoothstep(0.03, 0.27, below);
	float lines = 1.0 - smoothstep(0.04, 0.16, fract(world_y * 14.0 - TIME * 4.0));
	vec3 ink = tint.rgb * (0.23 + lines * 0.55);
	ALBEDO = mix(ink, mix(tint.rgb, vec3(1.0), 0.8), edge);
	EMISSION = tint.rgb * (lines * 0.27 + edge * 0.7);
}
