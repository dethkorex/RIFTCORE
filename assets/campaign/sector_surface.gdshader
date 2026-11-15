shader_type spatial;
render_mode cull_disabled, diffuse_burley;

uniform sampler2D terrain_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float texture_scale = 0.20;
uniform float roughness = 0.84;
uniform float relief = 1.0;
uniform float metal = 0.0;
uniform float grain_mix = 1.0;
uniform float brightness = 1.0;
uniform vec3 chassis_color : source_color = vec3(0.12);
uniform float reflected_light = 0.14;
uniform vec3 surface_tint : source_color = vec3(1.0);

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

vec3 sample_surface(vec2 coordinate) {
	// Mirroring keeps material swatches continuous at the repeat boundary.
	vec2 warp = 0.155 * vec2(sin(coordinate.y * 1.77 + coordinate.x * 0.72),
		cos(coordinate.x * 1.41 - coordinate.y * 0.53));
	vec2 uv = 1.0 - abs(fract((coordinate + warp) * 0.5) * 2.0 - 1.0);
	return texture(terrain_albedo, uv).rgb;
}

void fragment() {
	vec3 weights = pow(abs(normalize(world_normal)), vec3(7.0));
	weights /= max(dot(weights, vec3(1.0)), 0.001);
	vec3 p = world_position * texture_scale;
	vec3 pigment = weights.x * sample_surface(p.zy) +
		weights.y * sample_surface(p.xz) + weights.z * sample_surface(p.xy);
	float rock_layer = sin(world_position.y * 1.7 + sin(world_position.x * 0.52) * 1.0);
	vec3 color = mix(chassis_color, pigment * surface_tint, grain_mix) * mix(0.91, 1.10, 0.5 + 0.5 * rock_layer * relief);
	color *= brightness;
	ALBEDO = color;
	ROUGHNESS = roughness;
	METALLIC = metal;
	EMISSION = color * reflected_light;
}
