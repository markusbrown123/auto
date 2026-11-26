shader_type spatial;
// Hollow Reign surface shader for generated (Tripo PBR) models.
// Same texture reads as StandardMaterial3D (albedo, normal, packed ORM), but roughness and metallic
// are clamped per pixel into a range chosen by asset class, so nothing renders as liquid chrome
// or wet plastic. Optional fresnel rim keeps a figure readable against a dark arena.
// Cost: 3 texture samples, no extra passes. Works on the Mobile renderer.
render_mode diffuse_burley, specular_schlick_ggx; //CULL

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float normal_scale = 1.0;
uniform float rough_min = 0.32;
uniform float rough_max = 1.0;
uniform float metal_max = 0.85;
uniform float spec = 0.4;
uniform vec3 rim_color : source_color = vec3(0.0);
uniform float rim_power = 3.0;
uniform vec3 flash : source_color = vec3(0.0);
uniform vec3 emissive : source_color = vec3(0.0);
uniform sampler2D emissive_tex : source_color, hint_default_black, filter_linear_mipmap;

void fragment() {
	vec4 a = texture(albedo_tex, UV);
	vec3 orm = texture(orm_tex, UV).rgb;
	ALBEDO = a.rgb * tint.rgb;
	ROUGHNESS = clamp(orm.g, rough_min, rough_max);
	METALLIC = min(orm.b, metal_max);
	SPECULAR = spec;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = normal_scale;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	EMISSION = flash + rim_color * rim + emissive * texture(emissive_tex, UV).rgb;
}
