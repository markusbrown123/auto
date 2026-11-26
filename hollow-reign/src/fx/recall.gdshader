shader_type spatial;
// Recall: an advanced weapon rebuilt into the hand (or taken apart again).
// One uniform, `progress` 0..1, drives everything:
//   0.00 - 0.72  the surface is revealed from the hilt outward behind a thin bright front
//   0.72 - 1.00  one narrow pulse runs the length of the finished piece
//   1.00         nothing of the effect is left; Recall (recall.gd) then puts the ordinary material back
// The same PBR reads as pbr_clamp (albedo, normal, packed ORM) so the piece looks identical while it forms.
// Cost over pbr_clamp: one mat4 multiply per vertex, a few ALU and one discard per pixel; no extra samples,
// no extra pass, opaque, casts its (partial) shadow. `cheap` drops the lattice jitter and the pulse.
render_mode diffuse_burley, specular_schlick_ggx; //CULL

uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D emissive_tex : source_color, hint_default_white, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0);
uniform float normal_scale = 0.0;
uniform float rough_mul = 1.0;
uniform float metal_mul = 1.0;
uniform float rough_min = 0.3;
uniform float rough_max = 1.0;
uniform float metal_max = 1.0;
uniform float spec = 0.5;
uniform vec3 emissive : source_color = vec3(0.0);

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform mat4 to_root = mat4(1.0);        // this mesh's space -> the item's root space
uniform vec3 axis_origin = vec3(0.0);    // hilt end of the long axis (or the grip, when radial)
uniform vec3 axis_dir = vec3(0.0, 1.0, 0.0);
uniform float axis_len = 1.0;
uniform float radial = 0.0;              // 1: shields open outward from the grip
uniform vec3 front_color : source_color = vec3(0.62, 0.9, 1.0);
uniform float front_energy = 2.4;
uniform float cheap = 0.0;

varying float h;
varying vec3 cell;

void vertex() {
	vec3 p = (to_root * vec4(VERTEX, 1.0)).xyz - axis_origin;
	h = mix(dot(p, axis_dir), length(p), radial) / axis_len;
	cell = p;
}

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void fragment() {
	float reveal = clamp(progress / 0.72, 0.0, 1.0);
	float cut = reveal * 1.08 - 0.03;
	float hh = h;
	if (cheap < 0.5) {
		// the leading edge is built in small facets rather than a ruled line
		hh += (hash(floor(cell * 90.0)) - 0.5) * 0.035 * (1.0 - reveal * reveal);
	}
	if (hh > cut) {
		discard;
	}
	vec4 a = texture(albedo_tex, UV);
	vec3 orm = texture(orm_tex, UV).rgb;
	ALBEDO = a.rgb * tint.rgb;
	ROUGHNESS = clamp(orm.g * rough_mul, rough_min, rough_max);
	METALLIC = min(orm.b * metal_mul, metal_max);
	SPECULAR = spec;
	if (normal_scale > 0.0) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
		NORMAL_MAP_DEPTH = normal_scale;
	}
	float live = 1.0 - step(1.0, reveal);
	// thin reconstruction front, and a short cooling zone behind it
	float front = smoothstep(cut - 0.022, cut, hh) * live;
	float cool = smoothstep(cut - 0.16, cut, hh) * 0.18 * live;
	float pulse = 0.0;
	if (cheap < 0.5) {
		float u = clamp((progress - 0.72) / 0.28, 0.0, 1.0);
		float at = u * 1.2 - 0.1;
		float d = (h - at) / 0.03;
		pulse = exp(-d * d) * step(0.001, u) * (1.0 - smoothstep(0.9, 1.0, u)) * 0.5;
	}
	EMISSION = emissive * texture(emissive_tex, UV).rgb + front_color * front_energy * (front + cool + pulse);
}
