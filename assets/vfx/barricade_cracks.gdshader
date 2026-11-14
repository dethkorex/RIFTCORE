shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform int fractures = 0;
uniform vec4 accent : source_color = vec4(.22, .8, 1., 1.);

float segment(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b - a;
	return length(p - a - ab * clamp(dot(p - a, ab) / dot(ab, ab), 0., 1.));
}

void fragment() {
	vec2 p = UV;
	float crack = 2.;
	if (fractures > 0) {
		crack = min(segment(p, vec2(.47,.48), vec2(.56,.56)),
			segment(p, vec2(.56,.56), vec2(.59,.63)));
	}
	if (fractures > 1) {
		crack = min(crack, min(segment(p, vec2(.56,.56), vec2(.68,.48)),
			segment(p, vec2(.68,.48), vec2(.82,.52))));
	}
	if (fractures > 2) {
		crack = min(crack, min(segment(p, vec2(.47,.48), vec2(.39,.35)),
			segment(p, vec2(.39,.35), vec2(.19,.30))));
		crack = min(crack, segment(p, vec2(.39,.35), vec2(.48,.19)));
	}
	if (fractures > 3) {
		crack = min(crack, min(segment(p, vec2(.59,.63), vec2(.48,.73)),
			segment(p, vec2(.48,.73), vec2(.65,.97))));
		crack = min(crack, min(segment(p, vec2(.47,.48), vec2(.31,.60)),
			segment(p, vec2(.31,.60), vec2(.04,.72))));
	}
	float width = .013 + float(fractures) * .004;
	ALPHA = 1. - smoothstep(width, width + .009, crack);
	ALBEDO = mix(vec3(.015,.022,.037), accent.rgb, smoothstep(width * .62, width, crack));
}
