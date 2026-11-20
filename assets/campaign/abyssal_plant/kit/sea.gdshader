shader_type spatial;
render_mode unshaded, cull_disabled;
void fragment() {
    vec2 p=UV*vec2(5.0,3.0);
    float beam=pow(max(0.0,sin(p.x*3.0+p.y*.6+TIME*.035)),18.0);
    float caustic=pow(abs(sin(p.x*6.0+sin(p.y*7.0+TIME*.35))*cos(p.y*6.0+sin(p.x*6.0-TIME*.3))),14.0);
    ALBEDO=mix(vec3(.002,.012,.027),vec3(.015,.11,.14),UV.y)+vec3(.015,.055,.06)*beam+vec3(.01,.09,.1)*caustic;
}
