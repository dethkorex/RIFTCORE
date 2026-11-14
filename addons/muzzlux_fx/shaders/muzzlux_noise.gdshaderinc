// MUZZLUX shared noise. Written from scratch, no texture is ever sampled: hashes, value
// noise, fBm, ridged fBm and voronoi, in 2D and 3D, plus the small helpers every effect in
// the pack needs. Every function is deterministic and gives the same result on every
// renderer, so Forward+, Mobile, Compatibility and Web draw the same flash.
//
// The hashes avoid sin(), whose precision differs between GPUs.

const float MX_TAU = 6.2831853;

float mx_hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

float mx_hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.x, p.y, p.x) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float mx_hash13(vec3 p) {
	vec3 p3 = fract(p * 0.1031);
	p3 += dot(p3, p3.zyx + 31.32);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 mx_hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.x, p.y, p.x) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

vec3 mx_hash33(vec3 p) {
	vec3 p3 = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yxz + 33.33);
	return fract((p3.xxy + p3.yxx) * p3.zyx);
}

// ---------------------------------------------------------------- value noise

float mx_vnoise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mx_hash12(i);
	float b = mx_hash12(i + vec2(1.0, 0.0));
	float c = mx_hash12(i + vec2(0.0, 1.0));
	float d = mx_hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float mx_vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mx_hash13(i), mx_hash13(i + vec3(1.0, 0.0, 0.0)), f.x);
	float b = mix(mx_hash13(i + vec3(0.0, 1.0, 0.0)), mx_hash13(i + vec3(1.0, 1.0, 0.0)), f.x);
	float c = mix(mx_hash13(i + vec3(0.0, 0.0, 1.0)), mx_hash13(i + vec3(1.0, 0.0, 1.0)), f.x);
	float d = mix(mx_hash13(i + vec3(0.0, 1.0, 1.0)), mx_hash13(i + vec3(1.0, 1.0, 1.0)), f.x);
	return mix(mix(a, b, f.y), mix(c, d, f.y), f.z);
}

// ---------------------------------------------------------------- fBm

float mx_fbm(vec3 p, int octaves) {
	float sum = 0.0;
	float amp = 0.5;
	float norm = 0.0;
	for (int o = 0; o < 6; o++) {
		if (o >= octaves) {
			break;
		}
		sum += mx_vnoise(p) * amp;
		norm += amp;
		p *= 2.02;
		amp *= 0.5;
	}
	return sum / max(norm, 0.0001);
}

float mx_fbm2(vec2 p, int octaves) {
	float sum = 0.0;
	float amp = 0.5;
	float norm = 0.0;
	for (int o = 0; o < 6; o++) {
		if (o >= octaves) {
			break;
		}
		sum += mx_vnoise2(p) * amp;
		norm += amp;
		p *= 2.02;
		amp *= 0.5;
	}
	return sum / max(norm, 0.0001);
}

// Sharp ridges: cordite smoke and the spall ring of a concrete hit need them.
float mx_ridged(vec3 p, int octaves) {
	float sum = 0.0;
	float amp = 0.5;
	float norm = 0.0;
	for (int o = 0; o < 6; o++) {
		if (o >= octaves) {
			break;
		}
		float n = 1.0 - abs(mx_vnoise(p) * 2.0 - 1.0);
		sum += n * n * amp;
		norm += amp;
		p *= 2.13;
		amp *= 0.5;
	}
	return sum / max(norm, 0.0001);
}

// ---------------------------------------------------------------- voronoi

// Returns (distance to the nearest cell point, distance to the edge between the two
// nearest). The second component drawn dark is a crack network.
vec2 mx_voronoi2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = p - i;
	float f1 = 8.0;
	float f2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = mx_hash22(i + g);
			float d = length(g + o - f);
			if (d < f1) {
				f2 = f1;
				f1 = d;
			} else if (d < f2) {
				f2 = d;
			}
		}
	}
	return vec2(f1, f2 - f1);
}

vec2 mx_voronoi(vec3 p) {
	vec3 i = floor(p);
	vec3 f = p - i;
	float f1 = 8.0;
	float f2 = 8.0;
	for (int z = -1; z <= 1; z++) {
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec3 g = vec3(float(x), float(y), float(z));
				vec3 o = mx_hash33(i + g);
				float d = length(g + o - f);
				if (d < f1) {
					f2 = f1;
					f1 = d;
				} else if (d < f2) {
					f2 = d;
				}
			}
		}
	}
	return vec2(f1, f2 - f1);
}

// ---------------------------------------------------------------- helpers

// Builds a basis whose +y is `n`. Stands a splinter or a dust column on a surface.
mat3 mx_basis_from_normal(vec3 n) {
	vec3 up = abs(n.y) < 0.95 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
	vec3 t = normalize(cross(up, n));
	vec3 b = cross(n, t);
	return mat3(t, n, b);
}

// Smooth overshoot: 0 at t = 0, rises past 1 and settles back to 1.
float mx_overshoot(float t, float amount) {
	t = clamp(t, 0.0, 1.0);
	float s = 1.0 - pow(1.0 - t, 3.0);
	return s + amount * sin(t * 3.14159) * (1.0 - t);
}

// Rotation around `axis` (must be normalised) by `ang` radians. Tumbling casings use it.
mat3 mx_rot_axis(vec3 axis, float ang) {
	float c = cos(ang);
	float s = sin(ang);
	float k = 1.0 - c;
	vec3 a = axis;
	return mat3(
		vec3(c + a.x * a.x * k, a.x * a.y * k + a.z * s, a.x * a.z * k - a.y * s),
		vec3(a.x * a.y * k - a.z * s, c + a.y * a.y * k, a.y * a.z * k + a.x * s),
		vec3(a.x * a.z * k + a.y * s, a.y * a.z * k - a.x * s, c + a.z * a.z * k));
}

// A unit vector that is the same for every element with the same index.
vec3 mx_unit_from_index(float idx, float salt) {
	vec3 h = mx_hash33(vec3(idx, salt, idx * 0.37 + salt));
	vec3 v = h * 2.0 - 1.0;
	return length(v) > 0.0001 ? normalize(v) : vec3(0.0, 1.0, 0.0);
}

// ---------------------------------------------------------------- muzzle flash helpers

// 2D rotation matrix. A new roll per shot is what keeps a burst from repeating itself.
mat2 mx_rot2(float ang) {
	float c = cos(ang);
	float s = sin(ang);
	return mat2(vec2(c, s), vec2(-s, c));
}

// A flash rises in about a sixth of its life and falls off sharply: 0 at t = 0, 1 at the
// peak, 0 at t = 1. `peak` is where the top is (0.15 for a pistol, 0.3 for a held MG bloom).
float mx_flash_curve(float t, float peak) {
	t = clamp(t, 0.0, 1.0);
	float rise = smoothstep(0.0, max(peak, 0.001), t);
	float fall = 1.0 - smoothstep(max(peak, 0.001), 1.0, t);
	return rise * fall * fall;
}

// Blackbody-ish ramp from the cool falloff through the mid to the colourless core. `h` is
// how hot this fragment is, 0..1. The core stays white on purpose: burning propellant is a
// few thousand kelvin and all the colour belongs in the falloff.
vec3 mx_heat_ramp(float h, vec3 falloff, vec3 mid, vec3 core) {
	h = clamp(h, 0.0, 1.0);
	vec3 low = mix(falloff, mid, smoothstep(0.0, 0.55, h));
	return mix(low, core, smoothstep(0.62, 1.0, h));
}

// Reduces a colour to `steps` bands, for the 2D nodes' pixel mode and the `retro` palette.
vec3 mx_posterize(vec3 c, float steps) {
	return floor(c * steps + 0.5) / max(steps, 1.0);
}
