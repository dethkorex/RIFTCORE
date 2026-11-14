// Heat ripple of a shockwave: a camera-facing ring that bends what is behind it. Reads the
// screen texture, so it draws nothing on the Compatibility renderer (the ring and the disc
// carry the wave there).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

#include "res://addons/blastlux_fx/shaders/blastlux_noise.gdshaderinc"

uniform int seed = 1;
uniform float age = -1.0;
uniform vec3 em_origin;
uniform vec3 em_x = vec3(1.0, 0.0, 0.0);
uniform vec3 em_y = vec3(0.0, 1.0, 0.0);
uniform vec3 em_z = vec3(0.0, 0.0, 1.0);

uniform float radius = 4.0;
uniform float wave_speed = 16.0;
uniform float duration = 0.5;
uniform float thickness = 0.7;
uniform float strength = 1.0;
// Seconds after `age` 0 the wave starts (a charged blast).
uniform float delay = 0.0;

#if CURRENT_RENDERER != RENDERER_COMPATIBILITY
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
#endif

varying vec2 v_q;
varying float v_r;
varying float v_t;

void vertex() {
	float s = (length(em_x) + length(em_y) + length(em_z)) / 3.0;
	float t = age - delay;
	v_t = t / max(duration, 0.001);
	float r = min(wave_speed * s * max(t, 0.0), radius * s);
	v_r = r;
	float R = r + thickness * s * 2.0 + 0.001;
	vec2 c = UV * 2.0 - 1.0;
	vec3 p = em_origin + (INV_VIEW_MATRIX[0].xyz * c.x + INV_VIEW_MATRIX[1].xyz * c.y) * R;
	v_q = c * R;
	bool on = age >= 0.0 && t >= 0.0 && v_t < 1.0;
	VERTEX = on ? p : em_origin;
	NORMAL = normalize(INV_VIEW_MATRIX[3].xyz - p);
}

void fragment() {
	float s = (length(em_x) + length(em_y) + length(em_z)) / 3.0;
	float d = length(v_q);
	float x = (d - v_r) / max(thickness * s, 0.001);
	float band = exp(-x * x * 2.5);
	float fade = 1.0 - smoothstep(0.0, 1.0, v_t);
	float n = bx_vnoise(vec3(v_q * 3.0 / max(s, 0.001), float(seed % 41)));
#if CURRENT_RENDERER != RENDERER_COMPATIBILITY
	vec2 dir = d > 0.0001 ? v_q / d : vec2(0.0, 1.0);
	float bend = band * fade * strength * 0.035 * (0.8 + 0.4 * n);
	// Push the sample toward the ring's front: the air ahead of the wave looks compressed.
	vec2 uv = SCREEN_UV - dir * bend * vec2(1.0, -1.0) * sign(x + 0.001);
	vec3 col = textureLod(screen_tex, uv, 0.0).rgb;
	ALBEDO = col;
	ALPHA = clamp(band * fade * strength * 1.5, 0.0, 1.0);
#else
	ALBEDO = vec3(0.0);
	ALPHA = 0.0;
#endif
}
