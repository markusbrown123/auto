shader_type spatial;
// What the far-future kit builds in code (src/world/future.gd): ceramic plate and brushed alloy, laid in panels, and
// old. The panel sheet (plates of slightly different tone with a groove between them) is laid on in world space from
// three sides, so every wall, rib and tower in an arena shares one sheet and nothing needs UVs. Age is added here:
// rain streaks down upright faces, stains in large patches, what the region leaves at a thing's foot (moss, ash,
// rime) and snow on faces turned up. Six panel reads and two of noise.
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D panel_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D panel_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 tint : source_color = vec3(0.7, 0.71, 0.69);
uniform float metal = 0.12;
uniform float rough = 0.6;
uniform float scale = 0.16;                     // panel sheets a metre
uniform vec3 grime : source_color = vec3(0.2, 0.25, 0.12);
uniform float grime_h = 1.4;                    // how far up from the ground the region's grime climbs
uniform float streak = 0.5;
uniform float snow = 0.0;

varying vec3 tp;
varying vec3 tw;
varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	vec3 normal = MODEL_NORMAL_MATRIX * NORMAL;
	TANGENT = vec3(0.0, 0.0, -1.0) * abs(normal.x);
	TANGENT += vec3(1.0, 0.0, 0.0) * abs(normal.y);
	TANGENT += vec3(1.0, 0.0, 0.0) * abs(normal.z);
	TANGENT = inverse(MODEL_NORMAL_MATRIX) * normalize(TANGENT);
	BINORMAL = vec3(0.0, 1.0, 0.0) * abs(normal.x);
	BINORMAL += vec3(0.0, 0.0, -1.0) * abs(normal.y);
	BINORMAL += vec3(0.0, 1.0, 0.0) * abs(normal.z);
	BINORMAL = inverse(MODEL_NORMAL_MATRIX) * normalize(BINORMAL);
	tw = pow(abs(normal), vec3(4.0));
	tw /= dot(tw, vec3(1.0));
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize(normal);
	tp = wpos * scale * vec3(1.0, -1.0, 1.0);
}

vec4 tri(sampler2D s) {
	return texture(s, tp.xy) * tw.z + texture(s, tp.xz) * tw.y + texture(s, tp.zy * vec2(-1.0, 1.0)) * tw.x;
}

void fragment() {
	vec3 pt = tri(panel_tex).rgb;
	// across an upright face, whichever way it is turned
	float side = wpos.x * tw.z + wpos.z * tw.x + wpos.x * tw.y;
	float up = wpos.y * (1.0 - tw.y) + wpos.z * tw.y;
	float n = texture(noise_tex, vec2(side, up) * 0.055 + vec2(0.3, 0.1)).r;
	float st = texture(noise_tex, vec2(side * 0.42, up * 0.018)).r;
	float upright = 1.0 - tw.y;
	vec3 c = tint * pt * (0.8 + 0.4 * n);
	// rain streaks, and broad stains
	c *= 1.0 - streak * upright * smoothstep(0.5, 0.78, st) * 0.55;
	c *= mix(0.78, 1.0, smoothstep(0.35, 0.6, n));
	// what gathers at its foot
	float foot = (1.0 - smoothstep(0.0, grime_h, wpos.y + (n - 0.5) * grime_h * 1.4)) * smoothstep(0.25, 0.6, st + n * 0.5);
	c = mix(c, grime * (0.6 + 0.8 * n), foot * 0.8);
	float sn = snow * smoothstep(0.35, 0.75, wnrm.y + (n - 0.5) * 0.3);
	c = mix(c, vec3(0.82, 0.87, 0.94), sn);
	ALBEDO = c;
	ROUGHNESS = mix(mix(rough, 0.95, foot), 0.85, sn);
	METALLIC = metal * (1.0 - foot) * (1.0 - sn);
	SPECULAR = 0.4;
	NORMAL_MAP = tri(panel_n).rgb;
	NORMAL_MAP_DEPTH = 0.8 * (1.0 - sn * 0.7);
}
