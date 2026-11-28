shader_type spatial;
// Dust hanging in a lamp's beam (src/world/chamber.gd). One card along the node's own Y axis (its foot at the node,
// `length` along +Y... drawn downward by turning the node), turned about that axis to face the lens, widening from
// `top_w` to `bottom_w`. Added over the picture, faint, and it drifts. No depth writes, no fog, no shadows.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled, skip_vertex_transform;

uniform vec3 tint : source_color = vec3(1.0, 0.86, 0.66);
uniform float strength = 0.12;
uniform float top_w = 0.5;
uniform float bottom_w = 1.6;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

varying vec3 wp;
varying float near_fade;

void vertex() {
	vec3 foot = MODEL_MATRIX[3].xyz;
	vec3 axis = MODEL_MATRIX[1].xyz;               // length included
	float t = VERTEX.y + 0.5;                       // 0 at the lamp, 1 at the far end
	vec3 p = foot + axis * t;
	vec3 to_cam = normalize(CAMERA_POSITION_WORLD - p);
	vec3 side = normalize(cross(normalize(axis), to_cam));
	p += side * VERTEX.x * mix(top_w, bottom_w, t);
	wp = p;
	// seen from inside or right beside the beam a card would fill the frame: it fades out within 1.6 m of the axis
	vec3 ax = normalize(axis);
	vec3 rel = CAMERA_POSITION_WORLD - foot;
	float off_axis = length(rel - ax * clamp(dot(rel, ax), 0.0, length(axis)));
	near_fade = smoothstep(0.9, 2.0, off_axis);
	VERTEX = (VIEW_MATRIX * vec4(p, 1.0)).xyz;
}

void fragment() {
	float across = sin(UV.x * PI);
	float along = smoothstep(0.0, 0.15, UV.y) * (1.0 - smoothstep(0.55, 1.0, UV.y));
	float motes = texture(noise_tex, vec2(wp.x * 0.35 + TIME * 0.006, wp.y * 0.2 - TIME * 0.01)).r;
	ALBEDO = tint;
	ALPHA = across * across * along * strength * (0.6 + 0.8 * motes) * near_fade;
}
