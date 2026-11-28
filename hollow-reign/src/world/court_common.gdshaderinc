// Shared by the continuous Courtyard's surfaces (court_stone.gdshader, court_ground.gdshader; src/world/court_dress.gd).
// `route_lut` is a strip along the route (z from +90 to -310): r the road's spine height (the ground a wall stands on),
// g where the sea cliff's edge is (x), b the middle of the way (x).

float h21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

vec3 route_at(sampler2D lut, float z) {
	return texture(lut, vec2(clamp((90.0 - z) / 400.0, 0.0, 1.0), 0.5)).rgb;
}

// Coursed stone: rows `ch` high, blocks about `bl` long, every row its own length and its own offset.
// Returns (u, v) inside the block (0..1), the block's length, and writes the block's own random value to `id`.
vec3 coursed(vec2 p, float ch, float bl, out float id) {
	float row = floor(p.y / ch);
	float w = bl * mix(0.6, 1.5, h21(vec2(row, 7.1)));
	float x = p.x + h21(vec2(row, 3.3)) * w;
	float col = floor(x / w);
	id = h21(vec2(col, row + 0.5));
	return vec3(fract(x / w), fract(p.y / ch), w);
}
