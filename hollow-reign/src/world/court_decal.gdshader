shader_type spatial;
// Stains laid on the Courtyard's ground and walls (src/world/court_dress.gd): soot, old blood, damp, earth washed out
// of a joint. A card a little off the surface; COLOR.rgb is the stain, COLOR.a its strength; the blot is ragged by
// noise and fades to nothing at its edges. Lit, so it darkens what is under it rather than glowing.
render_mode blend_mix, depth_draw_never, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float n = texture(noise_tex, wpos.xz * 0.35 + wpos.y * 0.2).r;
	float n2 = texture(noise_tex, UV * 1.3 + COLOR.rg * 4.0).r;
	float r = length(q) + (n - 0.5) * 0.7 + (n2 - 0.5) * 0.5;
	float a = (1.0 - smoothstep(0.35, 0.95, r)) * COLOR.a;
	ALBEDO = COLOR.rgb * (0.75 + 0.5 * n);
	ALPHA = clamp(a, 0.0, 1.0);
	ROUGHNESS = 0.9;
	SPECULAR = 0.25;
}
