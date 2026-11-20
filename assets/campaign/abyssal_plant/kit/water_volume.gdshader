shader_type spatial;
render_mode unshaded, blend_mix, cull_back, depth_draw_never;
varying vec3 world_point;
void vertex() { world_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
    vec2 p=world_point.xy*vec2(.65,1.2);
    float caustic=pow(abs(sin(p.x+sin(p.y+TIME*.42))*cos(p.y+sin(p.x-TIME*.31))),10.0);
    float shaft=pow(max(0.0,sin(p.x*.44+p.y*.1+TIME*.03)),16.0);
    ALBEDO=vec3(.015,.22,.30)+vec3(.05,.30,.32)*caustic+vec3(.015,.10,.13)*shaft;
    ALPHA=.13+caustic*.09+shaft*.025;
}
