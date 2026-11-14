// MUZZLUX element placing and flight. Nothing here declares a uniform.
//
// muzzlux_shots.gdshaderinc includes this file, so a shader that includes *that* gets
// everything below as well. Never include both: the shader language has no include guard and
// the functions would be defined twice.
//
// Lite version. The full pack adds the 2D twins of the index readers (a canvas_item shader
// has no UV2, so the 2D meshes carry the index in COLOR) and the analytic flight with up to
// two bounces and a slide to a stop, which is what puts brass on the floor.

// The element index and sub index a vertex carries (see MuzzluxMeshes).
float mx_element(vec2 uv2) {
	return uv2.x;
}

float mx_sub(vec2 uv2) {
	return uv2.y;
}

// Collapses a vertex to a point, so a slot with nothing in it costs no fragments. Godot does
// not allow `return` inside vertex(), so this is how an empty slot is skipped.
vec3 mx_hide() {
	return vec3(0.0, -100000.0, 0.0);
}


// ---------------------------------------------------------------- flight

// Analytic flight: one evaluation gives the position at any time, so a chip thrown half a
// second ago costs the same as one thrown this frame and nothing is stepped on the CPU.
//
vec3 mx_free_flight(vec3 p0, vec3 v0, float t, float g, float drag) {
	float k = drag > 0.0001 ? (1.0 - exp(-drag * t)) / drag : t;
	vec3 p = p0 + v0 * k;
	p.y -= 0.5 * g * t * t;
	return p;
}

// ---------------------------------------------------------------- placing elements

// A basis whose +z is `n`, with a roll around it, for a quad lying on a hit surface (a
// bullet hole, a scorch ring, a skid streak).
mat3 mx_surface_basis(vec3 n, float roll) {
	vec3 up = abs(n.y) < 0.9 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
	vec3 t = normalize(cross(up, n));
	vec3 b = cross(n, t);
	float c = cos(roll);
	float s = sin(roll);
	return mat3(t * c + b * s, b * c - t * s, n);
}

// A basis whose +z points at the camera, with a roll, for a flash or a puff that must read
// from every direction.
mat3 mx_billboard_basis(vec3 world_pos, vec3 cam_pos, float roll) {
	vec3 n = normalize(cam_pos - world_pos);
	return mx_surface_basis(n, roll);
}
