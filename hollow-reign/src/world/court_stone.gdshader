shader_type spatial;
// The continuous Courtyard's masonry and paving (src/world/court_dress.gd, Stage 3C). No textures of its own: the
// block pattern is worked out here (courses of their own height, blocks of their own length and tone, bevelled and
// chipped arrises, recessed joints), laid on each face in its own plane so walls at any angle course properly, with
// the rock texture already loaded for the route (floor_roost) as the grain inside each block. Then age: rain streaks
// down upright faces, earth and damp at the foot of a wall (the route's ground height from `route_lut`), moss on what
// faces up, dark and wet toward the sea cliff.
// `paving` > 0.5 lays flagstones on faces turned up: some cracked, some gone to earth, grass in the joints, standing
// water in the hollows, the way worn smoother where it is walked.
// Beyond `future_x` (the broken tether far out in the sea) it is the makers' ceramic, plain.
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://src/world/court_common.gdshaderinc"

uniform sampler2D grain_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grain_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D route_lut : filter_linear, repeat_disable;
uniform vec3 tint : source_color = vec3(0.6, 0.58, 0.54);
uniform vec3 tint_b : source_color = vec3(0.5, 0.51, 0.5);
uniform float course = 0.56;
uniform float block = 1.1;
uniform float mortar = 0.02;
uniform float bevel = 0.07;
uniform float vary = 0.3;
uniform float grain = 0.6;
uniform float grain_scale = 0.12;
uniform vec3 moss : source_color = vec3(0.2, 0.26, 0.1);
uniform vec3 dirt : source_color = vec3(0.18, 0.16, 0.12);
uniform float moss_amt = 1.0;
uniform float dirt_h = 1.4;
uniform float paving = 0.0;
uniform float sea_level = -42.0;
uniform float future_x = 100000.0;
uniform vec3 future_tint : source_color = vec3(0.68, 0.69, 0.66);

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = normalize(wnrm);
	bool top = abs(n.y) > 0.72;
	vec3 s = top ? vec3(1.0, 0.0, 0.0) : normalize(vec3(-n.z, 0.0, n.x) + vec3(1e-5));
	vec3 t = top ? vec3(0.0, 0.0, 1.0) : vec3(0.0, 1.0, 0.0);
	vec2 p = vec2(dot(wpos, s), dot(wpos, t));
	bool pave = paving > 0.5 && n.y > 0.72;
	float ch = pave ? 0.95 : course;
	float bl = pave ? 1.25 : block;
	float mo = pave ? 0.035 : mortar;
	float bv = pave ? 0.12 : bevel;
	float id;
	vec3 b = coursed(p, ch, bl, id);
	vec2 near = vec2(min(b.x, 1.0 - b.x) * b.z, min(b.y, 1.0 - b.y) * ch);
	float d = min(near.x, near.y);
	vec3 rt = route_at(route_lut, wpos.z);

	vec2 gp = p * grain_scale + vec2(id * 7.31, id * 3.17);
	vec3 g = texture(grain_tex, gp).rgb;
	float gl = dot(g, vec3(0.3, 0.55, 0.15));
	vec3 gn = texture(grain_n, gp).rgb * 2.0 - 1.0;
	float n1 = texture(noise_tex, wpos.xz * 0.019 + vec2(wpos.y * 0.011)).r;
	float n2 = texture(noise_tex, p * 0.31 + vec2(0.3, 0.7)).r;
	float n3 = texture(noise_tex, p * 0.53 + vec2(id * 0.37 + 0.61, id * 0.71 + 0.13)).r;

	// two stones, the block's own tone, the grain
	vec3 c = mix(tint, tint_b, smoothstep(0.3, 0.75, h21(vec2(id, 1.7)) * 0.6 + n1 * 0.6 - 0.1));
	c *= 1.0 + (id - 0.5) * vary * 2.0;
	c *= mix(1.0, 0.5 + gl * 1.35, grain);
	c *= COLOR.rgb;
	// a stone fallen out of the face here and there: a dark hole
	c *= 1.0 - step(id, 0.03) * (pave ? 0.0 : 0.55);
	// arrises lighter and chipped, joints dark and recessed
	float edge = 1.0 - smoothstep(0.0, bv, d - mo);
	float chip = smoothstep(0.45, 0.72, n3);
	c = mix(c, c * 1.18 + 0.015, edge * (0.35 + 0.65 * chip) * 0.45);
	float joint = 1.0 - smoothstep(mo * 0.6, mo * 1.5, d - chip * mo * 0.8);
	float grassy = smoothstep(0.42, 0.68, n2) * moss_amt;
	vec3 jcol = mix(c * 0.5 + vec3(0.02), moss * 0.75, grassy * (pave ? 1.0 : 0.5));
	c = mix(c, jcol, joint * (pave ? 1.0 : 0.8));
	// age: broad stains and blackening that do not follow the blocks
	float stain = texture(noise_tex, vec2(p.x * 0.045, p.y * 0.06) + vec2(0.17, 0.41)).r;
	float stain2 = texture(noise_tex, wpos.xz * 0.05 + vec2(wpos.y * 0.03, 0.73)).r;
	c *= mix(1.0, 0.55, smoothstep(0.4, 0.75, stain));
	c *= mix(1.0, 0.75, smoothstep(0.5, 0.8, stain2));
	float rough = mix(0.88, 0.97, joint);
	float wetness = 0.0;
	vec3 tilt3 = vec3(0.0);

	if (pave) {
		// trodden-in dirt in broad patches, darker toward the edges of the yard
		float grime = smoothstep(0.4, 0.75, n1 * 0.7 + stain * 0.5);
		c = mix(c, dirt * (0.9 + 0.5 * gl), grime * 0.6);
		c *= 0.9 + 0.2 * h21(vec2(id, 9.3));
		// a stone gone: earth and moss where it was
		float gone = step(id, 0.045);
		vec3 earth = dirt * (0.8 + 0.6 * gl) * mix(vec3(1.0), moss * 3.2, smoothstep(0.4, 0.7, n3));
		c = mix(c, earth, gone);
		rough = mix(rough, 1.0, gone);
		// cracked stones
		float cracked = step(0.045, id) * step(id, 0.14);
		float crack = 1.0 - smoothstep(0.0, 0.025, abs(texture(noise_tex, p * 0.8 + id * 5.0).r - 0.5));
		c *= 1.0 - cracked * crack * 0.7;
		// the walked way: smoother and paler, less moss in its joints
		float worn = 1.0 - smoothstep(0.8, 3.0, abs(wpos.x - rt.b));
		c = mix(c, c * 1.1 + 0.02, worn * 0.5 * (1.0 - joint));
		rough -= worn * 0.1;
		// standing water in the hollows
		float pv = n1 * 0.55 + texture(noise_tex, wpos.xz * 0.083 + vec2(0.2, 0.9)).r * 0.6 - worn * 0.1;
		float pud = smoothstep(0.66, 0.69, pv);
		float damp = smoothstep(0.58, 0.68, pv);
		wetness = max(wetness, pud);
		c *= mix(1.0, 0.62, damp);
		c = mix(c, c * 0.45, pud);
		rough = mix(rough, 0.6, damp);
		rough = mix(rough, 0.38, pud);
	} else {
		// rain streaks down upright faces
		float st = texture(noise_tex, vec2(p.x * 0.33, wpos.y * 0.012)).r;
		float upright = 1.0 - abs(n.y);
		c *= 1.0 - upright * smoothstep(0.5, 0.8, st) * 0.34;
	}
	// the foot of a wall: earth splashed up, damp, moss
	float above = wpos.y - rt.r;
	float foot = (1.0 - smoothstep(0.0, dirt_h, above + (n2 - 0.5) * dirt_h * 0.9)) * smoothstep(-3.0, -0.6, above) * (pave ? 0.0 : 1.0);
	c = mix(c, dirt * (0.7 + 0.6 * n2), foot * 0.85);
	float mup = smoothstep(0.5, 0.86, n.y + (n2 - 0.5) * 0.7) * smoothstep(0.38, 0.62, n1 + 0.12) * (pave ? 0.25 : 1.0);
	float mlow = foot * smoothstep(0.52, 0.72, n1);
	c = mix(c, moss * (0.6 + 0.8 * n3), clamp((mup * 0.9 + mlow * 0.6) * moss_amt, 0.0, 1.0));
	// spray and damp toward the sea cliff
	float sea = smoothstep(rt.g - 16.0, rt.g - 2.0, wpos.x) * (1.0 - smoothstep(sea_level + 30.0, sea_level + 55.0, wpos.y));
	float wet = clamp(sea + foot * 0.3, 0.0, 1.0);
	c *= mix(1.0, 0.62, wet);
	rough = mix(rough, 0.5, wet * 0.6);
	// the makers' ceramic, far out
	float fut = step(future_x, wpos.x);
	c = mix(c, future_tint * (0.85 + 0.3 * n1), fut);
	rough = mix(rough, 0.6, fut);

	// normal: the block's bevel, its uneven face, its grain; flat where water stands
	vec2 dir = vec2(b.x < 0.5 ? -1.0 : 1.0, b.y < 0.5 ? -1.0 : 1.0);
	vec2 tilt = dir * (vec2(1.0) - smoothstep(vec2(0.0), vec2(bv), near - vec2(mo))) * 0.55;
	tilt += (vec2(n3, texture(noise_tex, p * 0.41 + vec2(id * 0.53, 0.5)).r) - 0.5) * 0.22;
	tilt += gn.xy * 0.4;
	tilt *= (1.0 - fut) * (1.0 - wetness);
	vec3 wn = normalize(n + s * tilt.x + t * tilt.y);
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
	ALBEDO = clamp(c, vec3(0.0), vec3(1.0));
	ROUGHNESS = clamp(rough, 0.04, 1.0);
	SPECULAR = mix(0.35, 0.15, wetness);
	METALLIC = 0.0;
}
