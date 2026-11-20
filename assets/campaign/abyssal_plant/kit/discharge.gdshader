// Noise adapted from Loop_Box / FencerDevLog, CC0; see SOURCES.md.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform vec4 tint : source_color = vec4(0.2,0.75,1.0,1.0);
uniform float intensity = 1.0;
float noise_hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float value_noise(vec2 p) {
    vec2 i=floor(p); vec2 f=fract(p); vec2 u=f*f*(3.0-2.0*f);
    return mix(mix(noise_hash(i),noise_hash(i+vec2(1,0)),u.x),mix(noise_hash(i+vec2(0,1)),noise_hash(i+vec2(1,1)),u.x),u.y);
}
void fragment() {
    float pulse=.65+.35*value_noise(UV*vec2(5,24)+TIME*17.0);
    ALBEDO=tint.rgb*pulse*intensity;
    EMISSION=tint.rgb*2.2*pulse*intensity;
    ALPHA=tint.a*intensity;
}
