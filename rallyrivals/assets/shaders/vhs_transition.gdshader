shader_type canvas_item;
// VHS channel-change scene transition (art-ui-transition). Flow drives `progress` 0->1 (cover) then
// 1->0 (reveal) around a scene swap: the frame loses sync — vertical roll, per-line tracking tears,
// chroma split, rising no-signal static — and collapses to black at the peak (masking the swap),
// then settles back. Reads the frame below via hint_screen_texture, like vhs.gdshader.
//
// `strength` = the VHS filter intensity, so the off switch reaches here too: at strength 0 every
// glitch drops out and only the fade-to-black remains — a clean cut for motion-sensitive players.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float strength : hint_range(0.0, 1.0) = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	float p = progress;
	float s = strength;
	float t = TIME;
	vec2 px = SCREEN_PIXEL_SIZE;
	vec2 uv = SCREEN_UV;

	// Loss of vertical sync — the picture slides upward, faster and jumpier as it collapses.
	float roll = p * p * (0.6 + 0.4 * sin(t * 20.0)) * s;
	uv.y = fract(uv.y + roll);

	// Per-line horizontal tracking tears; a fraction of lines jump hard (the head-switch tear).
	float line = floor(uv.y / max(px.y, 1e-5) / 3.0);      // ~3px bands
	float jitter = hash(vec2(line, floor(t * 24.0))) - 0.5;
	float hard = step(0.82, hash(vec2(line * 0.7, floor(t * 9.0))));
	uv.x += jitter * (0.04 + 0.20 * hard) * p * s;

	// Chroma split widens with p.
	float ab = (6.0 + 40.0 * p) * px.x * p * s;
	vec3 col = vec3(
		texture(screen_tex, vec2(uv.x + ab, uv.y)).r,
		texture(screen_tex, uv).g,
		texture(screen_tex, vec2(uv.x - ab, uv.y)).b);

	// No-signal static, rising through the back half.
	float st = hash(uv / max(px, vec2(1e-5)) * 0.5 + t * 60.0);
	col = mix(col, vec3(st), smoothstep(0.35, 1.0, p) * s * 0.9);

	// A bright head-switch bar sweeping up the frame as it tears.
	float bar_pos = fract(uv.y - t * 1.2);
	float bar = smoothstep(0.0, 0.04, bar_pos) * (1.0 - smoothstep(0.04, 0.10, bar_pos));
	col += bar * 0.4 * smoothstep(0.1, 0.7, p) * s;

	// Collapse to black at the peak — hides the actual scene change. Runs even at strength 0, so with
	// the tape off this is just a fade cut.
	col *= 1.0 - smoothstep(0.55, 1.0, p);

	COLOR = vec4(col, 1.0);
}
