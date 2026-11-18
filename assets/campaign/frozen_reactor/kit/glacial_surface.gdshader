shader_type spatial;

uniform sampler2D ice_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float texture_scale = 0.27;
uniform bool hard_ice = true;
varying vec3 position_in_model;
varying vec3 normal_in_model;

void vertex() {
	position_in_model = VERTEX;
	normal_in_model = NORMAL;
}

void fragment() {
	vec3 weights = pow(abs(normalize(normal_in_model)), vec3(5.0));
	weights /= max(.01, weights.x + weights.y + weights.z);
	vec3 color = texture(ice_albedo, position_in_model.zy * texture_scale).rgb * weights.x
		+ texture(ice_albedo, position_in_model.xz * texture_scale).rgb * weights.y
		+ texture(ice_albedo, position_in_model.xy * texture_scale).rgb * weights.z;
	float frost = smoothstep(.24, .64, dot(color, vec3(.25,.5,.25)));
	ALBEDO = hard_ice ? mix(vec3(.035,.095,.12),color * .34,.65) : mix(vec3(.22,.29,.32),color * .38,.20);
	ROUGHNESS = hard_ice ? mix(.46,.64,frost) : .88;
	METALLIC = .0;
	SPECULAR = hard_ice ? .10 : .025;
	vec2 tile = position_in_model.xz * texture_scale;
	float h = texture(ice_albedo, tile).g;
	float hx = texture(ice_albedo, tile + vec2(.0015,0)).g;
	float hy = texture(ice_albedo, tile + vec2(0,.0015)).g;
	NORMAL_MAP = normalize(vec3((h - hx) * 4.0,(h - hy) * 4.0,1.0)) * .5 + .5;
	NORMAL_MAP_DEPTH = .14;
}
