// ARCFLUX beam: camera-facing strip with flowing noise, travelling bands and erosion.
// Shares the vertex layout of the ribbon shader (see ArcfluxRibbon).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, skip_vertex_transform, shadows_disabled, fog_disabled;

uniform vec4 core_color : source_color = vec4(0.86, 0.93, 1.0, 1.0);
uniform vec4 glow_color : source_color = vec4(0.24, 0.52, 1.0, 1.0);
uniform float core_energy = 5.0;
uniform float glow_energy = 2.2;
uniform float core_ratio : hint_range(0.02, 1.0) = 0.25;
uniform float glow_falloff : hint_range(0.5, 8.0) = 2.0;
uniform float width_scale = 1.0;
uniform float min_core_pixels = 1.25;
uniform float intensity = 1.0;
uniform float core_gain = 1.0;
// Scales the coloured glow inside the body strip; lower keeps thick beams saturated.
uniform float body_glow_gain = 1.0;
// Noise flowing along the beam. flow is advanced by script (local units).
uniform float noise_scale = 1.4;
uniform float flow = 0.0;
uniform float edge_noise : hint_range(0.0, 1.0) = 0.35;
uniform float body_noise : hint_range(0.0, 1.0) = 0.4;
// Bright bands travelling along the beam.
uniform float band_strength = 0.0;
uniform float band_spacing = 1.5;
uniform float band_phase = 0.0;
uniform float band_sharpness = 6.0;
// Fade lengths at both ends, in local units. beam_length is set by script.
uniform float beam_length = 10.0;
uniform float start_fade = 0.1;
uniform float end_fade = 0.1;
// 0 = solid, 1 = fully dissolved.
uniform float erosion : hint_range(0.0, 1.0) = 0.0;
uniform float seed = 0.0;
// Strips flagged as halo (COLOR.a > 0.5) draw only a wide soft glow.
uniform float halo_gain = 0.25;
uniform float halo_falloff = 2.5;

varying float v_bright;
varying float v_energy;
varying float v_halo;

float af_hash2(vec2 p) {
	p = mod(p, 1024.0);
	return fract(sin(dot(p, vec2(41.37, 289.13)) + 7.31) * 31718.927);
}

float af_noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = af_hash2(i);
	float b = af_hash2(i + vec2(1.0, 0.0));
	float c = af_hash2(i + vec2(0.0, 1.0));
	float d = af_hash2(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float af_fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.55;
	for (int i = 0; i < 3; i++) {
		v += af_noise2(p) * amp;
		p = p * 2.03 + vec2(13.1, 7.7);
		amp *= 0.5;
	}
	return v / 0.9625;
}

void vertex() {
	vec3 p = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 t = (MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	bool ortho = PROJECTION_MATRIX[3][3] > 0.5;
	vec3 view_dir = ortho ? vec3(0.0, 0.0, -1.0) : normalize(p);
	vec3 side = cross(t, view_dir);
	float sl = length(side);
	side = sl > 1e-5 ? side / sl : vec3(1.0, 0.0, 0.0);
	float scale = length(MODEL_MATRIX[0].xyz);
	float w = UV2.x * scale * width_scale;
	float px = 2.0 / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y) * (ortho ? 1.0 : max(-p.z, 0.001));
	float w_min = min_core_pixels * px / max(core_ratio, 0.02);
	float w2 = max(w, w_min);
	v_energy = w / w2;
	VERTEX = p + side * (w2 * 0.5 * UV.y);
	NORMAL = vec3(0.0, 0.0, 1.0);
	v_bright = COLOR.r;
	v_halo = COLOR.a;
}

void fragment() {
	float x = UV.x;
	float d = abs(UV.y);
	float n = af_fbm(vec2(x * noise_scale - flow, UV.y * 1.3 + seed));
	float d_eff = d / max(1.0 - edge_noise * (n - 0.2), 0.05);
	float core = 1.0 - smoothstep(core_ratio * 0.45, core_ratio, d_eff);
	float halo = pow(clamp(1.0 - d_eff, 0.0, 1.0), glow_falloff);
	float body = mix(1.0, 0.45 + 1.1 * n, body_noise);
	float bands = 1.0;
	if (band_strength > 0.0) {
		float b = 0.5 + 0.5 * cos((x / max(band_spacing, 0.01) - band_phase) * TAU);
		bands = 1.0 + band_strength * pow(b, band_sharpness);
	}
	float ends = smoothstep(0.0, max(start_fade, 1e-4), x) * smoothstep(beam_length, beam_length - max(end_fade, 1e-4), x);
	float erode = 1.0;
	if (erosion > 0.0) {
		float e = af_fbm(vec2(x * noise_scale * 2.3 + seed * 3.0, UV.y * 2.0 - flow * 0.3));
		erode = smoothstep(erosion, erosion + 0.2, e);
	}
	vec3 col = core_color.rgb * (core_energy * core * core_gain) + glow_color.rgb * (glow_energy * halo * body_glow_gain);
	if (v_halo > 0.5) {
		col = glow_color.rgb * (glow_energy * halo_gain * pow(clamp(1.0 - d, 0.0, 1.0), halo_falloff));
		body = mix(1.0, body, 0.4);
	}
	ALBEDO = col * (v_bright * v_energy * intensity * body * bands * ends * erode);
}
