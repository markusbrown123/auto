shader_type spatial;
// Light coming down through the cloud: long soft cards laid along the sun's own direction, turned to the lens,
// added over the picture. Strongest looking toward the sun, and they breathe.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled, skip_vertex_transform;

uniform vec3 sun_dir = vec3(0.6, 0.25, -0.6);
uniform vec3 tint : source_color = vec3(1.0, 0.85, 0.6);
uniform float strength = 0.25;

varying float breathe;
varying float facing;

void vertex() {
	vec3 foot = MODEL_MATRIX[3].xyz;
	float len = length(MODEL_MATRIX[1].xyz);
	float wid = length(MODEL_MATRIX[0].xyz);
	vec3 s = normalize(sun_dir);
	vec3 p = foot + s * (VERTEX.y * len);
	vec3 to_cam = normalize(CAMERA_POSITION_WORLD - p);
	vec3 side = normalize(cross(s, to_cam));
	p += side * VERTEX.x * wid * (0.55 + 0.9 * VERTEX.y);
	breathe = 0.7 + 0.3 * sin(TIME * 0.23 + foot.x * 0.05 + foot.z * 0.03);
	facing = 0.25 + 0.75 * pow(max(dot(-to_cam, s), 0.0), 2.0);
	VERTEX = (VIEW_MATRIX * vec4(p, 1.0)).xyz;
}

void fragment() {
	float across = sin(UV.x * PI);
	float along = smoothstep(0.0, 0.12, UV.y) * (1.0 - smoothstep(0.35, 1.0, UV.y));
	ALBEDO = tint;
	ALPHA = across * across * along * strength * breathe * facing;
}
