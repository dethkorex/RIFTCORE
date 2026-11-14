// EDGEFLUX shared helpers: hashing, value noise and the analytic particle motion.
// Everything here is plain float math so it compiles the same on every renderer.

float ef_hash(float n) {
	return fract(sin(mod(n, 6283.0) * 12.9898 + 4.1414) * 43758.5453);
}

float ef_hash2(vec2 p) {
	return ef_hash(dot(mod(p, 1024.0), vec2(1.0, 57.0)));
}

float ef_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = ef_hash2(i);
	float b = ef_hash2(i + vec2(1.0, 0.0));
	float c = ef_hash2(i + vec2(0.0, 1.0));
	float d = ef_hash2(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float ef_fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += ef_noise(p) * a;
		p = p * 2.03 + vec2(17.1, 9.3);
		a *= 0.5;
	}
	return v;
}

// Position after t seconds for a particle with linear drag k and constant acceleration g.
vec3 ef_motion(vec3 p0, vec3 v0, vec3 g, float k, float t) {
	float kk = max(k, 0.0001);
	float e = (1.0 - exp(-kk * t)) / kk;
	return p0 + g / kk * t + (v0 - g / kk) * e;
}

// Direction inside a cone of half-angle `spread` around `axis` from two random numbers.
vec3 ef_cone(vec3 axis, float spread, float r1, float r2) {
	vec3 a = normalize(axis);
	vec3 helper = abs(a.y) < 0.95 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
	vec3 u = normalize(cross(a, helper));
	vec3 v = cross(a, u);
	float ct = mix(1.0, cos(min(spread, 3.14159)), r1);
	float st = sqrt(max(0.0, 1.0 - ct * ct));
	float ph = r2 * 6.28318;
	return a * ct + (u * cos(ph) + v * sin(ph)) * st;
}
