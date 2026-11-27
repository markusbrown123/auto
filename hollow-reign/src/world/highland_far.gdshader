shader_type spatial;
// The far country: ranges of hills one behind another. Each is lit on its sunward faces, rimmed at its crest and
// thinned toward the colour of the air by how far off it stands (vertex alpha), and all of them stand in sea haze.
render_mode unshaded, fog_disabled, shadows_disabled, cull_disabled;

uniform vec3 lit : source_color = vec3(0.6, 0.55, 0.45);
uniform vec3 shade : source_color = vec3(0.2, 0.24, 0.32);
uniform vec3 haze : source_color = vec3(0.8, 0.75, 0.7);
uniform vec3 rim : source_color = vec3(1.0, 0.85, 0.6);
uniform vec3 sun_dir = vec3(0.6, 0.25, -0.6);
uniform float snow = 0.0;

varying vec3 wn;

void vertex() {
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float l = 0.75 * smoothstep(-0.1, 0.7, dot(normalize(wn), normalize(sun_dir)));
	vec3 base = mix(shade, lit, l);
	base = mix(base, vec3(0.86, 0.89, 0.94) * (0.55 + 0.45 * l), max(snow, smoothstep(0.72, 0.96, UV.y) * COLOR.g * 0.4) * 0.8);
	base += rim * pow(UV.y, 7.0) * 0.35 * (0.3 + 0.7 * l);
	float air = COLOR.a + (1.0 - COLOR.a) * 0.75 * (1.0 - smoothstep(0.0, 0.42, UV.y));
	ALBEDO = mix(base, haze, air);
}
