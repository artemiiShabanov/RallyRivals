extends SceneTree
## Generates the RallyRivals master palette (ADR-003: ONE palette shared by voxel models and
## terrain). 10 ramps x 6 shades = 60 colours. The six SurfaceType colours are PINNED exactly
## into their ramps — the palette builds around the classifier anchors, never moves them.
## Writes: assets/palette/rallyrivals_palette.png  (256x1 MagicaVoxel-importable strip)
##         assets/palette/rallyrivals_swatches.png (human-readable swatch sheet)
## Run: godot --headless --script res://scripts/tools/gen_palette.gd
## Ramp discipline: linear HSV between hand-picked endpoints (hue via shortest path), darkest
## to lightest, 6 steps. Change endpoints here and regenerate — the PNGs are artifacts.

const SHADES := 6
const CELL := 40

# name, dark endpoint, light endpoint, {step: pinned exact colour}
var ramps := [
	["asphalt", Color(0.10, 0.10, 0.13), Color(0.62, 0.62, 0.66), {3: Color(0.3, 0.3, 0.32)}],
	["gravel", Color(0.16, 0.16, 0.15), Color(0.72, 0.72, 0.68), {3: Color(0.45, 0.45, 0.43)}],
	["dirt", Color(0.18, 0.10, 0.05), Color(0.75, 0.58, 0.38), {3: Color(0.45, 0.3, 0.16)}],
	["sand", Color(0.35, 0.27, 0.13), Color(0.96, 0.90, 0.70), {4: Color(0.8, 0.7, 0.45)}],
	["grass", Color(0.08, 0.18, 0.08), Color(0.62, 0.80, 0.38), {}],
	["frost", Color(0.35, 0.48, 0.62), Color(0.97, 0.98, 1.0), {4: Color(0.78, 0.88, 0.95), 5: Color(0.92, 0.94, 0.97)}],
	["apex", Color(0.06, 0.06, 0.09), Color(0.45, 0.47, 0.54), {}],
	["wreck", Color(0.20, 0.09, 0.05), Color(0.82, 0.48, 0.25), {}],
	["mayfly", Color(0.04, 0.14, 0.35), Color(0.45, 0.80, 0.98), {}],
	["accents", Color.BLACK, Color.WHITE, {
		0: Color(0.78, 0.11, 0.17),   # apex crimson
		1: Color(0.95, 0.45, 0.08),   # wreckhouse hazard orange
		2: Color(0.98, 0.83, 0.14),   # mayfly safety yellow
		3: Color(0.90, 0.72, 0.30),   # gold (rewards/UI)
		4: Color(0.45, 0.85, 0.65),   # mint (UI positive)
		5: Color(0.98, 0.97, 0.95),   # near-white
	}],
]

func _initialize() -> void:
	var dir := "res://assets/palette/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var colors: Array[Color] = []
	for ramp in ramps:
		for i in SHADES:
			var pins: Dictionary = ramp[3]
			if pins.has(i):
				colors.append(pins[i])
			else:
				colors.append(_hsv_lerp(ramp[1], ramp[2], float(i) / (SHADES - 1)))

	# MagicaVoxel strip: 256x1 (MV reads up to 255 slots; unused stay black)
	var strip := Image.create(256, 1, false, Image.FORMAT_RGBA8)
	for i in colors.size():
		strip.set_pixel(i, 0, colors[i])
	strip.save_png(ProjectSettings.globalize_path(dir + "rallyrivals_palette.png"))

	# swatch sheet: one ramp per row
	var sheet := Image.create(SHADES * CELL, ramps.size() * CELL, false, Image.FORMAT_RGB8)
	for r in ramps.size():
		for i in SHADES:
			sheet.fill_rect(Rect2i(i * CELL, r * CELL, CELL, CELL), colors[r * SHADES + i])
	sheet.save_png(ProjectSettings.globalize_path(dir + "rallyrivals_swatches.png"))

	for r in ramps.size():
		var line: String = ramps[r][0] + ": "
		for i in SHADES:
			line += "#" + colors[r * SHADES + i].to_html(false) + " "
		print(line)
	print("palette: %d colours -> %s" % [colors.size(), dir])
	quit()

func _hsv_lerp(a: Color, b: Color, t: float) -> Color:
	var ah := a.h
	var bh := b.h
	if absf(bh - ah) > 0.5:   # shortest hue path
		if bh > ah: ah += 1.0
		else: bh += 1.0
	return Color.from_hsv(fposmod(lerpf(ah, bh, t), 1.0), lerpf(a.s, b.s, t), lerpf(a.v, b.v, t))
