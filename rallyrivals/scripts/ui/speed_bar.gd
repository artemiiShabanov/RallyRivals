class_name SpeedBar
extends Control
## The rising, colour-ramped speed meter on the race HUD (art-ui-hud-gfx).
##
## Drawn rather than assembled from ColorRects in an HBoxContainer: the segments differ in height,
## and getting a box container to bottom-align children of mixed height reliably is more fight than
## it is worth. Drawing gives an exact common baseline, an exact ramp, and one node instead of
## fourteen.
##
## Segments grow taller left to right AND run green -> yellow -> orange -> red, so the meter says
## "fast" twice over: the ramp reads peripherally, the colour reads at a glance. Unlit segments keep
## their own hue at low alpha, so the bar still shows its shape when you are slow.

const PIPS := 14
const PIP_W := 9
const GAP := 3
const MIN_H := 5.0        # leftmost segment...
const MAX_H := 20.0       # ...rising to this at the right
const UNLIT_A := 0.16

## Green through to red. Stops are positions along the BAR, not speeds — the bar's own length is
## the scale, so a slow car still runs the full ramp against its own top speed.
const RAMP := [
	[0.00, Color(0.35, 0.85, 0.40)],   # green
	[0.45, Color(0.95, 0.90, 0.30)],   # yellow
	[0.75, Color(0.98, 0.62, 0.20)],   # orange
	[1.00, Color(0.95, 0.25, 0.25)],   # red
]

var value := 0.0:                      ## 0..1 of top speed
	set(v):
		var c := clampf(v, 0.0, 1.0)
		if not is_equal_approx(c, value):
			value = c
			queue_redraw()

func _init() -> void:
	custom_minimum_size = Vector2(PIPS * PIP_W + (PIPS - 1) * GAP, MAX_H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var lit := int(round(value * PIPS))
	for i in PIPS:
		var t := float(i) / float(PIPS - 1)
		var h := lerpf(MIN_H, MAX_H, t)
		var col := _ramp(t)
		if i >= lit:
			col.a = UNLIT_A
		# y from the BOTTOM edge, so every segment shares one baseline however tall it is
		draw_rect(Rect2(i * (PIP_W + GAP), size.y - h, PIP_W, h), col)

func _ramp(t: float) -> Color:
	for i in range(RAMP.size() - 1):
		var a: Array = RAMP[i]
		var b: Array = RAMP[i + 1]
		if t <= float(b[0]):
			var span := float(b[0]) - float(a[0])
			var k := 0.0 if span <= 0.0 else (t - float(a[0])) / span
			return (a[1] as Color).lerp(b[1] as Color, k)
	return RAMP[RAMP.size() - 1][1]
