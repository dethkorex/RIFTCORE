// ARCFLUX ribbon: camera-facing strips for bolts, arcs and sparks.
// Geometry comes from ArcfluxRibbon; see that script for the vertex layout.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, skip_vertex_transform, shadows_disabled, fog_disabled;

uniform vec4 core_color : source_color = vec4(0.86, 0.93, 1.0, 1.0);
uniform vec4 glow_color : source_color = vec4(0.24, 0.52, 1.0, 1.0);
uniform float core_energy = 5.0;
uniform float glow_energy = 2.2;
// Core width as a fraction of the full ribbon width.
uniform float core_ratio : hint_range(0.02, 1.0) = 0.18;
// Higher values tighten the halo around the core.
uniform float glow_falloff : hint_range(0.5, 8.0) = 2.4;
uniform float width_scale = 1.0;
// Core never gets thinner than this many pixels; energy is conserved when widened.
uniform float min_core_pixels = 1.25;
uniform float intensity = 1.0;
// Multiplies only the white-hot core; lowering it leaves the coloured afterglow.
uniform float core_gain = 1.0;
// Extra multiplier for branch strands (level >= 1).
uniform float branch_intensity = 1.0;
// Leader head position in reveal units. Values above 1 show the whole channel.
uniform float reveal = 2.0;
// Brightness noise travelling along the strand.
uniform float crackle : hint_range(0.0, 1.0) = 0.35;
uniform float crackle_scale = 3.0;
uniform float phase = 0.0;
uniform float seed = 0.0;
// Strands flagged as halo (COLOR.a > 0.5) draw only a wide soft glow.
uniform float halo_gain = 0.22;
uniform float halo_falloff = 2.5;
// Fades both ends of each strand over this fraction of its length.
uniform float end_fade : hint_range(0.0, 0.5) = 0.0;

varying float v_bright;
varying float v_reveal;
varying float v_s;
varying float v_level;
varying float v_energy;
varying float v_halo;

float af_hash(float n) {
	return fract(sin(mod(n, 4096.0) * 78.233 + 11.137) * 24634.6345);
}

float af_noise(float x) {
	float i = floor(x);
	float f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(af_hash(i), af_hash(i + 1.0), f);
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
	v_reveal = COLOR.g;
	v_s = COLOR.b;
	v_level = UV2.y;
	v_halo = COLOR.a;
}

void fragment() {
	float d = abs(UV.y);
	float core = 1.0 - smoothstep(core_ratio * 0.4, core_ratio, d);
	float halo = pow(clamp(1.0 - d, 0.0, 1.0), glow_falloff);
	float branch = v_level > 0.5 ? branch_intensity : 1.0;
	float head = 1.0 - smoothstep(reveal - 0.03, reveal, v_reveal);
	float tip = 1.0 + 3.0 * exp(-max(reveal - v_reveal, 0.0) * 60.0) * step(reveal, 1.0);
	float n = af_noise(UV.x * crackle_scale + seed * 37.0 + phase);
	float crk = mix(1.0, 0.3 + 1.4 * n, crackle);
	float ends = 1.0;
	if (end_fade > 0.0) {
		ends = smoothstep(0.0, end_fade, v_s) * smoothstep(1.0, 1.0 - end_fade, v_s);
	}
	vec3 col = core_color.rgb * (core_energy * core * core_gain) + glow_color.rgb * (glow_energy * halo);
	if (v_halo > 0.5) {
		col = glow_color.rgb * (glow_energy * halo_gain * pow(clamp(1.0 - d, 0.0, 1.0), halo_falloff));
	}
	ALBEDO = col * (v_bright * v_energy * intensity * branch * head * tip * crk * ends);
}
