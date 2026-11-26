shader_type spatial;
// The headland's ground: turf in two tones, heather in patches, bare rock where it is steep, and the worn
// road read from a mask. Cloud shadow drifts over it. Three noise samples and one mask sample; no normal map.
render_mode diffuse_lambert, specular_disabled;

uniform sampler2D path_mask : filter_linear, repeat_disable;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec4 mask_rect;
uniform vec3 grass_a : source_color = vec3(0.3, 0.4, 0.15);
uniform vec3 grass_b : source_color = vec3(0.55, 0.52, 0.22);
uniform vec3 heather : source_color = vec3(0.45, 0.28, 0.45);
uniform float heather_amt = 1.0;
uniform float snow = 0.0;
uniform vec2 wind = vec2(0.86, 0.5);

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = NORMAL;
}

void fragment() {
	float n1 = texture(noise_tex, wpos.xz * 0.013).r;
	float n2 = texture(noise_tex, wpos.xz * 0.11 + vec2(0.37, 0.11)).r;
	float n3 = texture(noise_tex, wpos.xz * 0.7).r;
	vec3 g = mix(grass_a, grass_b, smoothstep(0.38, 0.62, n1 * 0.55 + n2 * 0.45));
	float hp = texture(noise_tex, wpos.xz * 0.031 + vec2(0.7, 0.2)).r;
	g = mix(g, heather, smoothstep(0.57, 0.63, hp * 0.5 + n2 * 0.5) * heather_amt * 0.8);
	g *= 0.62 + 0.76 * n3;
	float steep = smoothstep(0.9, 0.74, wnrm.y);
	vec3 rock = vec3(0.42, 0.4, 0.37) * (0.6 + 0.8 * n2);
	vec3 c = mix(g, rock, steep);
	vec2 muv = (wpos.xz - mask_rect.xy) * mask_rect.zw;
	float pm = texture(path_mask, muv).r;
	pm = smoothstep(0.3, 0.62, pm + (n3 - 0.5) * 0.5 + (n2 - 0.5) * 0.3);
	// the road: pale worn stone, with earth showing between the setts
	vec3 road = mix(vec3(0.3, 0.25, 0.18), vec3(0.5, 0.47, 0.41), smoothstep(0.44, 0.54, n3)) * (0.7 + 0.6 * n2);
	c = mix(c, road, pm);
	c = mix(c, vec3(0.86, 0.88, 0.93), snow * smoothstep(0.45, 0.75, wnrm.y * 0.55 + n2 * 0.55) * (1.0 - pm * 0.45));
	float cl = texture(noise_tex, wpos.xz * 0.0028 + TIME * wind * 0.006).r;
	c *= 1.0 - 0.42 * smoothstep(0.5, 0.66, cl);
	ALBEDO = c;
	ROUGHNESS = 1.0;
}
