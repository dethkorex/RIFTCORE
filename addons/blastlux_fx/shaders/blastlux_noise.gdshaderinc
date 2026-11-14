// BLASTLUX shared shader helpers: hashes, value noise, fBm, curl, colour ramps, ballistics and
// the colour-space helpers every layer uses. Deterministic on Forward+, Mobile, Compatibility
// and Web. Every argument and local is prefixed with _ so no shader that includes this file can
// shadow one of its own uniforms (shader_audit.py).

const float BX_TAU = 6.2831853;

// ---------------------------------------------------------------- hashes

float bx_hash11(float _p) {
	_p = fract(_p * 0.1031);
	_p *= _p + 33.33;
	_p *= _p + _p;
	return fract(_p);
}

float bx_hash13(vec3 _p) {
	vec3 _p3 = fract(_p * 0.1031);
	_p3 += dot(_p3, _p3.zyx + 31.32);
	return fract((_p3.x + _p3.y) * _p3.z);
}

// Four independent numbers in [0, 1) for element `_i`, seed `_s`, salt `_k`.
vec4 bx_rand4(uint _i, uint _s, uint _k) {
	uint _n = _i * 747796405u + _s * 2891336453u + _k * 277803737u;
	_n ^= _n >> 13u;
	_n *= 1664525u;
	_n ^= _n >> 16u;
	uint _a = _n;
	uint _b = _a * 1103515245u + 12345u;
	uint _c = _b * 1103515245u + 12345u;
	uint _d = _c * 1103515245u + 12345u;
	return vec4(float(_a >> 8u), float(_b >> 8u), float(_c >> 8u), float(_d >> 8u)) / 16777216.0;
}

// A direction on the unit sphere from an element index and a salt.
vec3 bx_unit_from_index(float _idx, float _salt) {
	float _u = bx_hash11(_idx * 3.17 + _salt) * 2.0 - 1.0;
	float _a = bx_hash11(_idx * 7.31 + _salt + 1.0) * BX_TAU;
	float _s = sqrt(max(1.0 - _u * _u, 0.0));
	return vec3(_s * cos(_a), _u, _s * sin(_a));
}

// ---------------------------------------------------------------- noise

float bx_vnoise(vec3 _p) {
	vec3 _i = floor(_p);
	vec3 _f = fract(_p);
	_f = _f * _f * (3.0 - 2.0 * _f);
	float _a = mix(bx_hash13(_i), bx_hash13(_i + vec3(1.0, 0.0, 0.0)), _f.x);
	float _b = mix(bx_hash13(_i + vec3(0.0, 1.0, 0.0)), bx_hash13(_i + vec3(1.0, 1.0, 0.0)), _f.x);
	float _c = mix(bx_hash13(_i + vec3(0.0, 0.0, 1.0)), bx_hash13(_i + vec3(1.0, 0.0, 1.0)), _f.x);
	float _d = mix(bx_hash13(_i + vec3(0.0, 1.0, 1.0)), bx_hash13(_i + vec3(1.0, 1.0, 1.0)), _f.x);
	return mix(mix(_a, _b, _f.y), mix(_c, _d, _f.y), _f.z);
}

float bx_fbm(vec3 _p, int _octaves) {
	float _sum = 0.0;
	float _amp = 0.5;
	float _norm = 0.0;
	vec3 _q = _p;
	for (int _o = 0; _o < 5; _o++) {
		if (_o >= _octaves) {
			break;
		}
		_sum += bx_vnoise(_q) * _amp;
		_norm += _amp;
		_q = _q * 2.03 + vec3(7.1, 3.3, 11.7);
		_amp *= 0.5;
	}
	return _sum / max(_norm, 0.0001);
}

// Cheap divergence-free-ish swirl: three offset noises centred on zero.
vec3 bx_curl(vec3 _p) {
	return vec3(bx_vnoise(_p), bx_vnoise(_p + vec3(31.4, 7.7, 2.9)), bx_vnoise(_p + vec3(5.1, 47.3, 13.7))) * 2.0 - 1.0;
}

// ---------------------------------------------------------------- colour

// Heat ramp: 0 = cool (dark red), 0.5 = hot (orange), 1.0 = core (white-yellow).
vec3 bx_ramp(float _h, vec3 _cool, vec3 _hot, vec3 _core) {
	vec3 _c = mix(_cool, _hot, smoothstep(0.0, 0.5, _h));
	return mix(_c, _core, smoothstep(0.5, 1.0, _h));
}

// Palette colours are written as the artist sees them (sRGB) and declared WITHOUT source_color,
// so every renderer hands them over untouched; the layer works in linear and hands the result
// back the way the renderer reads it (Compatibility reads the output as sRGB).
vec3 bx_lin(vec3 _c) {
	return pow(max(_c, vec3(0.0)), vec3(2.2));
}

vec3 bx_out(vec3 _c, bool _srgb) {
	return _srgb ? pow(max(_c, vec3(0.0)), vec3(1.0 / 2.2)) : _c;
}

// Measured 2026-10-31 (_dev/color_probe.tscn, Forward+ against Compatibility on the same GPU):
// Compatibility reads the fragment output as sRGB and blends in that space, then tonemaps and
// encodes like Forward+. One layer over black matches when it hands over pow(c, 1/2.2); a stack
// of covering puffs matches when the cover is encoded first and premultiplied after
// (sum_k E(cover)*a*(1-a)^k -> E(cover)), so the layers write E(light) + E(cover) * a with the
// coverage unchanged. The earlier lifts (a^0.65, x0.45, 1/1.6) are gone.
float bx_alpha_out(float _a, bool _srgb) {
	return clamp(_a, 0.0, 1.0);
}

// Light a layer adds. On Compatibility the encoded light of overlapping layers is summed in
// sRGB space, and the curve lifts a near-zero value a lot (E(0.001) = 0.04): twenty cooled
// puffs with a trace of glow left summed to a grey haze (smoke L* 17 against 8, 2026-10-31).
// A small toe cut off before the encode removes that and leaves real glows untouched.
vec3 bx_add_out(vec3 _c, bool _srgb) {
	return _srgb ? bx_out(max(_c - vec3(0.004), vec3(0.0)), true) : _c;
}

vec3 bx_cover_out(vec3 _c, bool _srgb) {
	return bx_out(_c, _srgb);
}

vec3 bx_fire_out(vec3 _c, bool _srgb) {
	return bx_out(_c, _srgb);
}

// ---------------------------------------------------------------- motion

// Distance travelled along the launch direction under linear drag `_k` after `_t` seconds
// (unit initial speed).
float bx_drag_dist(float _t, float _k) {
	return _k > 0.0001 ? (1.0 - exp(-_k * _t)) / _k : _t;
}

mat3 bx_basis_from_normal(vec3 _n) {
	vec3 _up = abs(_n.y) < 0.95 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
	vec3 _t = normalize(cross(_up, _n));
	vec3 _b = cross(_n, _t);
	return mat3(_t, _b, _n);
}

mat3 bx_rot_axis(vec3 _axis, float _ang) {
	vec3 _a = normalize(_axis);
	float _c = cos(_ang);
	float _s = sin(_ang);
	float _oc = 1.0 - _c;
	return mat3(
		vec3(_oc * _a.x * _a.x + _c, _oc * _a.x * _a.y + _a.z * _s, _oc * _a.z * _a.x - _a.y * _s),
		vec3(_oc * _a.x * _a.y - _a.z * _s, _oc * _a.y * _a.y + _c, _oc * _a.y * _a.z + _a.x * _s),
		vec3(_oc * _a.z * _a.x + _a.y * _s, _oc * _a.y * _a.z - _a.x * _s, _oc * _a.z * _a.z + _c));
}

// Ballistic point with up to three bounces on the plane y = _ground. `_p` and `_v` are updated
// in place; returns the time still to run after the last bounce (so callers can skid).
// `_resting` becomes 1.0 once the piece has stopped bouncing.
vec3 bx_bounce_path(vec3 _p0, vec3 _v0, float _t, float _g, float _ground, float _rest, float _fric, out float _resting) {
	vec3 _p = _p0;
	vec3 _v = _v0;
	float _tr = _t;
	_resting = 0.0;
	for (int _b = 0; _b < 3; _b++) {
		float _disc = _v.y * _v.y + 2.0 * _g * (_p.y - _ground);
		if (_disc <= 0.0) {
			break;
		}
		float _th = (_v.y + sqrt(_disc)) / max(_g, 0.0001);
		if (_th >= _tr) {
			break;
		}
		if (_th <= 0.0005) {
			_resting = 1.0;
			break;
		}
		_p += _v * _th;
		_p.y = _ground;
		_v.y = -(_v.y - _g * _th) * _rest;
		_v.x *= _fric;
		_v.z *= _fric;
		_tr -= _th;
		if (_b == 2 || abs(_v.y) < 0.3) {
			_resting = 1.0;
		}
	}
	if (_resting > 0.5) {
		float _skid = (1.0 - exp(-_tr * 4.0)) / 4.0;
		_p.xz += _v.xz * _skid;
		_p.y = _ground;
	} else {
		_p += _v * _tr;
		_p.y -= 0.5 * _g * _tr * _tr;
		_p.y = max(_p.y, _ground);
	}
	return _p;
}
