shader_type spatial;
// World-space anti-aliased grid for the physics spike — gives a sense of speed.
// Throwaway prototype helper.

uniform vec4 base_color : source_color = vec4(0.30, 0.34, 0.30, 1.0);
uniform vec4 line_color : source_color = vec4(0.12, 0.14, 0.12, 1.0);
uniform vec4 major_color : source_color = vec4(0.06, 0.07, 0.06, 1.0);
uniform float cell_size = 4.0;     // meters between minor lines
uniform float major_every = 5.0;   // every Nth line is bolder (depth cue)

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Returns ~1 on a grid line, ~0 in a cell, anti-aliased via screen-space derivatives.
float grid_line(vec2 coord) {
	vec2 g = abs(fract(coord - 0.5) - 0.5) / fwidth(coord);
	return 1.0 - min(min(g.x, g.y), 1.0);
}

void fragment() {
	float minor = grid_line(world_pos.xz / cell_size);
	float major = grid_line(world_pos.xz / (cell_size * major_every));
	vec3 col = mix(base_color.rgb, line_color.rgb, minor);
	col = mix(col, major_color.rgb, major);
	ALBEDO = col;
	ROUGHNESS = 0.95;
}
