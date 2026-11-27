shader_type spatial;
// Armour parts (ArmorParts). Same texture reads and the same parameters as pbr_clamp.gdshader (tint, flash,
// rim_color, rough_min/max, metal_max, spec), plus what the material study in docs/MODULAR_ARMOR.md needed:
//  - the generated roughness maps sit in a narrow glossy band (median about 0.3-0.45 on every suit), so roughness is
//    re-centred and spread (rough_pivot, rough_gain, rough_lift) before it is clamped;
//  - the black areas between the plates are meant to be an undersuit but carry the same gloss and metalness as the
//    plates, so near-black albedo is turned into matt cloth (cloth, cloth_dark).
// Cost: 3 texture samples, no extra passes. Works on the Mobile renderer.
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;   // both sides: a part is an open shell, and a flattened spike folds faces over

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float normal_scale = 1.0;
uniform float rough_min = 0.33;
uniform float rough_max = 1.0;
uniform float rough_pivot = 0.38;
uniform float rough_gain = 1.0;
uniform float rough_lift = 0.0;
uniform float metal_max = 0.85;
uniform float spec = 0.35;
uniform float cloth = 0.0;          // 0 off .. 1 near-black albedo becomes matt, non-metal cloth
uniform float cloth_dark = 0.05;    // albedo luminance (linear) below which a texel counts as undersuit
uniform vec3 rim_color : source_color = vec3(0.0);
uniform float rim_power = 3.0;
uniform vec3 flash : source_color = vec3(0.0);
// Refinish (ArmorParts.FINISH, off by default): the plate is coated and has worn.
//  coat  0 off .. 1 every texel that is not undersuit takes coat_color (the texture's own light and dark are kept as
//        a gentle variation), with coat_metal and coat_rough instead of the suit's chrome;
//  wear  0 off .. 1 dark wear where the suit's own maps say there is a crease or an edge: the occlusion channel, the
//        painted panel lines (dark albedo), and the steep parts of the normal map, where the coat is chipped in
//        small irregular patches. wear_edge sets how much of that chipping there is.
uniform float coat = 0.0;
uniform vec3 coat_color : source_color = vec3(0.86, 0.84, 0.79);
uniform float coat_metal = 0.06;
uniform float coat_rough = 0.62;
uniform float wear = 0.0;
uniform float wear_edge = 1.0;
uniform vec3 wear_color : source_color = vec3(0.075, 0.07, 0.066);
//  motif 0 off .. 1 the designs inlaid in the coated plate, some in dark metal and some as lines of light. They are
//        drawn where the part is (UV2, written by tools/armor_split.gd): on the standing body for trunk and head (x
//        sideways, +10 on what faces backward; y height, the body 1 tall), on the limb itself for upper arms (+20/30),
//        forearms (+40/50) and shins (+60/70) (x round the limb from its outer line, y along it), so they follow a limb.
//        Breast: the house's mark (an open ring round a ring of light, a diamond, a line of light falling from the gap).
//        Brow: a small ring of light. Crown: a dark line. Back: a ring and the spine's line of light. Pauldrons: a
//        ring round a ring of light over a chevron. Forearms and shins: a line of light between dark marks. Thin
//        dark panel breaks round the limbs.
//  glow_color  every light on the suit: the visor, the lines, (ArmorParts) the vents and the cast light.
//  visor the eye slot lit: dark texels of the helm's front within visor_half of visor_y.
//  fx    1 the lights breathe and a sheen passes up the plate now and then; 0 still (reduced motion).
//  edge_shine  how much the sculpted edges (steep parts of the normal map) catch the light under the coat.
uniform float motif = 0.0;
uniform vec3 motif_dark : source_color = vec3(0.16, 0.15, 0.14);
uniform vec3 glow_color : source_color = vec3(0.3, 0.9, 1.0);
uniform float motif_energy = 1.6;
uniform float chest_y = 0.775;
uniform vec2 back_span = vec2(0.66, 0.82);
uniform float visor = 0.0;                // brightness, 0 off
uniform float visor_y = 0.931;
uniform float visor_half = 0.011;
uniform float fx = 1.0;
uniform float edge_shine = 0.0;
//  etch  0 off .. 1 tone-on-tone ornament cut into the coat, no light and no second colour: a rippled field on the
//        breast, a fine weave on the pauldrons, ruled lines down the shins (each only a little darker and rougher than
//        the plate, so it shows as it catches the light), the house's small incised sigil on the breast and the brow,
//        and the faceplate's cut lines: two from the brow down across the cheeks, one down the chin, with the planes
//        between them shaded a step apart so the smooth helm reads as faceted.
//  trim  0 off .. 1 a pale line along the plates' borders (the steep parts of the normal map next to a seam).
uniform float etch = 0.0;
uniform float trim = 0.0;

float line_at(float d, float half_w, float aa) { return 1.0 - smoothstep(half_w, half_w + aa, abs(d)); }
float diamond(vec2 d, float r, float aa) { return 1.0 - smoothstep(r, r + aa, abs(d.x) + abs(d.y)); }
float ring_at(vec2 d, float r, float half_w, float aa) { return 1.0 - smoothstep(half_w, half_w + aa, abs(length(d) - r)); }
float span(float v, float lo, float hi) { return step(lo, v) * step(v, hi); }

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x), mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec4 a = texture(albedo_tex, UV);
	vec3 orm = texture(orm_tex, UV).rgb;
	float lum = dot(a.rgb, vec3(0.2126, 0.7152, 0.0722));
	float under = cloth * (1.0 - smoothstep(cloth_dark, cloth_dark * 2.5, lum));
	vec3 nm = texture(normal_tex, UV).rgb;
	vec3 alb = a.rgb;
	float r = clamp((orm.g - rough_pivot) * rough_gain + rough_pivot + rough_lift, rough_min, rough_max);
	float metal = min(orm.b, metal_max);
	if (coat > 0.0) {
		float plate = coat * smoothstep(cloth_dark, cloth_dark * 2.5, lum);
		// the coat: the texture's light and dark stay as a soft variation, its colour does not
		float n0 = vnoise(UV * 7.0);
		vec3 coated = coat_color * mix(0.8, 1.05, smoothstep(0.04, 0.5, lum)) * (1.0 - 0.1 * wear * smoothstep(0.35, 0.8, n0));
		float slope = length(nm.xy * 2.0 - 1.0);
		float crease = (1.0 - orm.r) * 1.5 + (1.0 - smoothstep(cloth_dark * 1.6, cloth_dark * 4.0, lum)) * 0.75;
		float n1 = vnoise(UV * 70.0);
		float n2 = vnoise(UV * 260.0);
		float chip = smoothstep(0.12, 0.34, slope) * smoothstep(0.36, 0.62, n1 * 0.65 + n2 * 0.35) * wear_edge;
		float scuff = smoothstep(0.58, 0.85, n1 * 0.5 + vnoise(UV * 19.0) * 0.5) * 0.3 * wear_edge;
		float w = clamp(wear * (crease + chip * 1.3 + scuff), 0.0, 1.0) * plate;
		float edge = smoothstep(0.1, 0.32, slope) * (1.0 - clamp(crease, 0.0, 1.0));
		coated *= 1.0 + edge_shine * edge;
		coated = mix(coated, min(coat_color * 1.45, vec3(0.95)), trim * smoothstep(0.2, 0.42, slope) * (1.0 - clamp(crease, 0.0, 1.0)) * 0.7);
		alb = mix(a.rgb, coated, plate);
		alb = mix(alb, wear_color, w);
		r = mix(r, coat_rough + 0.06 * (n2 - 0.5) - 0.14 * edge * step(0.001, edge_shine), plate);
		r = mix(r, 0.78, w);
		metal = mix(metal, coat_metal, plate);
		metal = mix(metal, 0.35, w * step(0.5, chip));
	}
	if (etch > 0.0 && coat > 0.0) {
		float code = floor((UV2.x + 5.0) / 10.0);
		vec2 q = vec2(UV2.x - 10.0 * code, UV2.y);
		float aa = max(fwidth(q.y), fwidth(q.x)) * 1.2 + 0.0002;
		float whole = step(fwidth(UV2.x), 0.01);
		float plate = coat * smoothstep(cloth_dark, cloth_dark * 2.5, lum) * whole;
		float front = 1.0 - step(0.5, code);
		float field = 0.0;          // -1 .. 1: the ornament's relief
		// breast: ripples like pattern-welded steel, fading out at the edges of the field
		vec2 e = q - vec2(0.0, chest_y);
		float warp = vnoise(q * 34.0) * 5.0 + vnoise(q * 90.0) * 1.6;
		float rip = sin(q.y * 520.0 + warp + 7.0 * abs(q.x) * 30.0 * 0.1);
		float in_breast = front * (1.0 - smoothstep(0.075, 0.105, abs(e.x))) * smoothstep(-0.17, -0.14, e.y) * (1.0 - smoothstep(0.035, 0.055, e.y));
		field += rip * in_breast;
		// pauldrons: a fine weave
		float arm = span(code, 1.5, 3.5);
		float weave = sin((q.x + q.y) * 700.0) * sin((q.x - q.y) * 700.0);
		field += weave * arm * (1.0 - smoothstep(0.06, 0.08, q.y)) * step(0.004, q.y) * (1.0 - smoothstep(0.03, 0.045, abs(q.x)));
		// shins: ruled lines, closer toward the ankle
		float shin = span(code, 5.5, 7.5);
		field += sin(q.x * 900.0) * shin * span(q.y, 0.045, 0.19) * (1.0 - smoothstep(0.02, 0.032, abs(q.x)));
		field *= plate * etch;
		alb *= 1.0 - 0.085 * field;
		r = clamp(r + 0.13 * field, 0.2, 1.0);
		// the sigil, incised: an open ring, a diamond, a stem (breast), and smaller on the brow
		float lw = 0.0014;
		float rr = length(e);
		float open = smoothstep(0.62, 0.8, -e.y / max(rr, 0.0001));
		float sig = ring_at(e, 0.0135, lw, aa) * (1.0 - open) + diamond(e, 0.0042, aa) + line_at(e.x, lw * 0.8, aa) * span(e.y, -0.036, -0.012);
		vec2 hb = q - vec2(0.0, visor_y + 0.036);
		float hr = length(hb);
		float hopen = smoothstep(0.62, 0.8, -hb.y / max(hr, 0.0001));
		sig += ring_at(hb, 0.0075, lw * 0.8, aa) * (1.0 - hopen) + diamond(hb, 0.0024, aa);
		// the faceplate's cut lines and planes
		float in_face = front * step(visor_y - 0.07, q.y) * step(q.y, visor_y + 0.03) * step(abs(q.x), 0.07);
		float cheek = q.y - (visor_y + 0.026 - 1.25 * abs(q.x));
		float cut = line_at(cheek, lw * 0.9, aa) + line_at(q.x, lw * 0.8, aa) * step(q.y, visor_y - 0.022);
		float planes = (step(0.0, cheek) * 0.06 - step(q.y, visor_y - 0.022) * 0.03 * sign(q.x)) * in_face;
		alb *= 1.0 + planes * plate * etch;
		float inc = clamp((sig * front + cut * in_face), 0.0, 1.0) * plate * etch;
		alb = mix(alb, alb * 0.42, inc);
		r = mix(r, 0.7, inc);
	}
	vec3 glow = vec3(0.0);
	float sheen = 0.0;
	if (motif > 0.0 || visor > 0.0) {
		float code = floor((UV2.x + 5.0) / 10.0);          // 0 front, 1 back, 2/3 upper arms, 4/5 forearms, 6/7 shins
		vec2 q = vec2(UV2.x - 10.0 * code, UV2.y);
		float aa = max(fwidth(q.y), fwidth(q.x)) * 1.2 + 0.0002;
		// (a triangle that runs from one region to another sweeps UV2.x through every value: nothing is drawn there)
		float whole = step(fwidth(UV2.x), 0.01);
		float plate = coat * smoothstep(cloth_dark, cloth_dark * 2.5, lum) * whole;
		float lw = 0.0021;
		float dark = 0.0;
		float light = 0.0;
		float front = 1.0 - step(0.5, code);
		float back = span(code, 0.5, 1.5);
		// ---- the breast: the house's mark
		vec2 e = q - vec2(0.0, chest_y);
		float rr = length(e);
		float open = smoothstep(0.62, 0.8, -e.y / max(rr, 0.0001));
		float bd = ring_at(e, 0.034, lw, aa) * (1.0 - open);
		bd += line_at(e.y + 0.062, lw * 0.8, aa) * span(abs(e.x), 0.009, 0.026);
		bd += line_at(e.y - 0.55 * abs(e.x) + 0.012, lw * 0.8, aa) * span(abs(e.x), 0.044, 0.082);
		bd += ring_at(vec2(abs(e.x) - 0.058, e.y + 0.03), 0.006, lw * 0.7, aa);
		bd += line_at(abs(q.x) - 0.072, lw * 0.6, aa) * span(q.y, chest_y - 0.16, chest_y - 0.065);        // side panel lines
		float bl = ring_at(e, 0.021, lw * 0.7, aa) + diamond(e, 0.0065, aa) + line_at(e.x, lw * 0.75, aa) * span(e.y, -0.105, -0.03);
		dark += bd * front;
		light += bl * front;
		// ---- the helm: a dark line over the crown, a ring of light on the brow
		dark += line_at(q.x, lw, aa) * step(visor_y + 0.045, q.y) * step(code, 1.5);
		vec2 hb = q - vec2(0.0, visor_y + 0.032);
		light += ring_at(hb, 0.0075, lw * 0.6, aa) * front;
		// ---- the back: a ring, and the spine's line of light with its nodes
		vec2 bk = q - vec2(0.0, back_span.y - 0.015);
		dark += ring_at(bk, 0.032, lw, aa) * back * step(abs(q.x), 0.05) * step(0.004, abs(q.x));
		light += ring_at(bk, 0.019, lw * 0.7, aa) * back;
		light += line_at(q.x, lw * 0.75, aa) * back * span(q.y, back_span.x, back_span.y - 0.04);
		for (int i = 0; i < 3; i++) {
			vec2 nd = q - vec2(0.0, mix(back_span.x, back_span.y - 0.05, 0.12 + 0.36 * float(i)));
			dark += (diamond(nd, 0.0095, aa) - diamond(nd, 0.006, aa)) * back;
		}
		// ---- pauldrons: a ring round a ring of light, a chevron under them
		float arm = span(code, 1.5, 3.5);
		vec2 pc = q - vec2(0.0, 0.034);
		dark += (ring_at(pc, 0.019, lw, aa) + line_at(pc.y - 0.7 * abs(pc.x) - 0.03, lw * 0.8, aa) * step(abs(pc.x), 0.024)) * arm;
		light += (ring_at(pc, 0.0105, lw * 0.7, aa) + diamond(pc, 0.0035, aa)) * arm;
		dark += line_at(q.y - 0.088, lw * 0.6, aa) * arm;                                              // a panel break round the arm
		// ---- forearms: a line of light between two dark strokes, a ring at the elbow end
		float fore = span(code, 3.5, 5.5);
		light += line_at(q.x, lw * 0.75, aa) * span(q.y, 0.04, 0.105) * fore;
		dark += (line_at(abs(q.x) - 0.014, lw * 0.6, aa) * span(q.y, 0.05, 0.095) + ring_at(q - vec2(0.0, 0.026), 0.0085, lw * 0.7, aa)) * fore;
		dark += line_at(q.y - 0.118, lw * 0.6, aa) * fore;
		// ---- shins: a diamond under the knee, a line of light down the front
		float shin = span(code, 5.5, 7.5);
		light += line_at(q.x, lw * 0.75, aa) * span(q.y, 0.075, 0.175) * shin;
		vec2 sd = q - vec2(0.0, 0.052);
		dark += ((diamond(sd, 0.012, aa) - diamond(sd, 0.008, aa)) + line_at(abs(q.x) - 0.016, lw * 0.6, aa) * span(q.y, 0.09, 0.16)) * shin;
		dark += line_at(q.y - 0.195, lw * 0.6, aa) * shin;
		dark = clamp(dark, 0.0, 1.0) * motif * plate;
		light = clamp(light, 0.0, 1.0) * motif * plate;
		float breathe = mix(1.0, 0.8 + 0.2 * sin(TIME * 1.4), fx);
		alb = mix(alb, motif_dark, dark);
		metal = mix(metal, 0.85, dark);
		r = mix(r, 0.36, dark);
		alb = mix(alb, glow_color * 0.5, light);
		glow += glow_color * motif_energy * light * breathe;
		// ---- the visor: the slot's own dark texels, lit
		float slot = (1.0 - smoothstep(cloth_dark, cloth_dark * 3.0, lum)) * front * (1.0 - smoothstep(visor_half * 0.6, visor_half, abs(q.y - visor_y))) * step(abs(q.x), 0.06) * whole;
		glow += glow_color * visor * slot * breathe;
		alb = mix(alb, glow_color, clamp(slot * visor, 0.0, 1.0) * 0.6);
		under *= 1.0 - clamp(slot * visor, 0.0, 1.0);
		// ---- a sheen that passes up the plate every seven seconds
		vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float at = fract(TIME / 7.0) * 3.2 - 0.3;
		float d_sh = (wp.y - at) * 8.0;
		sheen = exp(-d_sh * d_sh) * fx * coat * smoothstep(cloth_dark, cloth_dark * 2.5, lum);
		r = mix(r, r * 0.6, sheen);
		glow += mix(vec3(1.0), glow_color, 0.35) * 0.07 * sheen;
	}
	ALBEDO = alb * tint.rgb;
	ROUGHNESS = mix(r, 0.86, under);
	METALLIC = metal * (1.0 - under);
	SPECULAR = mix(spec, 0.2, under);
	NORMAL_MAP = nm;
	NORMAL_MAP_DEPTH = normal_scale;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	EMISSION = flash + rim_color * rim + glow;
}
