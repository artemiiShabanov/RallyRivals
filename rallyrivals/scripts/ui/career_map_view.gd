extends Control
## The career map's map panel (code-ui-career-map). Intentionally has NO class_name — the screen
## preload()s it by path, so it never depends on the global class registry (which lags newly created
## scripts in an open editor and would parse-error until a restart).
##
## The chapter's races are dots SCATTERED across the panel (seeded, so a region's layout is stable) and
## joined in race order by a smooth, 50%-opacity road; the boss is the larger final dot. Everything fits
## the panel — NO scroll. Navigate with all four arrows (nearest dot in the pressed direction), PageUp/
## PageDown to change chapter (paged signal), or the mouse. Emits focus_changed (drive the card) +
## activated (launch). Dot fill reads state: empty ring = not raced, half = completed, full = won.

signal focus_changed(index: int)
signal activated(index: int)
signal paged(delta: int)      ## PageUp/PageDown — the screen turns this into a chapter change

const DOT_R := 14.0
const BOSS_R := 20.0
const HIT_PAD := 10.0
const MARGIN := Vector2(56, 50)     # inset the dots keep from the panel edges
const JITTER := 0.62                 # how far a dot wanders inside its cell (0..1) — the "chaotic" look

const BG := Color(0.05, 0.10, 0.50)
const ROAD := Color(0.95, 0.97, 1.0, 0.5)    # 50% opacity
const INK := Color(0.95, 0.97, 1.0)
const DIM := Color(0.60, 0.68, 0.92, 0.6)
const SELECT := Color(1.0, 0.85, 0.3)
const BOSS_COL := Color(0.97, 0.38, 0.45)

var nodes: Array = []
var selected := 0
var _norm: Array = []       # per-node normalized position in [0,1]^2 (seeded)
var _px: Array = []         # per-node pixel position (resolved on resize)
var _road := PackedVector2Array()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	resized.connect(_relayout)

## Feed the nodes + a seed (stable scatter). Everything fits the panel; no scroll.
func configure(list: Array, gen_seed: int) -> void:
	nodes = list
	selected = clampi(selected, 0, maxi(0, nodes.size() - 1))
	_norm = _layout(nodes.size(), gen_seed)
	_relayout()

func select(i: int, notify := true) -> void:
	var n := clampi(i, 0, maxi(0, nodes.size() - 1))
	if n == selected and notify:
		return
	selected = n
	if notify:
		focus_changed.emit(selected)
	queue_redraw()

# --- layout: a jittered serpentine grid — fills the panel, road flows in order, dots scattered ---
func _layout(n: int, gen_seed: int) -> Array:
	if n <= 0:
		return []
	var rng := RandomNumberGenerator.new()
	rng.seed = gen_seed
	var cols := clampi(int(ceil(sqrt(float(n) * 0.75))), 2, 4)
	var rows := int(ceil(float(n) / float(cols)))
	var out: Array = []
	for i in n:
		var row := i / cols
		var col := i % cols
		if row % 2 == 1:
			col = cols - 1 - col                       # serpentine: reverse odd rows so the road flows
		var cx := (float(col) + 0.5) / float(cols) + rng.randf_range(-JITTER, JITTER) * 0.5 / float(cols)
		var cy := (float(row) + 0.5) / float(rows) + rng.randf_range(-JITTER, JITTER) * 0.5 / float(rows)
		out.append(Vector2(clampf(cx, 0.0, 1.0), clampf(cy, 0.0, 1.0)))
	return out

func _relayout() -> void:
	_px = []
	var inner := size - MARGIN * 2.0
	for p in _norm:
		_px.append(MARGIN + Vector2((p as Vector2).x * inner.x, (p as Vector2).y * inner.y))
	_road = _smooth(_px)
	queue_redraw()

# A smooth Catmull-Rom road through the ordered dots.
func _smooth(pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	if pts.size() < 2:
		return out
	var seg := 16
	for i in range(pts.size() - 1):
		var p0: Vector2 = pts[maxi(i - 1, 0)]
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[i + 1]
		var p3: Vector2 = pts[mini(i + 2, pts.size() - 1)]
		for s in seg:
			var t := float(s) / float(seg)
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * (2.0 * p1 + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.append(pts[pts.size() - 1])
	return out

# --- input ---
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var i := _hit((event as InputEventMouseMotion).position)
		if i >= 0:
			select(i)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var i := _hit((event as InputEventMouseButton).position)
		if i >= 0:
			select(i)
			activated.emit(selected)
			accept_event()
	elif event.is_action_pressed("ui_up", true):
		_nav(Vector2(0, -1)); accept_event()
	elif event.is_action_pressed("ui_down", true):
		_nav(Vector2(0, 1)); accept_event()
	elif event.is_action_pressed("ui_left", true):
		_nav(Vector2(-1, 0)); accept_event()
	elif event.is_action_pressed("ui_right", true):
		_nav(Vector2(1, 0)); accept_event()
	elif event.is_action_pressed("ui_accept"):
		if not nodes.is_empty():
			activated.emit(selected)
		accept_event()
	elif event.is_action_pressed("ui_page_up"):
		paged.emit(-1); accept_event()
	elif event.is_action_pressed("ui_page_down"):
		paged.emit(1); accept_event()

# Select the nearest dot that lies in direction `dir` from the current one (a cone/nearness score).
func _nav(dir: Vector2) -> void:
	if _px.size() < 2:
		return
	var cur: Vector2 = _px[selected]
	var best := -1
	var best_score := INF
	for i in nodes.size():
		if i == selected:
			continue
		var d: Vector2 = _px[i] - cur
		var along := d.dot(dir)
		if along <= 1.0:
			continue                                   # not in the pressed direction
		var perp := absf(d.dot(Vector2(-dir.y, dir.x)))
		var score := along + perp * 2.5                # favour aligned + near
		if score < best_score:
			best_score = score
			best = i
	if best >= 0:
		select(best)

func _hit(p: Vector2) -> int:
	for i in nodes.size():
		var r: float = BOSS_R if bool(nodes[i].get("boss", false)) else DOT_R
		if p.distance_to(_px[i]) <= r + HIT_PAD:
			return i
	return -1

# --- draw ---
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	if _px.is_empty():
		return
	if _road.size() >= 2:
		draw_polyline(_road, ROAD, 4.0, true)
	for i in nodes.size():
		_draw_node(i)

func _draw_node(i: int) -> void:
	var c: Vector2 = _px[i]
	var nd: Dictionary = nodes[i]
	var boss: bool = bool(nd.get("boss", false))
	var locked: bool = bool(nd.get("locked", false))
	var state: int = int(nd.get("state", 0))
	var r: float = BOSS_R if boss else DOT_R
	var base: Color = (BOSS_COL if boss else INK)
	if locked:
		base = DIM
	draw_circle(c, r, BG)                              # backing disc so the road doesn't show through
	draw_arc(c, r, 0.0, TAU, 40, base, 3.0, true)      # ring = not raced
	if state == 2:
		draw_circle(c, r - 1.0, base)                  # full = won
	elif state == 1:
		_draw_half(c, r - 1.0, base)                   # half = completed
	if i == selected:
		draw_arc(c, r + 6.0, 0.0, TAU, 44, SELECT, 3.0, true)

# Fill the lower semicircle (θ 0..π, +y is down) — reads as a half-filled dot.
func _draw_half(c: Vector2, r: float, col: Color) -> void:
	var poly := PackedVector2Array()
	var steps := 20
	for s in steps + 1:
		var a := PI * float(s) / float(steps)
		poly.append(c + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(poly, col)
