extends Control
## The career map's left panel (code-ui-career-map). Intentionally has NO class_name — the screen
## preload()s it by path, so it never depends on the global class registry (which lags behind newly
## created scripts in an open editor and would parse-error until a restart).
## a winding top-to-bottom "road" through a chapter's
## races drawn as dots, the boss as the final node, and caps marking the region above / the next region
## below. The layout is randomly generated but SEEDED (stable per save+chapter). Navigate up/down (the
## view keeps the selected node centred and scrolls smoothly); it emits focus_changed (drive the detail
## card) and activated (launch). Mouse hover selects, click activates, wheel scrolls.
##
## Nodes are DRAWN, not child controls, so their state — empty ring (not raced) / half (completed) /
## full (won) — plus the boss + locked styling all live in _draw. Presentation + navigation only; the
## screen owns the data, the card and the launch.

signal focus_changed(index: int)
signal activated(index: int)

const V_GAP := 132.0         # vertical pixels between nodes
const TOP_NODE := 150.0      # y of the first node in content space
const CAP_TOP := 66.0        # y of the top region cap
const BOTTOM_EXTRA := 170.0  # content below the last node (holds the next-region cap)
const MEANDER := 0.30        # horizontal wander of the road, as a fraction of width (±)
const DOT_R := 15.0
const BOSS_R := 22.0
const HIT_PAD := 8.0
const SCROLL_SPEED := 1600.0

const BG := Color(0.05, 0.10, 0.50)
const ROAD := Color(0.95, 0.97, 1.0, 0.95)
const ROAD_EDGE := Color(0.02, 0.05, 0.24, 0.95)
const INK := Color(0.95, 0.97, 1.0)
const DIM := Color(0.60, 0.68, 0.92, 0.65)
const SELECT := Color(1.0, 0.85, 0.3)
const BOSS_COL := Color(0.97, 0.38, 0.45)

var nodes: Array = []        # [{label, state 0/1/2, locked, boss, ...}] — owned by the screen
var selected := 0
var _pos: Array = []         # per node: Vector2(wobble -1..1, y in content space)
var _content_h := 0.0
var _off := 0.0              # current vertical scroll offset
var _target := 0.0           # desired offset (keeps `selected` centred)
var _top_text := ""
var _bottom_text := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	resized.connect(_on_resized)

## Feed the nodes + a seed (stable layout) + the region caps.
func configure(list: Array, gen_seed: int, top_text: String, bottom_text: String) -> void:
	nodes = list
	_top_text = top_text
	_bottom_text = bottom_text
	var rng := RandomNumberGenerator.new()
	rng.seed = gen_seed
	_pos = []
	for i in nodes.size():
		_pos.append(Vector2(rng.randf_range(-1.0, 1.0), TOP_NODE + i * V_GAP))
	_content_h = TOP_NODE + maxf(0.0, (nodes.size() - 1) * V_GAP) + BOTTOM_EXTRA
	selected = clampi(selected, 0, maxi(0, nodes.size() - 1))
	_retarget()
	_off = _target
	queue_redraw()

## Move the selection (clamped). notify=false sets it silently; recenter=false highlights WITHOUT
## auto-scrolling — the mouse uses this so the pointed-at dot stays under the cursor (else the map
## slides it away between hover and click, and the click lands on the wrong race). Keyboard recenters.
func select(i: int, notify := true, recenter := true) -> void:
	var n := clampi(i, 0, maxi(0, nodes.size() - 1))
	if n == selected and notify:
		return
	selected = n
	if recenter:
		_retarget()
	if notify:
		focus_changed.emit(selected)
	queue_redraw()

func _on_resized() -> void:
	_retarget()
	_off = _target          # snap during layout (invisible), then _process handles nav scrolls
	queue_redraw()

# --- scroll ---
func _retarget() -> void:
	if _pos.is_empty():
		_target = 0.0
		return
	_target = clampf(_pos[selected].y - size.y * 0.5, 0.0, maxf(0.0, _content_h - size.y))

func _process(dt: float) -> void:
	if absf(_off - _target) > 0.5:
		_off = move_toward(_off, _target, SCROLL_SPEED * dt)
		queue_redraw()

# --- geometry ---
func _node_px(i: int) -> Vector2:            # content-space centre (before scroll)
	return Vector2(size.x * 0.5 + _pos[i].x * size.x * MEANDER, _pos[i].y)

func _screen_px(i: int) -> Vector2:          # on-screen centre
	return _node_px(i) - Vector2(0.0, _off)

func _hit(p: Vector2) -> int:
	for i in nodes.size():
		var r: float = BOSS_R if bool(nodes[i].get("boss", false)) else DOT_R
		if p.distance_to(_screen_px(i)) <= r + HIT_PAD:
			return i
	return -1

# --- input (this control owns keyboard nav while focused) ---
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var i := _hit((event as InputEventMouseMotion).position)
		if i >= 0:
			select(i, true, false)      # hover: highlight, but don't scroll it out from under the cursor
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			var i := _hit(mb.position)
			if i >= 0:
				select(i, true, false)
				activated.emit(selected)
				accept_event()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll_by(-70.0)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll_by(70.0)
			accept_event()
	elif event.is_action_pressed("ui_up", true):     # allow_echo: holding the key repeats
		select(selected - 1)                         # keyboard recenters (default)
		accept_event()
	elif event.is_action_pressed("ui_down", true):
		select(selected + 1)
		accept_event()
	elif event.is_action_pressed("ui_accept"):
		if not nodes.is_empty():
			activated.emit(selected)
		accept_event()

func _scroll_by(d: float) -> void:
	_off = clampf(_off + d, 0.0, maxf(0.0, _content_h - size.y))
	_target = _off
	queue_redraw()

# --- draw ---
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	if nodes.is_empty():
		return
	var font := get_theme_default_font()
	var fs := get_theme_default_font_size()

	# the road: a bordered white polyline through every node
	var pts := PackedVector2Array()
	for i in nodes.size():
		pts.append(_screen_px(i))
	if pts.size() >= 2:
		draw_polyline(pts, ROAD_EDGE, 9.0, true)
		draw_polyline(pts, ROAD, 4.0, true)

	_draw_cap(Vector2(size.x * 0.5, CAP_TOP - _off), _top_text, INK, font, fs)
	_draw_cap(Vector2(size.x * 0.5, _content_h - BOTTOM_EXTRA * 0.5 - _off), _bottom_text, DIM, font, fs)

	for i in nodes.size():
		_draw_node(i, font, fs)

func _draw_cap(c: Vector2, text: String, col: Color, font: Font, fs: int) -> void:
	if text == "" or c.y < -40.0 or c.y > size.y + 40.0:
		return
	draw_line(c - Vector2(72, 0), c + Vector2(72, 0), col, 2.0)
	if font != null:
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, c + Vector2(-w * 0.5, -12.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

func _draw_node(i: int, font: Font, fs: int) -> void:
	var c := _screen_px(i)
	if c.y < -60.0 or c.y > size.y + 60.0:
		return
	var nd: Dictionary = nodes[i]
	var boss: bool = bool(nd.get("boss", false))
	var locked: bool = bool(nd.get("locked", false))
	var state: int = int(nd.get("state", 0))
	var r: float = BOSS_R if boss else DOT_R
	var base: Color = (BOSS_COL if boss else INK)
	if locked:
		base = DIM
	draw_arc(c, r, 0.0, TAU, 40, base, 3.0, true)      # ring (empty)
	if state == 2:
		draw_circle(c, r - 1.0, base)                  # full = won
	elif state == 1:
		_draw_half(c, r - 1.0, base)                   # half = completed
	if i == selected:
		draw_arc(c, r + 6.0, 0.0, TAU, 44, SELECT, 3.0, true)
	if font != null:
		draw_string(font, c + Vector2(r + 10.0, fs * 0.35), String(nd.get("label", "")),
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, base)

# Fill the lower semicircle (θ 0..π, +y is down) — reads as a half-filled dot.
func _draw_half(c: Vector2, r: float, col: Color) -> void:
	var poly := PackedVector2Array()
	var steps := 20
	for s in steps + 1:
		var a := PI * float(s) / float(steps)
		poly.append(c + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(poly, col)
