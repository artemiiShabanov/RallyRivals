class_name RaceHud
extends CanvasLayer
## The in-race HUD (code-ui-hud): speed, running time + best, lap counter, a position placeholder,
## and a checkpoint split popup. Retro-chunky — hard-edged palette panels, heavy text outlines,
## no rounded corners — to sit with the voxel look. Built in code like the debug menu.
##
## Data only flows IN: get_forward_speed() for speed, RaceTiming for the clock/laps, gate_crossed
## for splits. It measures nothing itself except the per-gate best (to colour a split green/red) —
## RaceTiming gives the split into the current lap; "vs your best at this gate" lives here.

const SULPHUR := Color("f5f5b8")   # identity yellow — speed
const CARMINE := Color("a10b2b")   # identity red — slower splits, borders
const CREAM := Color(0.95, 0.92, 0.85)
const GOLD := Color(0.82, 0.68, 0.38)
const SAGE := Color(0.55, 0.80, 0.55)   # faster splits
const PANEL_BG := Color(0.05, 0.05, 0.07, 0.62)

var _car: VehicleController
var _timing: RaceTiming
var _is_loop := true
var _laps_total := 3

var _speed: Label
var _time: Label
var _best: Label
var _lap: Label
var _split: Label
var _split_ttl := 0.0
var _gate_best := {}   # gate index -> best split seen (for the +/- colour)

func bind(car: VehicleController, timing: RaceTiming, cps: TrackCheckpoints, laps_total: int) -> void:
	_car = car
	_timing = timing
	_is_loop = cps.loop
	_laps_total = laps_total
	if timing != null:
		timing.gate_crossed.connect(_on_gate)
		timing.lap_completed.connect(_on_lap)
	_lap.visible = _is_loop   # a lap counter is meaningless on a point-to-point sprint

func _ready() -> void:
	layer = 50
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Speed — bottom-right, the big one.
	var speed_box := _panel(GOLD)
	speed_box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	speed_box.position = Vector2(-230, -140)
	root.add_child(speed_box)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	speed_box.add_child(col)
	_speed = _label("0", 68, SULPHUR)
	_speed.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(_speed)
	var kmh := _label("KM/H", 20, CREAM)
	kmh.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(kmh)

	# Timer — top-centre: current time big, best under it.
	var time_box := _panel(CARMINE)
	time_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	time_box.position = Vector2(-110, 16)
	root.add_child(time_box)
	var tcol := VBoxContainer.new()
	tcol.alignment = BoxContainer.ALIGNMENT_CENTER
	time_box.add_child(tcol)
	_time = _label("0:00.00", 40, CREAM)
	_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tcol.add_child(_time)
	_best = _label("BEST --:--", 18, GOLD)
	_best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tcol.add_child(_best)

	# Lap counter — top-left.
	var lap_box := _panel(GOLD)
	lap_box.set_anchors_preset(Control.PRESET_TOP_LEFT)
	lap_box.position = Vector2(16, 16)
	root.add_child(lap_box)
	_lap = _label("LAP 1/3", 28, SULPHUR)
	lap_box.add_child(_lap)

	# Position — top-right. Placeholder until AI rivals exist (code-ai-rival).
	var pos_box := _panel(GOLD)
	pos_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pos_box.position = Vector2(-150, 16)
	root.add_child(pos_box)
	var pos := _label("POS 1/1", 28, CREAM)
	pos_box.add_child(pos)

	# Split popup — under the timer, hidden until a gate fires.
	_split = _label("", 30, CREAM)
	_split.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_split.position = Vector2(-120, 108)
	_split.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_split.modulate.a = 0.0
	root.add_child(_split)

func _process(dt: float) -> void:
	if _car != null:
		_speed.text = str(roundi(absf(_car.get_forward_speed()) * 3.6))
	if _timing != null and _car != null:
		_time.text = _fmt(_timing.current_time(_car))
		var b := _timing.best_lap(_car)
		_best.text = "BEST " + (_fmt(b) if b < INF else "--:--")
		if _is_loop:
			var done: int = (_timing.laps_of(_car) as Array).size()
			_lap.text = "LAP %d/%d" % [mini(done + 1, _laps_total), _laps_total]
	if _split_ttl > 0.0:
		_split_ttl -= dt
		_split.modulate.a = clampf(_split_ttl / 0.8, 0.0, 1.0)   # hold, then fade over the last 0.8 s

func _on_gate(body: Node3D, index: int, split: float) -> void:
	if body != _car:
		return
	var line := "CP " + _fmt(split)
	var col := CREAM
	if _gate_best.has(index):
		var delta: float = split - _gate_best[index]
		line += "  %s%.2f" % ["+" if delta >= 0.0 else "-", absf(delta)]
		col = CARMINE if delta >= 0.0 else SAGE
		_gate_best[index] = minf(_gate_best[index], split)
	else:
		_gate_best[index] = split
	_split.text = line
	_split.add_theme_color_override("font_color", col)
	_split.modulate.a = 1.0   # show at once; _process fades it from here
	_split_ttl = 2.0

func _on_lap(body: Node3D, _t: float, _n: int, _best: bool) -> void:
	if body == _car:
		_gate_best.clear()   # splits are measured into the current lap, so best-per-gate resets each lap

# ---------- retro-chunky widgets ----------
func _panel(border: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.border_color = border
	sb.set_border_width_all(3)          # hard, blocky, no corner radius
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 8)   # heavy outline = the chunky read
	return l

func _fmt(t: float) -> String:
	if t < 0.0 or t == INF:
		return "0:00.00"
	var m := int(t) / 60
	var s := t - m * 60
	return "%d:%05.2f" % [m, s]
