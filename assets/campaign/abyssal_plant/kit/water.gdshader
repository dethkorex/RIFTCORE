shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;
uniform vec4 tint : source_color = vec4(0.03,0.35,0.46,0.28);
uniform float flow = 1.0;
uniform float strength = 1.0;
void vertex() {
    float wave = sin(VERTEX.x*2.3+TIME*1.4)+sin(VERTEX.z*3.7-TIME*1.9);
    VERTEX += NORMAL * wave * 0.035 * strength;
}
void fragment() {
    vec2 p = UV*vec2(8.0,3.0)+vec2(TIME*flow,0.0);
    float streak = pow(abs(sin(p.x*2.1+sin(p.y*4.0+TIME)*1.7)),16.0);
    float cells = pow(abs(sin(p.x+sin(p.y*2.0))*cos(p.y+sin(p.x*1.7))),8.0);
    ALBEDO = mix(tint.rgb,vec3(0.48,0.91,0.93),streak*.45+cells*.4);
    ROUGHNESS = 0.16;
    METALLIC = 0.35;
    SPECULAR = 0.8;
    EMISSION = ALBEDO * (streak*.65+cells*.45);
    ALPHA = tint.a * strength;
}
