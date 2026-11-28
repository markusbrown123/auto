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
	vec2 m = UV * size * 9.0;
	vec2 cell = floor(m);
	vec2 f = fract(m) - 0.5;
	float r = h(cell + COLOR.r * 17.0);
	float ang = r * 6.283;
	vec2 q = mat2(vec2(cos(ang), sin(ang)), vec2(-sin(ang), cos(ang))) * (f + (vec2(h(cell + 3.1), h(cell + 7.7)) - 0.5) * 0.4);
	float leaf = 1.0 - smoothstep(0.32, 0.38, length(q * vec2(1.0, 1.7)) + abs(q.y) * 0.4);
	// coverage: dense in the body, thinning out at the sides and the foot, hanging strands
	float n = texture(noise_tex, UV * size * 0.35 + COLOR.r * 3.0).r;
	float side = smoothstep(0.0, 0.25, min(UV.x, 1.0 - UV.x));
	float strand = step(0.62, texture(noise_tex, vec2(UV.x * size.x * 1.3 + COLOR.r * 5.0, 0.2)).r);
	float body = smoothstep(0.95, 0.45, UV.y + (n - 0.5) * 0.6);
	float grow = max(body * side, strand * step(UV.y, 0.98) * smoothstep(1.0, 0.6, UV.y + n * 0.2)) * COLOR.a;
	float keep = step(r * 0.55 + (1.0 - grow) * 0.9, 0.85) * leaf;
	vec3 c = mix(leaf_a, leaf_b, h(cell + 1.3));
	c = mix(c, dead, step(1.0 - COLOR.g * 0.45, h(cell + 5.5)));
	c *= 0.7 + 0.5 * (0.5 - f.y);
	ALBEDO = c;
	ALPHA = keep;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 0.7;
	SPECULAR = 0.35;
	NORMAL_MAP = normalize(vec3(q * 0.9 + 0.5, 1.0));
	BACKLIGHT = c * 0.4;
}
