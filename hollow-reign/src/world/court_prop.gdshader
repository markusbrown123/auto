shader_type spatial;
// The Courtyard's small made things in one material (src/world/court_dress.gd): wood, iron, bone and rag, told apart by
// the vertex colour's alpha (0 wood, 0.5 bone or cloth, 1 iron; COLOR.rgb tints). Wood has a grain stretched along
// its length (world y on posts, across on boards: whichever way the face runs), iron is dark and pitted with rust,
// bone and rag are matte. One draw for all of them in a cell.
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 wood : source_color = vec3(0.42, 0.32, 0.22);
uniform vec3 iron : source_color = vec3(0.19, 0.18, 0.17);
uniform vec3 rust : source_color = vec3(0.32, 0.17, 0.09);
uniform vec3 bone : source_color = vec3(0.62, 0.58, 0.5);

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float kind = COLOR.a;
	vec3 n = abs(wnrm);
	// grain: along y on upright faces, along the longer horizontal axis otherwise
	vec2 gp = n.y > 0.6 ? wpos.xz : (n.x > n.z ? wpos.zy : wpos.xy);
	float g = texture(noise_tex, vec2(gp.x * 2.6, gp.y * 0.22)).r;
	float g2 = texture(noise_tex, vec2(gp.x * 9.0, gp.y * 0.6) + 0.37).r;
	float spot = texture(noise_tex, wpos.xz * 0.9 + wpos.y * 0.7).r;
	vec3 w = wood * (0.65 + 0.6 * g) * (0.85 + 0.3 * g2);
	vec3 i = mix(iron, rust, smoothstep(0.5, 0.75, spot)) * (0.8 + 0.4 * g2);
	vec3 b = bone * (0.85 + 0.3 * g2);
	float is_iron = smoothstep(0.7, 0.9, kind);
	float is_bone = (1.0 - is_iron) * smoothstep(0.25, 0.4, kind);
	vec3 c = mix(mix(w, b, is_bone), i, is_iron) * COLOR.rgb;
	ALBEDO = c;
	METALLIC = is_iron * (1.0 - smoothstep(0.5, 0.75, spot)) * 0.55;
	ROUGHNESS = mix(0.86, 0.6, is_iron) + is_iron * smoothstep(0.5, 0.75, spot) * 0.3;
	SPECULAR = 0.35;
}
