shader_type spatial;
// Banners and standards of the continuous Courtyard (src/world/court_dress.gd): wool gone dull, a pale device on a
// dyed field (COLOR.rgb is the dye, COLOR.a the device's variant), hung from the top edge (UV.y 0) and moving in
// the wind more the further from it. Torn: the hem and holes are cut out with a fixed alpha scissor (a varying
// threshold renders black on the Mobile renderer, see GRAPHICS_BIBLE "Renderer trap").
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 device : source_color = vec3(0.72, 0.66, 0.52);
uniform float wind = 1.0;
uniform vec3 dye : source_color = vec3(0.34, 0.08, 0.06);
uniform float kit_dye = 0.0;               // banners the kit builds carry no colours: use `dye`

varying vec3 wpos;

void vertex() {
	vec3 w0 = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float hang = UV.y * UV.y;
	float ph = w0.x * 0.31 + w0.z * 0.27;
	float sway = sin(TIME * 1.3 + ph + UV.y * 2.2) * 0.6 + sin(TIME * 2.9 + ph * 1.7 + UV.x * 3.0) * 0.25;
	VERTEX += NORMAL * sway * hang * 0.22 * wind;
	VERTEX.y += hang * 0.03 * sin(TIME * 2.0 + ph);
	wpos = w0;
}

void fragment() {
	vec2 uv = UV;
	float seed = mix(COLOR.a, fract(floor(wpos.x * 0.5) * 0.37 + floor(wpos.z * 0.5) * 0.61), kit_dye);
	float n = texture(noise_tex, uv * vec2(1.3, 2.6) + vec2(seed * 3.1, wpos.x * 0.01)).r;
	float n2 = texture(noise_tex, uv * vec2(5.0, 9.0) + vec2(seed * 7.0, 0.3)).r;
	// the hem torn into tongues, holes through the field
	float hem = 0.78 + 0.2 * n + 0.08 * sin(uv.x * 23.0 + seed * 9.0);
	float a = step(uv.y, hem) * step(0.1, smoothstep(0.66, 0.74, 1.0 - n2) + step(n2, 0.66));
	a *= step(0.02, uv.x) * step(uv.x, 0.98);
	// the field, a border, the device: a ring over a bar (the old house's sign; original)
	vec3 c = mix(COLOR.rgb, dye, kit_dye);
	vec2 q = uv - vec2(0.5, 0.34);
	q.x *= 1.6;
	float r = length(q);
	float ring = 1.0 - smoothstep(0.012, 0.03, abs(r - 0.15));
	float bar = (1.0 - smoothstep(0.03, 0.045, abs(uv.x - 0.5))) * step(0.42, uv.y) * step(uv.y, 0.68);
	float chev = (1.0 - smoothstep(0.015, 0.03, abs(uv.y - 0.12 - abs(uv.x - 0.5) * 0.4)));
	float border = 1.0 - smoothstep(0.03, 0.045, min(uv.x, 1.0 - uv.x));
	float dev = max(max(ring, bar * step(0.5, seed)), max(chev * step(seed, 0.5), border * 0.7));
	c = mix(c, device, dev * 0.85);
	// faded toward the hem, dirty, darker in its folds
	c *= mix(1.0, 0.55, uv.y * 0.7) * (0.8 + 0.4 * n);
	ALBEDO = c;
	ALPHA = a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
	BACKLIGHT = c * 0.35;
}
