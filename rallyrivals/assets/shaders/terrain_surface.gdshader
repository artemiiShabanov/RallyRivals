shader_type spatial;
render_mode cull_disabled;
// Terrain splat shader (ADR-003 flat-shaded look). Surfaces come as ONE-HOT WEIGHT textures
// (baked per classified pixel), sampled bilinear; the fragment picks the argmax -> boundaries
// are the smooth 50% iso-lines between regions instead of pixel staircases, with a one-screen-
// pixel fwidth blend for edge AA. Hard edges, smooth curves, zero world-space blur, and no
// phantom third surfaces (interpolation happens in weight space, not colour space).
// palette/variation arrays are the surfaces' canonical .tres colour + tint_variation.
// rr_wetness is driven globally by WeatherFX.

global uniform float rr_wetness;

uniform sampler2D weights0 : filter_linear, repeat_disable;
uniform sampler2D weights1 : filter_linear, repeat_disable;
uniform vec3 palette[6];
uniform float variation[6];
uniform float world_size = 512.0;
uniform float cell_size = 0.1;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float cell_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	NORMAL = normalize(cross(dFdy(VERTEX), dFdx(VERTEX)));
	vec2 uv = world_pos.xz / world_size + 0.5;
	vec4 wa = texture(weights0, uv);
	vec2 wb = texture(weights1, uv).rg;
	float w[6] = float[6](wa.r, wa.g, wa.b, wa.a, wb.r, wb.g);
	int best = 0;
	int second = 1;
	float bw = -1.0;
	float sw = -1.0;
	for (int i = 0; i < 6; i++) {
		if (w[i] > bw) {
			second = best; sw = bw;
			best = i; bw = w[i];
		} else if (w[i] > sw) {
			second = i; sw = w[i];
		}
	}
	float n = floor(cell_hash(floor(world_pos.xz / cell_size)) * 3.0) / 2.0 - 0.5;
	vec3 c_best = palette[best] * (1.0 + n * variation[best]);
	vec3 c_second = palette[second] * (1.0 + n * variation[second]);
	float d = bw - sw;
	float aa = clamp(d / max(fwidth(d), 1e-4) * 0.5 + 0.5, 0.0, 1.0);
	vec3 albedo = mix(c_second, c_best, aa);
	albedo *= mix(1.0, 0.62, rr_wetness);
	ALBEDO = albedo;
	ROUGHNESS = mix(0.95, 0.35, rr_wetness);
	SPECULAR = mix(0.3, 0.55, rr_wetness);
}
