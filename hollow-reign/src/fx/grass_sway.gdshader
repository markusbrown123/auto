shader_type spatial;
// Grass tufts (crossed alpha-cut quads in a MultiMesh) with a gentle wind sway.
// Cost: one texture sample, two sines per vertex (4 vertices per quad). Mobile-safe.
render_mode cull_disabled, depth_draw_opaque, diffuse_lambert, specular_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float sway = 0.05;
uniform float speed = 1.4;

void vertex() {
	// the top of the quad (UV.y = 0) moves, the root stays planted
	float h = 1.0 - UV.y;
	vec3 w = MODEL_MATRIX[3].xyz;
	float t = TIME * speed + w.x * 0.7 + w.z * 0.9;
	VERTEX.x += (sin(t) + 0.5 * sin(t * 2.3 + 1.7)) * sway * h;
	VERTEX.z += cos(t * 0.8) * sway * 0.5 * h;
}

void fragment() {
	vec4 a = texture(albedo_tex, UV);
	ALBEDO = a.rgb;
	ALPHA = a.a;
	ALPHA_SCISSOR_THRESHOLD = 0.35;
	ROUGHNESS = 1.0;
}
