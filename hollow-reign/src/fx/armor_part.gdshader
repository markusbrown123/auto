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

void fragment() {
	vec4 a = texture(albedo_tex, UV);
	vec3 orm = texture(orm_tex, UV).rgb;
	float lum = dot(a.rgb, vec3(0.2126, 0.7152, 0.0722));
	float under = cloth * (1.0 - smoothstep(cloth_dark, cloth_dark * 2.5, lum));
	ALBEDO = a.rgb * tint.rgb;
	float r = clamp((orm.g - rough_pivot) * rough_gain + rough_pivot + rough_lift, rough_min, rough_max);
	ROUGHNESS = mix(r, 0.86, under);
	METALLIC = min(orm.b, metal_max) * (1.0 - under);
	SPECULAR = mix(spec, 0.2, under);
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = normal_scale;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	EMISSION = flash + rim_color * rim;
}
