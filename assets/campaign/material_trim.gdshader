shader_type spatial;
render_mode diffuse_burley;

uniform sampler2D trim_sheet : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec2 strip = vec2(0.005, 0.112);
uniform vec2 span = vec2(6.0, 0.46);
uniform float center_y = -0.49;
uniform float metallic = 0.62;
uniform vec3 tint : source_color = vec3(1.0);
uniform float relief_strength = 0.31;
varying vec3 local_position;
varying vec3 local_normal;

void vertex() {
	local_position = VERTEX;
	local_normal = NORMAL;
}

float height_at(vec2 p) {
	return texture(trim_sheet, vec2(p.x + 0.5, p.y)).r;
}

void fragment() {
	float width_coordinate = mix(local_position.x, local_position.z, step(abs(local_normal.z), abs(local_normal.x)));
	float u = fract(width_coordinate / span.x + 0.5);
	float v = clamp(0.5 - (local_position.y - center_y) / span.y, 0.0, 1.0);
	vec2 uv = vec2(mix(0.003, 0.497, u), mix(strip.x, strip.y, v));
	vec2 texel = vec2(1.0) / vec2(textureSize(trim_sheet, 0));
	float h = height_at(uv);
	vec3 n = normalize(NORMAL);
	vec3 dx = dFdx(VERTEX);
	vec3 dy = dFdy(VERTEX);
	vec3 along = cross(dy, n);
	vec3 across = cross(n, dx);
	float det = dot(dx, along);
	vec3 gradient = dFdx(h) * along + dFdy(h) * across;
	NORMAL = normalize(max(abs(det), 0.000001) * n - sign(det) * gradient * relief_strength * texel.x * 15.0);
	ALBEDO = texture(trim_sheet, uv).rgb * tint;
	METALLIC = metallic;
	ROUGHNESS = mix(0.66, 0.43, clamp(h, 0.0, 1.0));
}
