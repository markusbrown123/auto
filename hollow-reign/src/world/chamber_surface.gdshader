shader_type spatial;
// The awakening chamber's surfaces (src/world/chamber.gd): plate, gunmetal, bronze, ceramic and the deck, all old.
// Laid on in world space from three sides (no UVs needed on the code-built geometry):
//   - the shared panel sheet (Highland._panels) for plate seams, at `panel_amt`;
//   - the gear kit's worn-steel sheet for the metal's own grain, and a generated scratch sheet for wear;
//   - dust settled on every face turned up, heavier low down; rust/verdigris run down from seams on upright faces;
//   - a baked-looking occlusion term: darker at the foot of the walls, in the crown of the vault and in corners
//     (`ao_low`, `ao_high`), so the room reads as lit by a few lamps and their bounce, not by flat ambient.
// Five sheet reads per sample (three-way blended), two noise reads. Opaque, one pass.
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D panel_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D panel_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grain_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grain_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D scratch_tex : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 tint : source_color = vec3(0.4, 0.42, 0.43);
uniform float metal = 0.55;
uniform float rough = 0.55;
uniform float panel_scale = 0.25;          // panel sheets a metre
uniform float panel_amt = 0.8;
uniform float grain_scale = 1.2;
uniform float scratch_amt = 0.7;
uniform vec3 dust : source_color = vec3(0.42, 0.39, 0.34);
uniform float dust_amt = 0.7;
uniform vec3 rust : source_color = vec3(0.3, 0.18, 0.1);
uniform float rust_amt = 0.45;
uniform float ao_low = 0.55;               // how dark the foot of things is (0: black, 1: no change)
uniform float ao_high = 0.6;               // how dark the crown of the vault is
uniform float vault_y = 4.6;               // above this the vault darkens toward ao_high
uniform float floor_mode = 0.0;            // 1: the deck (no foot darkening, dust in the joints and worn paths)
uniform vec2 room_centre = vec2(0.0, 0.0);

varying vec3 tp;
varying vec3 tw;
varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	vec3 normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	TANGENT = vec3(0.0, 0.0, -1.0) * abs(normal.x);
	TANGENT += vec3(1.0, 0.0, 0.0) * abs(normal.y);
	TANGENT += vec3(1.0, 0.0, 0.0) * abs(normal.z);
	TANGENT = inverse(MODEL_NORMAL_MATRIX) * normalize(TANGENT);
	BINORMAL = vec3(0.0, 1.0, 0.0) * abs(normal.x);
	BINORMAL += vec3(0.0, 0.0, -1.0) * abs(normal.y);
	BINORMAL += vec3(0.0, 1.0, 0.0) * abs(normal.z);
	BINORMAL = inverse(MODEL_NORMAL_MATRIX) * normalize(BINORMAL);
	tw = pow(abs(normal), vec3(4.0));
	tw /= dot(tw, vec3(1.0));
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normal;
	tp = wpos * vec3(1.0, -1.0, 1.0);
}

vec4 tri(sampler2D s, float k) {
	vec3 p = tp * k;
	return texture(s, p.xy) * tw.z + texture(s, p.xz) * tw.y + texture(s, p.zy * vec2(-1.0, 1.0)) * tw.x;
}

void fragment() {
	vec3 pt = tri(panel_tex, panel_scale).rgb;
	vec3 gr = tri(grain_tex, grain_scale).rgb;
	float sc = tri(scratch_tex, grain_scale * 0.7).r;
	float side = wpos.x * tw.z + wpos.z * tw.x + wpos.x * tw.y;
	float up = wpos.y * (1.0 - tw.y) + wpos.z * tw.y;
	float n = texture(noise_tex, vec2(side, up) * 0.09 + vec2(0.31, 0.17)).r;
	float n2 = texture(noise_tex, vec2(side * 0.6, up * 0.035) + vec2(0.7, 0.2)).r;
	float upright = 1.0 - tw.y;
	float seam = 1.0 - smoothstep(0.38, 0.62, dot(pt, vec3(0.333)));       // where the sheet has a groove
	vec3 c = tint * mix(vec3(1.0), pt * 1.12, panel_amt) * mix(vec3(1.0), gr * 1.15, 0.55) * (0.82 + 0.36 * n);
	// wear: bright bare metal in the scratches, a little smoother
	float wear = sc * scratch_amt * (0.5 + 0.5 * smoothstep(0.3, 0.7, n));
	c = mix(c, c * 1.9 + vec3(0.05), wear * metal);
	// corrosion runs down from the seams and gathers in broad stains
	float run = smoothstep(0.55, 0.8, n2) * upright + seam * 0.35;
	float rs = clamp(run * rust_amt * smoothstep(0.3, 0.65, n), 0.0, 1.0);
	c = mix(c, rust * (0.7 + 0.6 * n), rs);
	// dust on everything turned up, more of it low down and in still corners
	float facing_up = smoothstep(0.35, 0.85, wnrm.y);
	float low = 1.0 - smoothstep(0.0, 2.6, wpos.y);
	float ds = dust_amt * facing_up * (0.55 + 0.45 * low) * smoothstep(0.25, 0.7, n + 0.25);
	if (floor_mode > 0.5) {
		// the deck: dust drifts against the plate joints and away from where feet went; a darker worn path to the door
		float r = length(wpos.xz - room_centre);
		float path = 1.0 - smoothstep(0.5, 1.3, abs(wpos.x)) * step(wpos.z, 1.0);
		ds = dust_amt * (0.45 + 0.55 * seam) * smoothstep(0.2, 0.8, n + 0.2) * (1.0 - 0.45 * path) * smoothstep(0.4, 1.6, r);
	}
	c = mix(c, dust * (0.85 + 0.3 * n), clamp(ds, 0.0, 0.92));
	// baked-looking occlusion
	float ao = mix(ao_low, 1.0, smoothstep(0.0, 1.1, wpos.y + (n - 0.5) * 0.3));
	ao *= mix(1.0, ao_high, smoothstep(vault_y, vault_y + 1.6, wpos.y));
	ao = mix(ao, 1.0, floor_mode);
	c *= ao;
	ALBEDO = c;
	ROUGHNESS = clamp(mix(rough + (n - 0.5) * 0.15, 0.95, max(ds, rs * 0.8)) - wear * 0.18, 0.2, 1.0);
	METALLIC = metal * (1.0 - clamp(ds + rs, 0.0, 1.0));
	SPECULAR = 0.45;
	AO = ao;
	AO_LIGHT_AFFECT = 0.25;
	NORMAL_MAP = normalize(mix(tri(panel_n, panel_scale).rgb, tri(grain_n, grain_scale).rgb, 0.4));
	NORMAL_MAP_DEPTH = mix(0.9, 0.4, ds);
}
