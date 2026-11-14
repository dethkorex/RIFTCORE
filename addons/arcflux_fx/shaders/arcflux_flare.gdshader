// ARCFLUX flare: camera-facing radial glow with optional star rays.
// Use with a 1x1 QuadMesh. Drawn without depth test so it never shows a hard cut where it
// meets geometry; the owning script hides it with a line-of-sight test instead (visibility).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, depth_test_disabled, cull_disabled, skip_vertex_transform, shadows_disabled, fog_disabled;

uniform vec4 core_color : source_color = vec4(0.86, 0.93, 1.0, 1.0);
uniform vec4 glow_color : source_color = vec4(0.24, 0.52, 1.0, 1.0);
uniform float core_energy = 5.0;
uniform float glow_energy = 2.2;
uniform float size = 1.0;
uniform float intensity = 1.0;
// 0..1 line-of-sight factor written by script.
uniform float visibility = 1.0;
uniform float core_size : hint_range(0.01, 1.0) = 0.1;
uniform float glow_falloff = 5.0;
uniform float rays = 6.0;
uniform float ray_strength : hint_range(0.0, 4.0) = 0.6;
uniform float ray_sharpness = 24.0;
uniform float rotation = 0.0;
// Fraction of the flare radius the quad is moved toward the camera.
uniform float camera_push : hint_range(0.0, 1.0) = 0.9;

void vertex() {
	vec3 c = (MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	bool ortho = PROJECTION_MATRIX[3][3] > 0.5;
	float s = length(MODEL_MATRIX[0].xyz) * size;
	if (ortho) {
		c.z += camera_push * s * 0.5;
	} else {
		float dist = length(c);
		float push = min(camera_push * s * 0.5, max(dist - 0.1, 0.0));
		float nd = dist - push;
		c *= nd / max(dist, 1e-4);
		s *= nd / max(dist, 1e-4);
	}
	VERTEX = c + vec3(VERTEX.xy * s, 0.0);
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float edge = 1.0 - smoothstep(0.6, 1.0, r);
	float core = exp(-(r * r) / (core_size * core_size));
	float glow = exp(-r * glow_falloff) * edge;
	float a = atan(q.y, q.x) + rotation;
	float ray = pow(abs(cos(a * rays * 0.5)), ray_sharpness) * (1.0 - r) * (1.0 - r) * edge;
	vec3 col = core_color.rgb * (core_energy * core) + glow_color.rgb * (glow_energy * (glow + ray * ray_strength));
	ALBEDO = col * intensity * visibility;
}
