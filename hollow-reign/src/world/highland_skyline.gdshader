shader_type spatial;
// Light in the sky that is not weather: the orbital ring's arc, aurora curtains, the trails of what is falling from
// it, and stars. Ribbons and small cards, added over the sky. Vertex colour is the tint and (alpha) the strength.
// UV.x runs across a ribbon, UV.y along it. UV2.x chooses the kind: 0 a soft ribbon, 1 the built arc (plates and
// gaps), 2 a curtain that hangs from its top edge, 3 a point.
render_mode unshaded, blend_add, depth_draw_never, fog_disabled, shadows_disabled, cull_disabled;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float strength = 1.0;
uniform vec3 wake : source_color = vec3(0.0);     // added to the built arc when it is lit (generation III)

void fragment() {
	float kind = UV2.x;
	float across = sin(clamp(UV.x, 0.0, 1.0) * PI);
	float a = across * across;
	vec3 c = COLOR.rgb;
	if (kind > 2.5) {
		vec2 d = UV * 2.0 - 1.0;
		a = pow(max(1.0 - length(d), 0.0), 2.5) * (0.75 + 0.25 * sin(TIME * (1.0 + UV2.y * 3.0) + UV2.y * 40.0));
	} else if (kind > 1.5) {
		float fold = texture(noise_tex, vec2(UV.y * 3.0 + TIME * 0.004, 0.3)).r;
		float rays = texture(noise_tex, vec2(UV.y * 22.0 - TIME * 0.01, 0.7)).r;
		a = pow(1.0 - UV.x, 1.6) * smoothstep(0.0, 0.08, UV.x) * smoothstep(0.3, 0.7, fold) * (0.45 + 0.9 * rays) * sin(UV.y * PI);
	} else if (kind > 0.5) {
		float plate = floor(UV.y * 260.0);
		float h = fract(sin(plate * 12.9898) * 43758.5453);
		float gap = step(0.08, fract(UV.y * 260.0)) * step(0.16, h);
		a = pow(across, 3.0) * gap * (0.45 + 0.55 * h);
		c += wake * step(0.72, h);
	} else {
		a *= sin(UV.y * PI);
	}
	ALBEDO = c;
	ALPHA = clamp(a * COLOR.a * strength, 0.0, 1.0);
}
