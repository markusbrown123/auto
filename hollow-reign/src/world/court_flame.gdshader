shader_type spatial;
// Fire in the Courtyard's braziers and candles (src/world/court_dress.gd, Future._court_brazier): crossed cards,
// additive, the flame's shape licking up through scrolling noise, white-gold at its root to red at its tips.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 hot : source_color = vec3(1.0, 0.86, 0.55);
uniform vec3 cool : source_color = vec3(0.9, 0.3, 0.06);
uniform float energy = 1.6;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = vec2(UV.x, 1.0 - UV.y);          // y up from the root
	vec2 cell = floor(wpos.xz / 3.0);
	float ph = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453) * 7.0;   // each fire its own
	float n = texture(noise_tex, vec2(uv.x * 0.9 + ph, uv.y * 0.7 - TIME * 0.9)).r;
	float n2 = texture(noise_tex, vec2(uv.x * 2.1 - ph, uv.y * 1.6 - TIME * 1.7)).r;
	float x = (uv.x - 0.5 + (n - 0.5) * 0.35 * uv.y) * 2.0;
	float width = (1.0 - uv.y) * (0.75 + 0.25 * n2);
	float shape = (1.0 - smoothstep(width * 0.55, width, abs(x))) * smoothstep(0.0, 0.08, uv.y);
	float body = shape * smoothstep(1.0, 0.25, uv.y + (n2 - 0.5) * 0.5);
	vec3 c = mix(hot, cool, smoothstep(0.1, 0.8, uv.y + (n - 0.5) * 0.3));
	ALBEDO = c * body * energy;
	ALPHA = body;
}
