shader_type spatial;
render_mode cull_disabled;
// Terrain splat shader (art-shader-surface, ADR-003): flat-shaded low-poly look over the
// baker's vertex-coloured surface meshes. Facet normals come from screen-space derivatives,
// so baked smooth normals are simply ignored. Subtle QUANTIZED per-cell tint variation keeps
// large fields alive without leaving the palette neighbourhood. rr_wetness is set globally by
// WeatherFX — wet races darken and gloss the ground.

global uniform float rr_wetness;

uniform float variation_strength : hint_range(0.0, 0.3) = 0.10;
uniform float cell_size = 2.0;

varying vec3 world_pos;
varying vec4 vcol;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vcol = COLOR;
}

float cell_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	NORMAL = normalize(cross(dFdy(VERTEX), dFdx(VERTEX)));
	float n = cell_hash(floor(world_pos.xz / cell_size));
	float tint = 1.0 + (floor(n * 3.0) / 2.0 - 0.5) * variation_strength;
	vec3 albedo = vcol.rgb * tint;
	albedo *= mix(1.0, 0.62, rr_wetness);
	ALBEDO = albedo;
	ROUGHNESS = mix(0.95, 0.35, rr_wetness);
	SPECULAR = mix(0.3, 0.55, rr_wetness);
}
