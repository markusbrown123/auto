shader_type spatial;
// The world this one turns round, low over the sea haze: a pale banded disc, lit from the sun's side and gone into the
// sky's own colour on the other. Drawn on a card a long way off, behind the hills and under the cloud.
render_mode unshaded, blend_mix, depth_draw_never, fog_disabled, shadows_disabled, cull_disabled;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 lit : source_color = vec3(0.95, 0.9, 0.82);
uniform vec3 band : source_color = vec3(0.75, 0.62, 0.55);
uniform vec3 light = vec3(0.6, 0.3, 0.5);     // the sun, in the card's own axes (x right, y up, z toward the viewer)
uniform float strength = 0.85;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	p.y = -p.y;
	float r = length(p);
	vec3 n = vec3(p, sqrt(max(1.0 - r * r, 0.0)));
	float day = smoothstep(-0.12, 0.45, dot(n, normalize(light)));
	float swirl = texture(noise_tex, vec2(p.x * 0.12 + n.z * 0.05, p.y * 0.55 + 0.3)).r;
	float bands = 0.5 + 0.5 * sin(p.y * 13.0 + swirl * 7.0);
	vec3 c = mix(lit, band, clamp(bands * 0.7 + (swirl - 0.5) * 0.5, 0.0, 1.0));
	// a thin bright limb, as an atmosphere has
	c += lit * pow(r, 6.0) * 0.25;
	ALBEDO = c;
	ALPHA = (1.0 - smoothstep(0.985, 1.0, r)) * mix(0.1, 1.0, day) * strength;
}
