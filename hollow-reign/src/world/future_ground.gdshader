shader_type spatial;
// The floor of a duel arena in the far-future kit (src/world/future.gd): the land is natural, what is laid on it is not.
// A deck of ceramic plates set flush in the ground round the duelling ring (an alloy band with a line of light in it,
// a second band at the deck's edge, joints every few metres), and beyond the deck the region's own land: turf, ash,
// ice or wet rock from the region's ground texture, taking the deck back at its edge and in patches where plates have
// gone. The floor is flat everywhere: nothing here changes where a fighter stands.
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D panel_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D panel_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D land_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D land_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 deck : source_color = vec3(0.62, 0.63, 0.62);     // the plates
uniform vec3 band : source_color = vec3(0.2, 0.21, 0.23);      // the inlaid alloy
uniform vec3 seam : source_color = vec3(0.3, 0.8, 0.9);        // the light in the bands (black: dead)
uniform vec3 land_a : source_color = vec3(0.3, 0.4, 0.15);     // the land's two tones (multiplied into its texture)
uniform vec3 land_b : source_color = vec3(0.5, 0.48, 0.22);
uniform float land_tex_amt = 0.6;  // 0: the land is its two tones only; 1: its texture's own colour
uniform float land_scale = 0.22;
uniform float deck_r = 9.5;        // the deck's radius; beyond about 40 the whole floor is deck
uniform float lost = 0.25;         // how much of the deck the land has taken back in patches
uniform float snow = 0.0;
uniform float wet = 0.0;
uniform float ring_r = 4.38;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// 1 on a line at every half-integer of v, `w` its half width in v's units, `aa` one pixel in v's units
float line(float v, float w, float aa) {
	return 1.0 - smoothstep(w, w + aa, abs(fract(v) - 0.5));
}

void fragment() {
	vec2 p = wpos.xz;
	float r = length(p);
	float n1 = texture(noise_tex, p * 0.021).r;
	float n2 = texture(noise_tex, p * 0.09 + vec2(0.37, 0.11)).r;
	float n3 = texture(noise_tex, p * 0.7).r;
	// ---- the land
	vec3 lt = texture(land_tex, p * land_scale).rgb;
	vec3 lt2 = texture(land_tex, p.yx * land_scale * 0.31 + vec2(0.4, 0.1)).rgb;
	float ll = dot(mix(lt, lt2, 0.35), vec3(0.35, 0.5, 0.15));
	vec3 tone = mix(land_a, land_b, smoothstep(0.38, 0.62, n1 * 0.6 + n2 * 0.4));
	vec3 land = mix(tone * (0.45 + 1.5 * ll), mix(lt, lt2, 0.35) * tone * 2.6, land_tex_amt) * (0.86 + 0.28 * n3);
	// ---- where the deck still is: inside its radius, less what the land has taken back (never inside the ring)
	float edge = deck_r + (n2 - 0.5) * 2.6 + (n3 - 0.5) * 0.5;
	float on = 1.0 - smoothstep(edge - 0.25, edge + 0.25, r);
	float patches = smoothstep(0.62 - lost * 0.3, 0.7 - lost * 0.3, n1 * 0.55 + n2 * 0.45) * smoothstep(ring_r + 1.6, ring_r + 3.4, r);
	on *= 1.0 - patches * step(0.001, lost);
	// ---- the deck: plates, joints, bands
	vec3 pt = texture(panel_tex, p * 0.17).rgb;
	vec3 d = deck * (0.62 + 0.5 * pt.r) * (0.88 + 0.24 * n2);
	// stains: rain has run across it for a long time
	d *= mix(0.6, 1.0, smoothstep(0.3, 0.62, n1 * 0.45 + n2 * 0.3 + n3 * 0.25));
	// joints: rings every three metres out from the duelling ring, spokes between them
	float ang = atan(p.y, p.x) / 6.2832;
	float inner = step(r, ring_r);
	float spokes = mix(16.0, 8.0, inner);
	float px = length(fwidth(p));
	float jr = line((r - ring_r) / 3.0, 0.012, px / 3.0);
	float per_m = spokes / (6.2832 * max(r, 0.6));
	float ja = line(ang * spokes, 0.035 * per_m, px * per_m) * step(1.2, r) * (1.0 - step(ring_r - 0.05, r) * step(r, ring_r + 0.2));
	float joint = max(jr * step(ring_r + 1.0, r), ja);
	d = mix(d, d * 0.3, joint * 0.85);
	// the duelling ring: an alloy band with a line of light down its middle; a narrower dead band at the hub
	float rb = 1.0 - smoothstep(0.11, 0.13, abs(r - ring_r));
	float rl = 1.0 - smoothstep(0.018, 0.03, abs(r - ring_r));
	float hub = (1.0 - smoothstep(0.03, 0.04, abs(r - 1.2))) * 0.6;
	// dashes: the line is cut where the spokes cross it, and some lengths of it are dead
	float dash = step(0.06, abs(fract(ang * 32.0) - 0.5)) * step(0.3, fract(sin(floor(ang * 32.0) * 12.9898) * 43758.5453));
	d = mix(d, band * (0.8 + 0.4 * pt.r), max(rb, hub));
	vec3 glow = seam * rl * dash * 1.6;
	// a band at the deck's own edge, where there is an edge
	float eb = (1.0 - smoothstep(0.2, 0.24, abs(r - (deck_r - 1.6)))) * step(deck_r, 39.0);
	d = mix(d, band * (0.8 + 0.4 * pt.r), eb);
	glow += seam * (1.0 - smoothstep(0.02, 0.04, abs(r - (deck_r - 1.6)))) * step(deck_r, 39.0) * step(0.55, fract(ang * 12.0 + 0.1)) * 0.9;
	// ---- together
	vec3 c = mix(land, d, on);
	vec3 nm = mix(texture(land_n, p * land_scale).rgb, texture(panel_n, p * 0.17).rgb, on);
	// dirt creeps over the plates from the land side
	float creep = on * smoothstep(edge - 2.2, edge, r) * smoothstep(0.35, 0.65, n3);
	c = mix(c, land * 0.8, creep * 0.6);
	// ---- snow lies on everything but the lit lines
	float sn = snow * smoothstep(0.34, 0.62, n2 * 0.55 + n3 * 0.25 + ll * 0.5) * mix(1.0, 0.45, on) * smoothstep(1.5, 4.5, r + n2 * 2.0);
	c = mix(c, vec3(0.8, 0.85, 0.92), sn);
	ALBEDO = c;
	EMISSION = glow * on * (1.0 - sn);
	NORMAL_MAP = nm;
	NORMAL_MAP_DEPTH = mix(0.9, 0.7, on);
	ROUGHNESS = mix(mix(0.92, 0.58, on), 0.5, wet * (0.5 + 0.5 * n1)) ;
	METALLIC = 0.0;
	SPECULAR = mix(0.3, 0.42, max(on, wet));
}
