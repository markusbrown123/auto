shader_type spatial;
// Ivy and creeper on the Courtyard's walls (src/world/court_dress.gd): a card laid flat on a wall, cut into leaves by
// a fixed alpha scissor. Leaves are cells of a grid, each a pointed oval at its own angle and size; how many grow
// thins toward the card's edges and its foot (COLOR.a; UV.y 0 at the top, where it hangs from), with tendrils below.
// COLOR.r seeds the card; COLOR.g turns some of it brown.
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 leaf_a : source_color = vec3(0.13, 0.2, 0.07);
uniform vec3 leaf_b : source_color = vec3(0.24, 0.3, 0.1);
uniform vec3 dead : source_color = vec3(0.3, 0.2, 0.1);

float h(vec2 p) {
	p = fract(p * vec2(233.34, 851.73));
	p += dot(p, p + 23.45);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 size = max(UV2, vec2(0.5));          // metres the card covers (Batch.card), so leaves stay leaf-sized
	// coverage: dense in the body, thinning out at the sides and the foot, hanging strands
	float n = texture(noise_tex, UV * size * 0.35 + COLOR.r * 3.0).r;
	float n2 = texture(noise_tex, UV * size * 0.9 + COLOR.r * 5.0 + 0.3).r;
	float side = smoothstep(0.0, 0.22, min(UV.x, 1.0 - UV.x) + (n2 - 0.5) * 0.25);
	float strand = step(0.6, texture(noise_tex, vec2(UV.x * size.x * 1.3 + COLOR.r * 5.0, 0.2)).r);
	float body = smoothstep(0.95, 0.5, UV.y + (n - 0.5) * 0.7);
	float grow = max(body * side, strand * smoothstep(1.0, 0.55, UV.y + n * 0.2)) * COLOR.a;
	// two offset grids of leaves, each a pointed oval at its own angle; most cells of the body hold one
	float a = 0.0;
	vec2 qb = vec2(0.0);
	float rb = 0.0;
	for (int layer = 0; layer < 2; layer++) {
		vec2 m = UV * size * 5.0 + float(layer) * vec2(0.5, 0.37);
		vec2 cell = floor(m);
		vec2 f = fract(m) - 0.5;
		float r = h(cell + COLOR.r * 17.0 + float(layer) * 13.0);
		float ang = r * 6.283;
		vec2 q = mat2(vec2(cos(ang), sin(ang)), vec2(-sin(ang), cos(ang))) * (f + (vec2(h(cell + 3.1), h(cell + 7.7)) - 0.5) * 0.3);
		float leaf = 1.0 - smoothstep(0.42, 0.48, length(q * vec2(1.0, 1.45)) + abs(q.y) * 0.25);
		float here = leaf * step(r * 0.8 + 0.1, grow * 1.1);
		if (here > a) {
			a = here;
			qb = q;
			rb = r;
		}
	}
	vec3 c = mix(leaf_a, leaf_b, h(vec2(rb, 1.3)));
	c = mix(c, dead, step(1.0 - COLOR.g * 0.45, h(vec2(rb, 5.5))));
	c *= 0.65 + 0.5 * (0.5 - qb.y) * (0.8 + 0.4 * n2);
	ALBEDO = c;
	ALPHA = a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 0.7;
	SPECULAR = 0.35;
	NORMAL_MAP = normalize(vec3(qb * 0.9 + 0.5, 1.0));
	BACKLIGHT = c * 0.4;
}
