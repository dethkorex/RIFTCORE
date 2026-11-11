shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;
uniform sampler2D skyline : source_color, filter_linear_mipmap, repeat_disable;
varying vec3 world_at;
void vertex() {
	world_at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	// Repeat with an overlap so the outer edges cannot form a hard seam.
	float raw = (world_at.x - CAMERA_POSITION_WORLD.x * 0.68) / 132.0 + 0.36;
	float u = fract(raw);
	float vertical = 0.48 - (world_at.y - CAMERA_POSITION_WORLD.y * 0.65) / 67.0;
	float y = clamp(vertical, 0.002, 0.998);
	vec3 color = texture(skyline, vec2(u * 0.94, y)).rgb;
	if (u < 0.06383) {
		float blend = smoothstep(0.0, 0.06383, u);
		color = texture(skyline, vec2(u * 0.94, y)).rgb;
		// At the wrap itself sample the identical edge seen at the end of the prior tile.
		color = mix(texture(skyline, vec2(0.94 + u * 0.94, y)).rgb, color, blend);
	}
	float fade = smoothstep(-0.06, 0.14, vertical) * (1.0 - smoothstep(0.87, 1.08, vertical));
	ALBEDO = mix(vec3(0.016, 0.036, 0.093), color * vec3(0.66, 0.74, 0.84), fade);
}
