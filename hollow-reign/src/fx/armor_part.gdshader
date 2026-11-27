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
		float scuff = smoothstep(0.58, 0.85, n1 * 0.5 + vnoise(UV * 19.0) * 0.5) * 0.3;
		float w = clamp(wear * (crease + chip * 1.3 + scuff), 0.0, 1.0) * plate;
		alb = mix(a.rgb, coated, plate);
		alb = mix(alb, wear_color, w);
		r = mix(r, coat_rough + 0.06 * (n2 - 0.5), plate);
		r = mix(r, 0.78, w);
		metal = mix(metal, coat_metal, plate);
		metal = mix(metal, 0.35, w * step(0.5, chip));
	}
	ALBEDO = alb * tint.rgb;
	ROUGHNESS = mix(r, 0.86, under);
	METALLIC = metal * (1.0 - under);
	SPECULAR = mix(spec, 0.2, under);
	NORMAL_MAP = nm;
	NORMAL_MAP_DEPTH = normal_scale;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	EMISSION = flash + rim_color * rim;
}
