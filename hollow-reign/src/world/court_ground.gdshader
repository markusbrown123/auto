shader_type spatial;
// The natural ground of the continuous Courtyard (src/world/court_route.gd): turf on the gentle slopes, earth and scree
// where it steepens, bare rock on the cliffs and the ravine walls. Mapped from three sides in world space so a cliff
// face is not a smear of stretched grass. Dark and wet near the sea.
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D turf_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D turf_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 turf_a : source_color = vec3(0.24, 0.34, 0.12);
uniform vec3 turf_b : source_color = vec3(0.42, 0.43, 0.2);
uniform vec3 earth : source_color = vec3(0.33, 0.27, 0.2);
uniform vec3 rock_tint : source_color = vec3(0.62, 0.6, 0.56);
uniform float sea_level = -42.0;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec3 tri(sampler2D t, vec3 p, vec3 w, float s) {
	return texture(t, p.zy * s).rgb * w.x + texture(t, p.xz * s).rgb * w.y + texture(t, p.xy * s).rgb * w.z;
}

void fragment() {
	vec3 w = pow(abs(wnrm), vec3(4.0));
	w /= (w.x + w.y + w.z);
	float up = wnrm.y;
	float n1 = texture(noise_tex, wpos.xz * 0.018).r;
	float n2 = texture(noise_tex, wpos.xz * 0.11 + vec2(0.31, 0.7)).r;
	// turf: the texture's grain under two tones that drift over tens of metres
	vec3 g = texture(turf_tex, wpos.xz * 0.21).rgb;
	vec3 g2 = texture(turf_tex, wpos.zx * 0.067 + vec2(0.3, 0.1)).rgb;
	float gl = dot(mix(g, g2, 0.4), vec3(0.35, 0.5, 0.15));
	vec3 turf = mix(turf_a, turf_b, smoothstep(0.35, 0.65, n1 * 0.7 + n2 * 0.3)) * (0.55 + 1.2 * gl);
	vec3 rock = tri(rock_tex, wpos, w, 0.09) * rock_tint;
	rock *= 0.8 + 0.35 * n2;
	// what the slope allows: turf where it is gentle, earth and scree as it steepens, rock on the faces
	float t_turf = smoothstep(0.62, 0.8, up + (n2 - 0.5) * 0.12);
	float t_earth = smoothstep(0.45, 0.62, up + (n1 - 0.5) * 0.1) * (1.0 - t_turf);
	vec3 c = mix(rock, earth * (0.7 + 0.6 * gl), t_earth);
	c = mix(c, turf, t_turf);
	// wet and dark near the sea
	float wet = 1.0 - smoothstep(sea_level + 1.0, sea_level + 9.0, wpos.y);
	c *= mix(1.0, 0.55, wet);
	vec3 nm = mix(tri(rock_n, wpos, w, 0.09), texture(turf_n, wpos.xz * 0.21).rgb, t_turf);
	ALBEDO = c;
	NORMAL_MAP = nm;
	NORMAL_MAP_DEPTH = 0.8;
	ROUGHNESS = mix(0.92, 0.55, wet);
	SPECULAR = 0.3;
	METALLIC = 0.0;
}
