shader_type spatial;
// The natural ground of the continuous Courtyard (src/world/court_route.gd): turf on the gentle slopes, earth and scree
// where it steepens, bare rock on the cliffs and the ravine walls. Mapped from three sides in world space so a cliff
// face is not a smear of stretched grass. Dark and wet near the sea.
// Stage 3C (src/world/court_dress.gd): the turf has dry and lush patches, clover and stones in it, and is trodden to
// earth along the edges of the causeway (`route_lut` b: the middle of the way); earth carries pebbles; rock is bedded
// in strata, streaked dark where water runs, with lichen on its faces and moss and turf on its ledges.
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://src/world/court_common.gdshaderinc"

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D turf_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D turf_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D route_lut : filter_linear, repeat_disable;
uniform float has_lut = 0.0;
uniform vec3 turf_a : source_color = vec3(0.24, 0.34, 0.12);
uniform vec3 turf_b : source_color = vec3(0.42, 0.43, 0.2);
uniform vec3 turf_dry : source_color = vec3(0.5, 0.46, 0.27);
uniform vec3 earth : source_color = vec3(0.33, 0.27, 0.2);
uniform vec3 rock_tint : source_color = vec3(0.62, 0.6, 0.56);
uniform vec3 lichen : source_color = vec3(0.66, 0.64, 0.46);
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
	float n3 = texture(noise_tex, wpos.xz * 0.43 + vec2(0.71, 0.2)).r;
	float n4 = texture(noise_tex, wpos.xz * 1.9 + vec2(0.17, 0.53)).r;
	// turf: the texture's grain under two tones that drift over tens of metres, dry patches, dark clover, stones
	vec3 g = texture(turf_tex, wpos.xz * 0.21).rgb;
	vec3 g2 = texture(turf_tex, wpos.zx * 0.067 + vec2(0.3, 0.1)).rgb;
	float gl = dot(mix(g, g2, 0.4), vec3(0.35, 0.5, 0.15));
	vec3 turf = mix(turf_a, turf_b, smoothstep(0.35, 0.65, n1 * 0.7 + n2 * 0.3)) * (0.55 + 1.2 * gl);
	turf = mix(turf, turf_dry * (0.6 + 0.9 * gl), smoothstep(0.55, 0.75, n2 * 0.6 + n3 * 0.5) * 0.7);
	turf *= mix(1.0, 0.72, smoothstep(0.6, 0.72, n3) * (1.0 - smoothstep(0.55, 0.75, n2)));
	float stones = smoothstep(0.73, 0.78, n4) * smoothstep(0.45, 0.6, n2);
	turf = mix(turf, vec3(0.5, 0.49, 0.45) * (0.8 + 0.4 * n3), stones);
	// earth, with pebbles in it
	vec3 dirt = earth * (0.7 + 0.6 * gl) * (0.85 + 0.3 * n3);
	dirt = mix(dirt, vec3(0.45, 0.42, 0.38), smoothstep(0.7, 0.76, n4) * 0.8);
	// rock: the texture from three sides, bedded in strata, streaked, lichen on its faces
	vec3 rock = tri(rock_tex, wpos, w, 0.09) * rock_tint;
	float bed = texture(noise_tex, vec2(wpos.x * 0.004 + wpos.z * 0.004, wpos.y * 0.09 + n1 * 0.4)).r;
	rock *= 0.78 + 0.35 * n2 + (bed - 0.5) * 0.35;
	float streak = smoothstep(0.55, 0.8, texture(noise_tex, vec2((wpos.x + wpos.z) * 0.15, wpos.y * 0.01)).r);
	rock *= 1.0 - streak * (1.0 - up) * 0.4;
	rock = mix(rock, lichen * (0.7 + 0.4 * n3), smoothstep(0.66, 0.74, n4 * 0.6 + n2 * 0.5) * 0.55);
	// what the slope allows: turf where it is gentle, earth and scree as it steepens, rock on the faces
	float t_turf = smoothstep(0.62, 0.8, up + (n2 - 0.5) * 0.12);
	float t_earth = smoothstep(0.45, 0.62, up + (n1 - 0.5) * 0.1) * (1.0 - t_turf);
	// trodden earth along the causeway's edges
	if (has_lut > 0.5) {
		vec3 rt = route_at(route_lut, wpos.z);
		float off = abs(wpos.x - rt.b);
		float trod = (1.0 - smoothstep(1.4, 2.6 + n2 * 1.2, off)) * smoothstep(0.85, 0.95, up);
		trod *= step(wpos.z, 58.0) * step(-60.0, wpos.z);
		t_earth = max(t_earth, trod * 0.85 * (1.0 - t_turf * 0.15));
		t_turf *= 1.0 - trod * 0.85;
	}
	vec3 c = mix(rock, dirt, t_earth);
	c = mix(c, turf, t_turf);
	// moss and turf on the ledges of the rock
	float ledge = smoothstep(0.35, 0.6, up) * (1.0 - t_turf) * (1.0 - t_earth) * smoothstep(0.4, 0.65, n2);
	c = mix(c, turf_a * (0.7 + 0.8 * gl), ledge * 0.7);
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
