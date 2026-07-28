shader_type canvas_item;
// Slipstream speed-lines (art-vfx-slipstream): thin radial streaks that rush inward from the screen
// edges and intensify with `strength` (the player's draft). Fades out toward the centre so the road
// ahead stays clear. Drawn over the world, under the HUD.

uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 line_color : source_color = vec4(0.90, 0.97, 1.0, 1.0);

float hash(float x) {
	return fract(sin(x * 12.9898) * 43758.5453);
}

void fragment() {
	vec2 c = UV - 0.5;
	float r = length(c);                              // 0 centre .. ~0.7 corner
	float ang = atan(c.y, c.x) / 6.2831853 + 0.5;     // 0..1 around
	float sectors = 130.0;
	float id = floor(ang * sectors);
	float rnd = hash(id);
	float active = step(rnd, 0.30 + 0.45 * strength); // more streaks appear as the draft builds
	float scroll = fract(r * 4.0 + TIME * 1.8 + rnd * 7.0);   // rush INWARD (toward the centre)
	float streak = smoothstep(0.55, 0.98, scroll);
	float edge = smoothstep(0.16, 0.5, r);            // clear centre, streaks live near the edges
	float a = streak * active * edge * strength * 0.8;
	COLOR = vec4(line_color.rgb, a * line_color.a);
}
