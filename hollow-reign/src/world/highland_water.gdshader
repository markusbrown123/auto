shader_type spatial;
// Water laid on the ground in a ribbon (HighlandSights): the stream that crosses the road and the fall that takes it over
// the cliff. COLOR.r is how steep the ground is there: flat water is dark and slow with a few lines on it, steep water is
// fast and white. UV.x is across the ribbon, UV.y metres along it. `freeze` turns it to ice (the third generation's winter).
render_mode diffuse_lambert, specular_disabled, shadows_disabled, cull_disabled;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 deep : source_color = vec3(0.1, 0.27, 0.33);
uniform vec3 foam : source_color = vec3(0.93, 0.97, 1.0);
uniform vec3 sun_dir = vec3(0.6, 0.25, -0.6);
uniform vec3 haze : source_color = vec3(0.8, 0.75, 0.7);
uniform float freeze = 0.0;

void fragment() {
	float steep = COLOR.r;
	float speed = 0.5 + steep * 4.5;
	float n = texture(noise_tex, vec2(UV.x * 0.55, UV.y * 0.06 - TIME * speed * 0.05)).r;
	float n2 = texture(noise_tex, vec2(UV.x * 1.4 + 0.3, UV.y * 0.17 - TIME * speed * 0.13)).r;
	float across = smoothstep(0.0, 0.2, UV.x) * smoothstep(1.0, 0.8, UV.x);
	float f = clamp(steep * 1.25 + n * n2 * 1.5 - 0.25 + (1.0 - across) * 0.5, 0.0, 1.0);
	vec3 c = mix(deep * (0.8 + 0.4 * n2), foam, f);
	c = mix(c, vec3(0.78, 0.88, 0.95), freeze);
	ALBEDO = c;
	EMISSION = c * (0.18 + steep * 0.22);
	ALPHA = clamp(across * mix(0.78, 0.96, steep) + freeze * 0.2, 0.0, 1.0);
}
