shader_type spatial;
// Highland turf and heath: clumps of crossed cards in MultiMeshes. Gusts are fronts in a scrolling noise, so they
// can be seen crossing the hill; a clump leans with the gust and catches the light as it does. Roots are dark, tips
// pale; far clumps sink into ground of their own colour. Lit with the ground's normal, the land's baked shadow,
// the Ring-Gate's shadow and the cloud's, and glows a little when the sun is behind it.
// Instance colour: r picks between the two turf tones, g is how dry this clump is, b its own brightness.
// Each clump's own up axis is its ground's normal.
render_mode cull_disabled, depth_draw_opaque, diffuse_lambert, specular_disabled, world_vertex_coords;

#include "highland_common.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 grass_a : source_color = vec3(0.3, 0.4, 0.15);
uniform vec3 grass_b : source_color = vec3(0.55, 0.52, 0.22);
uniform vec3 heather : source_color = vec3(0.45, 0.28, 0.45);
uniform vec3 straw : source_color = vec3(0.62, 0.5, 0.26);
uniform float heather_amt = 1.0;
uniform float dry = 0.0;
uniform float heath = 0.0;         // 1: this material is the heather and gorse, not the grass
uniform float fade_near = 100.0;
uniform float fade_far = 138.0;
uniform float stiff = 1.0;

varying vec3 tint;
varying vec3 bloom;
varying float gust;
varying float lit;
varying vec3 rootp;
varying float cdist;

void vertex() {
	float h = 1.0 - UV.y;
	vec3 root = MODEL_MATRIX[3].xyz;
	float force = length(wind);
	vec2 dir = wind / max(force, 0.001);
	float front = texture(noise_tex, root.xz * 0.0075 - dir * TIME * 0.055 * force).r;
	float g = smoothstep(0.38, 0.66, front);
	g *= 0.75 + 0.25 * sin(dot(root.xz, dir) * 0.6 - TIME * 3.2 * force);
	float flutter = sin(TIME * 5.3 + root.x * 1.3 + root.z * 1.7) * 0.025;
	float bend = ((0.05 + 0.34 * g) * force + flutter) * stiff;
	VERTEX.xz += dir * bend * h * h * 1.5;
	VERTEX.y -= bend * bend * 0.7 * h;
	cdist = distance(CAMERA_POSITION_WORLD, root);
	// far clumps sink into the ground; one the lens is about to pass through gets out of its way
	float k = (1.0 - smoothstep(fade_near, fade_far, cdist)) * smoothstep(1.3, 3.6, cdist);
	VERTEX = mix(root, VERTEX, k);
	NORMAL = normalize(MODEL_MATRIX[1].xyz);
	gust = g * h;
	vec3 turf = mix(grass_a, grass_b, COLOR.r);
	turf = mix(turf, straw, clamp(dry * 0.5 + COLOR.g * 0.35 - 0.12, 0.0, 0.8) * (0.4 + 0.6 * COLOR.r));
	turf *= 0.8 + 0.4 * COLOR.b;
	tint = turf;
	// gorse among the heather: one clump in five flowers yellow
	bloom = mix(turf * 1.1, mix(heather, vec3(0.85, 0.62, 0.08), step(0.8, COLOR.g)), heather_amt);
	rootp = root;
}

void fragment() {
	vec4 a = texture(albedo_tex, UV);
	float h = 1.0 - UV.y;
	vec3 c = tint * mix(0.26, 0.92, smoothstep(0.0, 0.9, h)) * (0.5 + 0.62 * a.r);
	c = mix(c, c * 1.06 + straw * 0.05, smoothstep(0.65, 1.0, h) * 0.45);
	c = mix(c, tint * 0.42 * (0.7 + 0.5 * a.r), heath * (1.0 - a.g) * 0.8);
	c = mix(c, bloom * (0.8 + 0.5 * a.r), a.g * heath);
	c *= 0.92 + 0.42 * gust;
	c = mix(c, vec3(0.84, 0.88, 0.94), snow * 0.85 * smoothstep(0.3, 0.85, h + (a.r - 0.5) * 0.3));
	ALBEDO = c;
	// thin blades lose their alpha in the small mips: far clumps are given it back, or the far turf goes bald
	ALPHA = min(a.a * mix(1.0, 1.9, smoothstep(14.0, 90.0, cdist)), 1.0);
	ALPHA_SCISSOR_THRESHOLD = 0.38;
	ROUGHNESS = 1.0;
	lit = sun_shade(rootp);
}

void light() {
	float s = LIGHT_IS_DIRECTIONAL ? lit : 1.0;
	float ndl = max(dot(NORMAL, LIGHT), 0.0);
	// blades stand up: they take the low sun on their sides as well as the ground's share of it
	float side = 0.1 * (1.0 - UV.y);
	// and with the sun behind them they glow
	float through = pow(max(dot(VIEW, -LIGHT), 0.0), 3.0) * 0.3 * (1.0 - UV.y);
	DIFFUSE_LIGHT += (ndl + side + through) * ATTENUATION * LIGHT_COLOR * s / PI;
}
