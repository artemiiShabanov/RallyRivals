shader_type spatial;
render_mode cull_disabled;
// Terrain splat shader (art-shader-surface, ADR-003): flat-shaded low-poly look, with the
// surface splat sampled PER FRAGMENT from the exact painted image (nearest filter -> hard
// 1 m pixel edges between surfaces, exactly what the map editor shows). The splat's alpha
// carries each surface's tint-variation strength (SurfaceType.tint_variation baked in), so
// glassy ice and chunky gravel read differently. Tint cells are voxel-scale (0.1 m).
// rr_wetness is driven globally by WeatherFX.

global uniform float rr_wetness;

uniform sampler2D splat : filter_nearest, repeat_disable;
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
	vec4 s = texture(splat, uv);
	float n = cell_hash(floor(world_pos.xz / cell_size));
	float tint = 1.0 + (floor(n * 3.0) / 2.0 - 0.5) * s.a;
	vec3 albedo = s.rgb * tint;
	albedo *= mix(1.0, 0.62, rr_wetness);
	ALBEDO = albedo;
	ROUGHNESS = mix(0.95, 0.35, rr_wetness);
	SPECULAR = mix(0.3, 0.55, rr_wetness);
}
