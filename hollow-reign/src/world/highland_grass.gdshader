shader_type spatial;
// Highland turf: crossed cards in MultiMeshes. The wind is two travelling waves, so gusts can be seen crossing
// the slope; the cards lean with it and catch the light as they do. Far cards shrink into the ground instead of
// popping. Lit with the ground's own normal, so a card never shows a dark back.
// Instance colour: a = 1 heather (rgb its colour); a = 0 turf (r chooses between the two turf tones).
render_mode cull_disabled, depth_draw_opaque, diffuse_lambert, specular_disabled, world_vertex_coords;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 grass_a : source_color = vec3(0.3, 0.4, 0.15);
uniform vec3 grass_b : source_color = vec3(0.55, 0.52, 0.22);
uniform vec3 heather : source_color = vec3(0.45, 0.28, 0.45);
uniform float heather_amt = 1.0;
uniform float snow = 0.0;
uniform float dry = 0.0;
uniform vec2 wind = vec2(0.86, 0.5);
uniform float fade_near = 170.0;
uniform float fade_far = 290.0;

varying vec3 tint;
varying float gust;

void vertex() {
	float h = 1.0 - UV.y;
	vec3 root = MODEL_MATRIX[3].xyz;
	float force = length(wind);
	vec2 dir = wind / max(force, 0.001);
	float along = dot(root.xz, dir);
	float across = dot(root.xz, vec2(-dir.y, dir.x));
	float g = 0.5 + 0.5 * sin(along * 0.085 - TIME * 1.5 * force + sin(across * 0.05) * 1.8);
	g *= 0.6 + 0.4 * sin(along * 0.023 - TIME * 0.5 * force + 1.3);
	float flutter = sin(TIME * 5.0 + root.x * 1.3 + root.z * 1.7) * 0.03;
	float bend = (0.07 + 0.3 * g) * force + flutter;
	VERTEX.xz += dir * bend * h;
	VERTEX.y -= bend * bend * 0.6 * h;
	float dist = distance(CAMERA_POSITION_WORLD, root);
	// far cards sink into the ground; a card the lens is about to pass through gets out of its way
	float k = (1.0 - smoothstep(fade_near, fade_far, dist)) * smoothstep(0.5, 2.4, dist);
	VERTEX = mix(root, VERTEX, k);
	NORMAL = vec3(0.0, 1.0, 0.0);
	gust = g * h;
	vec3 turf = mix(grass_a, grass_b, COLOR.r);
	turf = mix(turf, vec3(0.62, 0.5, 0.26), dry * 0.45 * COLOR.r);
	tint = mix(turf, mix(turf, heather, heather_amt), COLOR.a);
}

void fragment() {
	vec4 a = texture(albedo_tex, UV);
	vec3 c = tint * (0.5 + 1.15 * a.r) * (0.9 + 0.45 * gust);
	c = mix(c, vec3(0.88, 0.9, 0.94), snow * 0.8 * smoothstep(0.35, 0.9, 1.0 - UV.y));
	ALBEDO = c;
	ALPHA = a.a;
	ALPHA_SCISSOR_THRESHOLD = 0.35;
	ROUGHNESS = 1.0;
}
