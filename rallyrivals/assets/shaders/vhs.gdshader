shader_type canvas_item;
// VHS tape post-process (art-shader-vhs). A full-screen ColorRect reads the rendered frame
// (hint_screen_texture) and re-draws it degraded: chroma bleed, tracking wobble, a rolling head-
// switch band, grain, scanlines, vignette, tape warmth. Everything scales by `intensity` (0 = clean
// passthrough), so ONE dial drives the whole look — the settings slider and the debug menu write it.
//
// Tuned for DRIVING: noticeable but gentle. Heavier tracking/glitch for transitions (menus, loading,
// replays) is a future variant that cranks the same knobs. Sits below the HUD layer, so the scorebug
// never gets fogged.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float intensity : hint_range(0.0, 1.0) = 0.6;

// Per-effect weights (relative to intensity) — the knobs to tune.
uniform float aberration_px = 1.6;    // chroma split, pixels
uniform float wobble_px = 1.3;        // horizontal tracking displacement, pixels
uniform float grain = 0.055;
uniform float scanlines = 0.06;
uniform float vignette = 0.30;
uniform float warmth = 0.05;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	float I = intensity;
	vec2 px = SCREEN_PIXEL_SIZE;      // 1 / viewport, so effects are resolution-independent
	vec2 size = 1.0 / px;
	float t = TIME;
	vec2 uv = SCREEN_UV;

	// Tracking wobble: a small per-row horizontal shake, plus an occasional stronger band that
	// scrolls up the frame — the tape not quite holding sync. Kept tiny so the road stays steady.
	float shake = sin(uv.y * 90.0 + t * 3.0) * 0.5 + sin(uv.y * 13.0 - t * 1.3) * 0.5;
	float band = smoothstep(0.965, 1.0, sin(uv.y * 4.0 - t * 0.5) * 0.5 + 0.5);
	uv.x += (shake * 0.4 + band * 3.0) * wobble_px * px.x * I;

	// Chroma bleed: split R/B horizontally.
	float ab = aberration_px * px.x * I;
	vec3 col = vec3(
		texture(screen_tex, uv + vec2(ab, 0.0)).r,
		texture(screen_tex, uv).g,
		texture(screen_tex, uv - vec2(ab, 0.0)).b);

	// Rolling head-switch band: a faint bright bar creeping down the frame.
	float pos = fract(uv.y + t * 0.08);
	float bar = smoothstep(0.0, 0.03, pos) * (1.0 - smoothstep(0.03, 0.07, pos));
	col += bar * 0.05 * I;

	// Scanlines — very low amplitude; they shimmer under motion, so keep them a whisper.
	col *= 1.0 - scanlines * I * (0.5 + 0.5 * sin(uv.y * size.y * 3.14159265));

	// Animated grain.
	col += (hash(uv * size + fract(t) * 91.7) - 0.5) * grain * I;

	// Vignette + tape warmth/desat.
	vec2 d = uv - 0.5;
	col *= 1.0 - dot(d, d) * vignette * I * 2.0;
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(luma), warmth * I);
	col *= mix(vec3(1.0), vec3(1.03, 0.99, 0.96), I);

	COLOR = vec4(col, 1.0);
}
