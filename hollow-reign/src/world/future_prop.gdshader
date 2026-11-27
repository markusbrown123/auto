shader_type spatial;
// Surface for the far-future kit's generated props (env_fu_*; src/world/future.gd). The same three texture reads as
// pbr_clamp (albedo, normal, packed ORM) with roughness and metal clamped so nothing is chrome, and two things more:
//  - the lines of light painted into a prop's texture are found by colour (`key`) and made to give light, in the
//    region's own colour (`seam`), so one model serves a cyan courtyard, an ember hall and a gold throne room;
//  - `snow` lies on faces turned up, and `tint` sets the prop into the region's light (soot, frost, damp).
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec3 tint : source_color = vec3(1.0);
uniform vec3 seam : source_color = vec3(0.35, 0.85, 1.0);
uniform float seam_e = 2.2;
uniform vec3 key = vec3(-1.0, 0.4, 0.6);      // what counts as light in the texture: cyan by default
uniform float key_lo = 0.14;
uniform float key_hi = 0.3;
uniform float rough_min = 0.55;
uniform float metal_max = 0.45;
uniform float snow = 0.0;

varying vec3 wn;

void vertex() {
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 a = texture(albedo_tex, UV).rgb;
	vec3 orm = texture(orm_tex, UV).rgb;
	float lit = smoothstep(key_lo, key_hi, dot(a, key));
	float sn = snow * smoothstep(0.45, 0.8, wn.y);
	vec3 c = mix(a * tint, seam * 0.6, lit);
	ALBEDO = mix(c, vec3(0.82, 0.87, 0.94), sn);
	ROUGHNESS = mix(clamp(orm.g, rough_min, 1.0), 0.85, sn);
	METALLIC = min(orm.b, metal_max) * (1.0 - sn);
	SPECULAR = 0.35;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = 1.0 - sn * 0.6;
	EMISSION = seam * seam_e * lit * (1.0 - sn);
}
