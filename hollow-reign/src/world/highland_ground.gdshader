shader_type spatial;
// The headland's ground. Turf in two tones with large patches of colour, heather where the heather grows, earth and
// scree where it steepens and bare banded rock where it is steeper still; the road is laid slabs with joints, a
// kerb line and a lit guide strip down the middle, and grass fraying its edges where it is no longer kept. The sun's light is cut by the land's own baked shadow, the
// Ring-Gate's shadow and drifting cloud (highland_common).
render_mode diffuse_lambert, specular_disabled;

#include "highland_common.gdshaderinc"

uniform sampler2D path_mask : filter_linear, repeat_disable;
uniform sampler2D turf_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D turf_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 slab : source_color = vec3(0.62, 0.64, 0.64);
uniform vec3 guide : source_color = vec3(0.1, 0.4, 0.36);   // the light in the road's middle strip (black: dead)
uniform vec4 mask_rect;
uniform vec3 grass_a : source_color = vec3(0.3, 0.4, 0.15);
uniform vec3 grass_b : source_color = vec3(0.55, 0.52, 0.22);
uniform vec3 heather : source_color = vec3(0.45, 0.28, 0.45);
uniform vec3 rock_a : source_color = vec3(0.2, 0.19, 0.18);
uniform vec3 rock_b : source_color = vec3(0.52, 0.48, 0.42);
uniform vec3 earth : source_color = vec3(0.27, 0.22, 0.15);
uniform float heather_amt = 1.0;
uniform float wear = 1.0;          // 1: the road is walked and kept; less: turf has taken parts of it back
uniform float wet = 0.6;
uniform float sea_level = -76.0;

varying vec3 wpos;
varying vec3 wnrm;
varying float lit;
varying float gloss;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = NORMAL;
}

float lum(vec3 c) {
	return dot(c, vec3(0.35, 0.5, 0.15));
}

void fragment() {
	float dist = length(wpos - CAMERA_POSITION_WORLD);
	float n1 = texture(noise_tex, wpos.xz * 0.006).r;
	float n2 = texture(noise_tex, wpos.xz * 0.045 + vec2(0.37, 0.11)).r;
	float n3 = texture(noise_tex, wpos.xz * 0.61).r;
	// the detail map at two scales, so that neither one's repeat is seen on a far slope
	float tl = mix(lum(texture(turf_tex, wpos.xz * 0.21).rgb), lum(texture(turf_tex, wpos.zx * 0.037 + vec2(0.4, 0.1)).rgb), 0.35 + 0.45 * smoothstep(25.0, 120.0, dist));
	// ---- turf
	vec3 g = mix(grass_a, grass_b, smoothstep(0.36, 0.64, n1 * 0.6 + n2 * 0.4));
	g *= mix(0.72, 1.16, smoothstep(0.3, 0.7, texture(noise_tex, wpos.xz * 0.0021 + vec2(0.5, 0.2)).r));
	float hp = texture(noise_tex, wpos.xz * 0.011 + vec2(0.7, 0.2)).r;
	g = mix(g, mix(g, heather, 0.55) * 0.6, smoothstep(0.55, 0.6, hp * 0.62 + n2 * 0.38) * heather_amt * 0.8);
	// under the cards it is dark between the roots; beyond them it is the colour the cards would have been
	g *= mix(0.6, 0.86, smoothstep(40.0, 130.0, dist)) * (0.55 + 1.5 * tl) * (0.86 + 0.28 * n3);
	// ---- slope: turf, then earth and scree, then rock
	float ny = wnrm.y + (n2 - 0.5) * 0.16 + (n3 - 0.5) * 0.06;
	float rockw = smoothstep(0.8, 0.68, ny);
	float screew = smoothstep(0.91, 0.82, ny) * (1.0 - rockw);
	vec3 bw = abs(wnrm);
	float wx = bw.x * bw.x / (bw.x * bw.x + bw.z * bw.z + 0.0001);
	float rl = mix(lum(texture(rock_tex, wpos.xy * 0.085).rgb), lum(texture(rock_tex, wpos.zy * 0.085).rgb), wx);
	// beds: thin, uneven, and broken up by the stone's own grain rather than drawn over it
	float bed = wpos.y * 0.9 + n2 * 3.0 + n1 * 14.0;
	float strata = smoothstep(0.2, 0.8, fract(bed)) * (1.0 - smoothstep(0.86, 1.0, fract(bed)));
	strata = mix(strata, 0.5 + 0.5 * sin(wpos.y * 5.3 + n3 * 4.0), 0.3);
	vec3 rock = mix(rock_a, rock_b, clamp(rl * 1.7 - 0.12 + (strata - 0.5) * 0.24 + (n3 - 0.5) * 0.2, 0.0, 1.0));
	rock *= 0.8 + 0.4 * n2;
	// the foot of the sea cliff is dark and wet
	rock *= mix(0.45, 1.0, smoothstep(sea_level + 1.0, sea_level + 9.0, wpos.y));
	vec3 scree = mix(earth, rock_b * 0.8, smoothstep(0.42, 0.6, n3) * 0.6 + 0.4 * n2) * (0.75 + 0.7 * tl);
	vec3 c = mix(mix(g, scree, screew), rock, rockw);
	// ---- the road
	vec2 muv = (wpos.xz - mask_rect.xy) * mask_rect.zw;
	float pm0 = texture(path_mask, muv).r;
	float pm = 0.0;
	gloss = 0.0;
	vec3 nmap = texture(turf_n, wpos.xz * 0.21).rgb;
	float nstr = 0.7 * (1.0 - rockw);
	vec3 glow = vec3(0.0);
	if (pm0 > 0.01) {
		// turf takes it back from the edges, and in the later generations in patches along it
		float keep = mix(smoothstep(0.38, 0.56, n2 * 0.6 + n1 * 0.4 + (wear - 0.5) * 0.36), 1.0, step(0.99, wear));
		float fray = 0.08 + 0.3 * (1.0 - wear);
		pm = smoothstep(0.36, 0.42 + fray * 0.3, pm0 * (0.55 + 0.45 * keep) + (n3 - 0.5) * fray + (tl - 0.3) * fray);
		// laid slabs: a joint across every three metres, a dark kerb line inside each edge, a guide strip down the middle
		float along = texture(path_mask, muv).g;
		float joint = smoothstep(0.9, 0.97, along);
		float kerb = smoothstep(0.5, 0.54, pm0) * (1.0 - smoothstep(0.6, 0.64, pm0));
		float strip = smoothstep(0.8, 0.86, pm0);
		vec3 road = slab * (0.84 + 0.3 * n2) * (0.92 + 0.3 * (n3 - 0.5));
		road = mix(road, road * 0.3, max(joint, kerb) * 0.85);
		road = mix(road, slab * 0.38, strip * (1.0 - joint));
		road = mix(road, earth * 1.1, (1.0 - keep) * 0.5 + smoothstep(0.55, 0.75, n2) * (1.0 - wear) * 0.5);
		c = mix(c, road, pm);
		nmap = mix(nmap, vec3(0.5, 0.5, 1.0), pm);
		gloss = pm * (0.45 + 0.55 * wet);
		glow = guide * strip * (1.0 - joint) * pm * keep;
	}
	// ---- snow lies where it is level, thinner on the road
	float sn = snow * smoothstep(0.42, 0.7, wnrm.y * 0.6 + n2 * 0.5 + (tl - 0.3) * 0.4) * (1.0 - pm * 0.5) * (1.0 - rockw * 0.6);
	c = mix(c, vec3(0.82, 0.86, 0.93), sn);
	gloss *= 1.0 - sn;
	ALBEDO = c;
	EMISSION = glow * (1.0 - sn * 0.6);
	NORMAL_MAP = nmap;
	NORMAL_MAP_DEPTH = nstr * (1.0 - smoothstep(60.0, 220.0, dist));
	ROUGHNESS = 1.0;
	lit = sun_shade(wpos);
}

void light() {
	float ndl = max(dot(NORMAL, LIGHT), 0.0);
	float s = LIGHT_IS_DIRECTIONAL ? lit : 1.0;
	DIFFUSE_LIGHT += ndl * ATTENUATION * LIGHT_COLOR * s / PI;
	vec3 h = normalize(LIGHT + VIEW);
	SPECULAR_LIGHT += pow(max(dot(NORMAL, h), 0.0), 48.0) * gloss * 0.5 * ATTENUATION * LIGHT_COLOR * s * step(0.0001, ndl);
}
