shader_type spatial;
// A layer of cloud that moves: a very large sheet bowed down toward the horizon so it reads as a sky, not a ceiling.
// Three noise samples: two for the shape, one a step toward the sun to tell the lit edge from the dark belly.
// Two of these are stacked (a low broken deck and high streaks), drifting at different speeds.
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled, shadows_disabled;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float cover = 0.48;
uniform vec3 lit : source_color = vec3(1.0, 0.95, 0.85);
uniform vec3 dark : source_color = vec3(0.5, 0.5, 0.58);
uniform vec3 haze : source_color = vec3(0.9, 0.8, 0.6);
uniform vec3 sun_col : source_color = vec3(1.0, 0.8, 0.5);
uniform vec2 wind = vec2(0.86, 0.5);
uniform vec3 sun_dir = vec3(0.6, 0.25, -0.6);
uniform float scale = 0.00042;
uniform vec2 stretch = vec2(1.0, 1.0);
uniform float speed = 1.0;
uniform float bow = 0.000028;      // how far the sheet drops with distance
uniform float density = 0.9;

varying vec3 wpos;
varying vec2 flat_xz;

void vertex() {
	vec4 w = MODEL_MATRIX * vec4(VERTEX, 1.0);
	flat_xz = w.xz;
	vec2 d = w.xz - CAMERA_POSITION_WORLD.xz;
	float drop = dot(d, d) * bow;
	wpos = w.xyz - vec3(0.0, drop, 0.0);
	VERTEX.y -= drop;
}

float shape(vec2 p) {
	return texture(noise_tex, p).r * 0.6 + texture(noise_tex, p * 2.7 + vec2(0.3, 0.6) + TIME * wind * 0.0016 * speed).r * 0.4;
}

void fragment() {
	vec2 p = flat_xz * scale * stretch + TIME * wind * 0.0035 * speed;
	float n = shape(p);
	float a = smoothstep(cover, cover + 0.17, n);
	// a step toward the sun: thinner there means this side is the lit one
	float toward = texture(noise_tex, p + normalize(sun_dir.xz + vec2(0.0001)) * 0.035 * stretch).r * 0.6 + n * 0.4;
	float thick = smoothstep(cover, cover + 0.34, n);
	float light = clamp(0.55 + (n - toward) * 5.0 - thick * 0.55, 0.0, 1.0);
	vec3 v = normalize(wpos - CAMERA_POSITION_WORLD);
	float near_sun = pow(max(dot(v, normalize(sun_dir)), 0.0), 6.0);
	vec3 c = mix(dark, lit, light);
	// the thin edge of a cloud near the sun burns
	c += sun_col * near_sun * (1.0 - thick) * 0.9;
	float d = length(flat_xz - CAMERA_POSITION_WORLD.xz);
	float far = smoothstep(700.0, 3400.0, d);
	ALBEDO = mix(c, haze, far * 0.85);
	ALPHA = a * density * (1.0 - smoothstep(2900.0, 4300.0, d));
}
