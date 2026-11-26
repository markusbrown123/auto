shader_type spatial;
// The sea under the headland: dark and deep, paler over the shelf at the cliff's foot, with a surf line that
// breaks along the shore (read from the land's own height field) and a path of light toward the sun.
render_mode diffuse_lambert, specular_disabled, shadows_disabled;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D height_tex : filter_linear, repeat_disable;
uniform vec4 land_rect;
uniform float sea_level = -76.0;
uniform vec3 deep : source_color = vec3(0.05, 0.12, 0.16);
uniform vec3 shelf : source_color = vec3(0.12, 0.3, 0.32);
uniform vec3 foam : source_color = vec3(0.9, 0.93, 0.95);
uniform vec3 haze : source_color = vec3(0.8, 0.75, 0.7);
uniform vec3 glint : source_color = vec3(1.0, 0.85, 0.6);
uniform vec3 sun_dir = vec3(0.6, 0.25, -0.6);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = (wpos.xz - land_rect.xy) * land_rect.zw;
	float h = texture(height_tex, clamp(uv, vec2(0.0), vec2(1.0))).r;
	float depth = sea_level - h;
	float n = texture(noise_tex, wpos.xz * 0.02 + TIME * vec2(0.004, 0.007)).r;
	float n2 = texture(noise_tex, wpos.xz * 0.13 - TIME * vec2(0.011, 0.006)).r;
	float shore = 1.0 - smoothstep(0.0, 6.5, depth);
	float wave = 0.5 + 0.5 * sin(depth * 1.5 + TIME * 0.9 + n * 9.0);
	float surf = shore * smoothstep(0.55, 0.95, wave * 0.6 + n2 * 0.6) + smoothstep(1.6, 0.2, depth);
	vec3 c = mix(deep, shelf, shore * 0.7 + (n - 0.5) * 0.25);
	c *= 0.85 + 0.3 * n2;
	c = mix(c, foam, clamp(surf, 0.0, 1.0) * 0.92);
	// the light on the water toward the sun, broken by the swell
	vec3 v = normalize(wpos - CAMERA_POSITION_WORLD);
	vec3 r = reflect(v, normalize(vec3((n2 - 0.5) * 0.5, 1.0, (n - 0.5) * 0.5)));
	float g = pow(max(dot(r, normalize(sun_dir)), 0.0), 26.0);
	float d = length(wpos.xz - CAMERA_POSITION_WORLD.xz);
	EMISSION = glint * g * 1.3;
	ALBEDO = mix(c, haze, smoothstep(500.0, 2600.0, d) * 0.9);
	ROUGHNESS = 1.0;
}
