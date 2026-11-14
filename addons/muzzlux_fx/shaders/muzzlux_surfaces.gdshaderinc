// MUZZLUX surface rows. The material a shot hit, as four uniform arrays indexed by the
// surface id a shot slot carries in c.z.
//
// This is why one MuzzluxImpact3D (or one MuzzluxHoles3D) can show nine different materials
// at once: the look is not a shader branch and not a separate node, it is a row of numbers
// the vertex shader reads for the slot it is drawing. A player who sprays a wall of concrete,
// steel and wood gets the right debris, sparks, dust and crater for each hit out of one
// static mesh and one material.
//
// MuzzluxSurfaces.apply_rows_to() fills the arrays; MuzzluxSurfaces.MAX_ROWS must stay equal
// to MX_SURFACES. Row 0 is `concrete`, and an id the table does not know falls back to it.
//
//   surf_a[i] = vec4(debris colour rgb, chips)
//   surf_b[i] = vec4(dust colour rgb, dust_amount)
//   surf_c[i] = vec4(sparks, dust_rise, along, gravity)
//   surf_d[i] = vec4(hole, hole_style, light, duration)
//   surf_e[i] = vec4(ring, ring_speed, bloom, debris_size)

#define MX_SURFACES 16

uniform vec4 surf_a[MX_SURFACES];
uniform vec4 surf_b[MX_SURFACES];
uniform vec4 surf_c[MX_SURFACES];
uniform vec4 surf_d[MX_SURFACES];
uniform vec4 surf_e[MX_SURFACES];

struct MxSurface {
	vec3 debris;
	vec3 dust;
	float chips;
	float dust_amount;
	float sparks;
	float dust_rise;
	float along;
	float gravity;
	float hole;
	float style;
	float light;
	float duration;
	float ring;
	float ring_speed;
	float bloom;
	float debris_size;
};

MxSurface mx_surface(float id) {
	int k = clamp(int(id + 0.5), 0, MX_SURFACES - 1);
	vec4 a = surf_a[k];
	vec4 b = surf_b[k];
	vec4 c = surf_c[k];
	vec4 d = surf_d[k];
	vec4 e = surf_e[k];
	MxSurface s;
	s.debris = a.rgb;
	s.chips = a.a;
	s.dust = b.rgb;
	s.dust_amount = b.a;
	s.sparks = c.x;
	s.dust_rise = c.y;
	s.along = c.z;
	s.gravity = c.w;
	s.hole = d.x;
	s.style = d.y;
	s.light = d.z;
	s.duration = d.w;
	s.ring = e.x;
	s.ring_speed = e.y;
	s.bloom = e.z;
	s.debris_size = e.w;
	return s;
}

// True (1.0) when `style` is the crater kind `want`. The styles are whole numbers written by
// GDScript, so an equality test on floats is safe here; a tolerance is used anyway because
// the value has been through a uniform array.
float mx_is_style(float style, float want) {
	return abs(style - want) < 0.25 ? 1.0 : 0.0;
}
