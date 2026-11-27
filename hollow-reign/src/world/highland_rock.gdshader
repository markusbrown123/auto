shader_type spatial;
// The crags: faceted rock in MultiMeshes, banded like the cliffs, with turf (or snow) lying on whatever faces up.
render_mode diffuse_lambert, specular_disabled;

#include "highland_common.gdshaderinc"

uniform sampler2D rock_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 grass_a : source_color = vec3(0.3, 0.4, 0.15);
uniform vec3 grass_b : source_color = vec3(0.55, 0.52, 0.22);
uniform vec3 rock_a : source_color = vec3(0.2, 0.19, 0.18);
uniform vec3 rock_b : source_color = vec3(0.52, 0.48, 0.42);
uniform float sea_level = -76.0;

varying vec3 wpos;
varying vec3 wnrm;
varying float lit;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float n2 = texture(noise_tex, wpos.xz * 0.045 + vec2(0.37, 0.11)).r;
	float n3 = texture(noise_tex, wpos.xz * 0.61 + wpos.y * 0.3).r;
	vec3 bw = wnrm * wnrm;
	float l = dot(vec3(0.35, 0.5, 0.15), texture(rock_tex, wpos.xy * 0.11).rgb * bw.z + texture(rock_tex, wpos.zy * 0.11).rgb * bw.x + texture(rock_tex, wpos.xz * 0.11).rgb * bw.y);
	float bed = wpos.y * 0.9 + n2 * 3.0;
	float strata = smoothstep(0.2, 0.8, fract(bed)) * (1.0 - smoothstep(0.86, 1.0, fract(bed)));
	vec3 c = mix(rock_a, rock_b, clamp(l * 1.7 - 0.12 + (strata - 0.5) * 0.24 + (n3 - 0.5) * 0.2, 0.0, 1.0)) * (0.8 + 0.4 * n2);
	c *= mix(0.45, 1.0, smoothstep(sea_level + 1.0, sea_level + 9.0, wpos.y));
	float top = smoothstep(0.62, 0.86, wnrm.y + (n3 - 0.5) * 0.3);
	c = mix(c, mix(grass_a, grass_b, n2) * (0.5 + 0.5 * n3), top * 0.85 * (1.0 - snow));
	c = mix(c, vec3(0.82, 0.86, 0.93), snow * smoothstep(0.35, 0.7, wnrm.y + (n3 - 0.5) * 0.3));
	ALBEDO = c;
	ROUGHNESS = 1.0;
	lit = land_shade(wpos + vec3(0.0, 2.0, 0.0)) * cloud_shade(wpos.xz);
}

void light() {
	float s = LIGHT_IS_DIRECTIONAL ? lit : 1.0;
	DIFFUSE_LIGHT += max(dot(NORMAL, LIGHT), 0.0) * ATTENUATION * LIGHT_COLOR * s / PI;
}
