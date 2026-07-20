shader_type spatial;
render_mode cull_disabled;
// Terrain splat shader (ADR-003 flat-shaded look). Surfaces come as ONE-HOT WEIGHT textures
// (baked per classified pixel), sampled bilinear; the fragment picks the argmax -> boundaries
// are the smooth 50% iso-lines between regions instead of pixel staircases, with a one-screen-
// pixel fwidth blend for edge AA. Hard edges, smooth curves, zero world-space blur, and no
// phantom third surfaces (interpolation happens in weight space, not colour space).
//
// Everything per-surface arrives as a uniform array indexed the same way as the weights:
//   palette    canonical .tres colour
//   variation  tint noise amplitude
//   rough      how matte (1 = fully diffuse). Loose ground must catch NO highlight or it reads
//              as wet plastic; ice is the one surface that should genuinely look glossy.
//   chunk      fake blocky relief strength (see below)
// rr_wetness is driven globally by WeatherFX.

global uniform float rr_wetness;

uniform sampler2D weights0 : filter_linear, repeat_disable;
uniform sampler2D weights1 : filter_linear, repeat_disable;
uniform vec3 palette[6];
uniform float variation[6];
uniform float rough[6];
uniform float chunk[6];
uniform float world_size = 512.0;
uniform float cell_size = 0.1;      // tint cell — one voxel
uniform float chunk_size = 0.3;     // relief cell — a few voxels, so chunks read as stones not grain

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float cell_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec3 face_normal = normalize(cross(dFdy(VERTEX), dFdx(VERTEX)));
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
	float d = bw - sw;
	float aa = clamp(d / max(fwidth(d), 1e-4) * 0.5 + 0.5, 0.0, 1.0);

	float n = floor(cell_hash(floor(world_pos.xz / cell_size)) * 3.0) / 2.0 - 0.5;
	vec3 c_best = palette[best] * (1.0 + n * variation[best]);
	vec3 c_second = palette[second] * (1.0 + n * variation[second]);
	vec3 albedo = mix(c_second, c_best, aa);

	// Blocky micro-relief. Each cell picks one of 8 quantised tilt directions and a magnitude, so
	// the ground lights as if built from little cubes turned different ways — loose gravel catches
	// light on one face and shades on the next. Pure lighting: no geometry, no parallax, so it
	// costs nothing and leaves collision honest. Quantising the angle is what makes it read as
	// faceted chunks rather than smooth bumpy noise.
	float chunkiness = mix(chunk[second], chunk[best], aa);
	if (chunkiness > 0.001) {
		vec2 cell = floor(world_pos.xz / chunk_size);
		float ang = floor(cell_hash(cell) * 8.0) / 8.0 * TAU;
		float amt = (0.35 + 0.65 * cell_hash(cell + 37.0)) * chunkiness * 0.55;
		// The face normal is in view space; the tilt is authored in world space, so rotate it.
		vec3 tilt = (VIEW_MATRIX * vec4(cos(ang), 0.0, sin(ang), 0.0)).xyz;
		face_normal = normalize(face_normal + tilt * amt);
	}
	NORMAL = face_normal;

	// Wet ground darkens and tightens its highlight. Specular follows roughness instead of being a
	// flat constant — a fully matte surface then gets essentially none, which is what stops gravel
	// and dirt reading as plastic.
	float r = mix(rough[second], rough[best], aa);
	albedo *= mix(1.0, 0.62, rr_wetness);
	ALBEDO = albedo;
	ROUGHNESS = mix(r, min(r, 0.35), rr_wetness);
	SPECULAR = mix(0.05 + (1.0 - r) * 0.40, 0.5, rr_wetness);
}
