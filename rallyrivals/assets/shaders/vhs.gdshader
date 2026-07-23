shader_type canvas_item;
// VHS tape post-process (art-shader-vhs). A full-screen ColorRect reads the rendered frame
// (hint_screen_texture) and re-draws it degraded. Two tiers of effect:
//   ALWAYS-ON (scaled by `intensity`): chroma bleed, steady per-row shimmer, grain, scanlines,
//     vignette, tape warmth. Safe under motion — this is the driving look.
//   GLITCH (scaled by `intensity * glitch`): the vertically-SCROLLING artifacts — the rolling
//     head-switch bright bar and the tracking tear. These read as a line crawling up the frame,
//     which is distracting while driving, so the race sets glitch=0 and only menus/loading/replays
//     set glitch=1.
// One `intensity` dial (0 = clean passthrough = off switch) drives every filter; the settings
// slider and the debug menu write it. Sits below the HUD, so the scorebug never gets fogged.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float intensity : hint_range(0.0, 1.0) = 0.75;
uniform float glitch : hint_range(0.0, 1.0) = 0.0;   // 0 = driving (no scrolling line), 1 = menus

// Per-effect weights — the knobs. Cranked harder than the first pass.
uniform float aberration_px = 3.6;
uniform float wobble_px = 1.0;
uniform float grain = 0.1;
uniform float scanlines = 0.05;
uniform float vignette = 0.18;      // edges only — kept light so it doesn't read as global dimming
uniform float warmth = 0.06;
uniform float brightness = 1.03;    // small lift to offset the tape's tendency to darken

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	float I = intensity;
	float G = intensity * glitch;     // scrolling artifacts: menus only
	vec2 px = SCREEN_PIXEL_SIZE;
	vec2 size = 1.0 / px;
	float t = TIME;
	vec2 uv = SCREEN_UV;

	// Steady per-row shimmer (always) — a fine horizontal tremble, not a moving line.
	float shake = sin(uv.y * 90.0 + t * 3.0) * 0.5 + sin(uv.y * 13.0 - t * 1.3) * 0.5;
	uv.x += shake * wobble_px * px.x * I;

	// Scrolling tracking tear (menus only) — a band that jumps horizontally, creeping up the frame.
	float band = smoothstep(0.965, 1.0, sin(uv.y * 4.0 - t * 0.5) * 0.5 + 0.5);
	uv.x += band * 3.5 * px.x * G;

	// Chroma bleed.
	float ab = aberration_px * px.x * I;
	vec3 col = vec3(
		texture(screen_tex, uv + vec2(ab, 0.0)).r,
		texture(screen_tex, uv).g,
		texture(screen_tex, uv - vec2(ab, 0.0)).b);

	// Rolling head-switch bright bar (menus only) — the bottom-to-top line.
	float pos = fract(uv.y + t * 0.08);
	float bar = smoothstep(0.0, 0.03, pos) * (1.0 - smoothstep(0.03, 0.07, pos));
	col += bar * 0.07 * G;

	// Scanlines — net-neutral: lines oscillate around 1.0 (some brighter, some darker), so they add
	// tape texture without dimming the overall image.
	col *= 1.0 + scanlines * I * sin(uv.y * size.y * 3.14159265) * 0.5;

	// Animated grain.
	col += (hash(uv * size + fract(t) * 91.7) - 0.5) * grain * I;

	// Gentle vignette (edges only) + a whisper of desat, then a small brightness lift so the tape
	// doesn't leave the picture darker than it found it.
	vec2 d = uv - 0.5;
	col *= 1.0 - dot(d, d) * vignette * I;
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(luma), warmth * I);
	col *= mix(1.0, brightness, I);

	COLOR = vec4(col, 1.0);
}
