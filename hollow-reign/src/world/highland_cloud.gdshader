shader_type spatial;
// A deck of cloud that moves: one very large plane high over the headland, two noise samples, no lighting.
// It thins into the horizon's own colour with distance so its edge is never seen.
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled, shadows_disabled;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float cover = 0.48;
uniform vec3 lit : source_color = vec3(1.0, 0.95, 0.85);
uniform vec3 dark : source_color = vec3(0.5, 0.5, 0.58);
uniform vec3 haze : source_color = vec3(0.9, 0.8, 0.6);
uniform vec2 wind = vec2(0.86, 0.5);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz * 0.00042 + TIME * wind * 0.0035;
	float n = texture(noise_tex, p).r * 0.62 + texture(noise_tex, p * 2.9 + vec2(0.3, 0.6) + TIME * wind * 0.002).r * 0.38;
	float a = smoothstep(cover, cover + 0.16, n);
	float d = length(wpos.xz - CAMERA_POSITION_WORLD.xz);
	float far = smoothstep(900.0, 3600.0, d);
	ALBEDO = mix(mix(dark, lit, smoothstep(cover + 0.02, cover + 0.3, n)), haze, far * 0.8);
	ALPHA = a * 0.9 * (1.0 - smoothstep(2600.0, 4300.0, d));
}
