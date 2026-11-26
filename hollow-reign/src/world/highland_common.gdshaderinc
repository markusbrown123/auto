// Shared by the high road's ground, rock and grass: the baked shadow of the land for this generation's sun,
// the Ring-Gate's own shadow (worked out, not sampled), and cloud shadow drifting with the wind.
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D sun_mask : filter_linear, repeat_disable, hint_default_white;
uniform vec4 land_rect;            // x0, z0, 1/width, 1/length of the height field
uniform vec2 wind = vec2(0.86, 0.5);
uniform vec3 sun_dir = vec3(0.6, 0.25, -0.6);   // toward the sun
uniform float ring_break = 0.0;    // 1: the arc is down, and its shadow with it
uniform float cloud_shadow = 0.5;
uniform float snow = 0.0;

const vec3 RING_C = vec3(0.0, 36.0, -32.0);
const float RING_R = 50.0;
const float RING_HALF = 5.5;

float cloud_shade(vec2 xz) {
	vec2 p = xz * 0.0017 + TIME * wind * 0.0045;
	float n = texture(noise_tex, p).r * 0.62 + texture(noise_tex, p * 2.3 + vec2(0.31, 0.17)).r * 0.38;
	return 1.0 - cloud_shadow * smoothstep(0.47, 0.63, n);
}

float ring_shade(vec3 p) {
	if (abs(sun_dir.z) < 0.04) {
		return 1.0;
	}
	float t = (RING_C.z - p.z) / sun_dir.z;
	if (t < 0.0) {
		return 1.0;
	}
	vec3 q = p + sun_dir * t;
	vec2 d = q.xy - RING_C.xy;
	float r = length(d);
	float soft = 0.6 + t * 0.012;
	float band = 1.0 - smoothstep(RING_HALF - soft, RING_HALF + soft, abs(r - RING_R));
	float ang = atan(d.x, -d.y);
	band *= 1.0 - ring_break * step(2.06, ang) * step(ang, 2.76);
	return 1.0 - band * 0.85 * (1.0 - smoothstep(260.0, 420.0, t));
}

float land_shade(vec3 p) {
	return texture(sun_mask, (p.xz - land_rect.xy) * land_rect.zw).r;
}

float sun_shade(vec3 p) {
	return land_shade(p) * ring_shade(p) * cloud_shade(p.xz);
}
