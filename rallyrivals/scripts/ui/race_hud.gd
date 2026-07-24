class_name RaceHud
extends CanvasLayer
## The in-race HUD (code-ui-hud / art-ui-hud-gfx / code-ui-scorebug), built as a BROADCAST SCOREBUG:
## one unified bar across the top carrying lap + running time + best, and a separate speed cluster
## down near the car where your eyes already are. That beats scattering four panels into four
## corners — the eye has one place to check, not four.
##
## It shares the menus' VHS register rather than sitting in its own telemetry look: the recessed
## blue field at partial alpha, hard edges, the pixel font, a bright top rule on the bar. One visual
## language across sky, menus and HUD.
##
## The speed bar is the SAME segmented-pip language as the garage stat bars (white filled, recessed
## blue empty), so a player reads it without being taught. It exists so speed is legible
## peripherally — you feel it without reading the digits.
##
## Data only flows IN: get_forward_speed() for speed, RaceTiming for the clock/laps, gate_crossed
## for splits. The one thing it measures is the per-gate best (to colour a split green/red).
## There is deliberately no position readout: it would be a hardcoded "1/1" until code-ai-rival
## lands, and a HUD that lies is worse than one that omits.

const SAGE := Color(0.55, 0.80, 0.55)      # faster split
const CARMINE := Color(0.85, 0.25, 0.35)   # slower split — lifted off the menu carmine so it reads on blue
const PIPS := 16                           # segments in the speed bar
const PIP_FILLED := Color(0.95, 0.97, 1.0)
const PIP_EMPTY := Color(0.05, 0.11, 0.60)
const EDGE := 26                            # screen margin for the speed cluster
const TOP_GAP := 18                         # gap above the scorebug so its top rule reads
const FALLBACK_TOP := 55.0                  # m/s assumed top speed when the car has no CarDef

var _car: VehicleController
var _timing: RaceTiming
var _is_loop := true
var _laps_total := 3

var _speed: Label
var _time: Label
var _best: Label
var _lap: Label
var _lap_cell: Control
var _lap_rule: ColorRect
var _split: Label
var _split_ttl := 0.0
var _gate_best := {}
var _pips: Array[ColorRect] = []

func bind(car: VehicleController, timing: RaceTiming, cps: TrackCheckpoints, laps_total: int) -> void:
	_car = car
	_timing = timing
	_is_loop = cps.loop
	_laps_total = laps_total
	if timing != null:
		timing.gate_crossed.connect(_on_gate)
		timing.lap_completed.connect(_on_lap)
	# A lap counter is meaningless on a point-to-point sprint — drop the cell AND its divider so the
	# bar closes up cleanly instead of leaving a gap.
	_lap_cell.visible = _is_loop
	_lap_rule.visible = _is_loop

func _ready() -> void:
	layer = 50
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# ---- scorebug: one bar, centred at the top ----
	var top := CenterContainer.new()          # centres the bar without needing to know its width
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_top = TOP_GAP                  # let the bar float clear of the screen edge
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)

	var bar := PanelContainer.new()
	bar.theme_type_variation = "HudBar"
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(bar)

	var cells := HBoxContainer.new()
	cells.add_theme_constant_override("separation", 0)
	bar.add_child(cells)

	_lap = _label("LAP 1/3", "HudTag")
	_lap_cell = _cell(_lap)
	cells.add_child(_lap_cell)
	_lap_rule = _rule()
	cells.add_child(_lap_rule)

	_time = _label("0:00.00", "HudTimer")
	cells.add_child(_cell(_time))
	cells.add_child(_rule())

	_best = _label("BEST --:--", "HudBest")
	cells.add_child(_cell(_best))

	# ---- split popup, directly under the bar so it reads as part of it ----
	var split_row := CenterContainer.new()
	split_row.set_anchors_preset(Control.PRESET_TOP_WIDE)
	split_row.offset_top = TOP_GAP + 96
	split_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(split_row)
	_split = _label("", "HudSplit")
	_split.modulate.a = 0.0
	split_row.add_child(_split)

	# ---- speed cluster, bottom-right, near the car ----
	var speed_panel := PanelContainer.new()
	speed_panel.theme_type_variation = "HudPanel"
	speed_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speed_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	speed_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN   # size from content, pinned to the corner
	speed_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	speed_panel.offset_right = -EDGE
	speed_panel.offset_bottom = -EDGE
	root.add_child(speed_panel)

	var scol := VBoxContainer.new()
	scol.add_theme_constant_override("separation", 6)
	speed_panel.add_child(scol)

	var srow := HBoxContainer.new()
	srow.alignment = BoxContainer.ALIGNMENT_END
	srow.add_theme_constant_override("separation", 8)
	scol.add_child(srow)
	_speed = _label("0", "HudValue")
	_speed.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	srow.add_child(_speed)
	var unit := _label("KM/H", "HudUnit")
	unit.size_flags_vertical = Control.SIZE_SHRINK_END          # sits on the numerals' baseline
	srow.add_child(unit)

	var barrow := HBoxContainer.new()
	barrow.add_theme_constant_override("separation", 3)
	scol.add_child(barrow)
	for _i in PIPS:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(14, 12)
		pip.color = PIP_EMPTY
		barrow.add_child(pip)
		_pips.append(pip)

func _process(dt: float) -> void:
	if _car != null:
		var kmh := absf(_car.get_forward_speed()) * 3.6
		_speed.text = str(roundi(kmh))
		var top: float = _car.max_speed if _car.max_speed < INF else FALLBACK_TOP
		var lit := int(round(clampf(absf(_car.get_forward_speed()) / top, 0.0, 1.0) * PIPS))
		for i in _pips.size():
			_pips[i].color = PIP_FILLED if i < lit else PIP_EMPTY
	if _timing != null and _car != null:
		_time.text = _fmt(_timing.current_time(_car))
		var b := _timing.best_lap(_car)
		_best.text = "BEST " + (_fmt(b) if b < INF else "--:--")
		if _is_loop:
			var done: int = (_timing.laps_of(_car) as Array).size()
			_lap.text = "LAP %d/%d" % [mini(done + 1, _laps_total), _laps_total]
	if _split_ttl > 0.0:
		_split_ttl -= dt
		_split.modulate.a = clampf(_split_ttl / 0.8, 0.0, 1.0)

func _on_gate(body: Node3D, index: int, split: float) -> void:
	if body != _car:
		return
	var line := "CP " + _fmt(split)
	var col := PIP_FILLED
	if _gate_best.has(index):
		var delta: float = split - _gate_best[index]
		line += "   %s%.2f" % ["+" if delta >= 0.0 else "-", absf(delta)]
		col = CARMINE if delta >= 0.0 else SAGE
		_gate_best[index] = minf(_gate_best[index], split)
	else:
		_gate_best[index] = split
	_split.text = line
	_split.add_theme_color_override("font_color", col)
	_split.modulate.a = 1.0
	_split_ttl = 2.0

func _on_lap(body: Node3D, _t: float, _n: int, _best: bool) -> void:
	if body == _car:
		_gate_best.clear()

# ---------- widgets (styling comes from the theme) ----------
func _label(text: String, variation: String) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l

## One cell of the scorebug: content with breathing room, vertically centred so a small label and
## the big clock sit on the same optical line.
func _cell(content: Control) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 20)
	m.add_theme_constant_override("margin_right", 20)
	m.add_theme_constant_override("margin_top", 6)
	m.add_theme_constant_override("margin_bottom", 6)
	content.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	m.add_child(content)
	return m

## Hard divider between cells — the bar reads as segments, not one run-on strip.
func _rule() -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0.95, 0.97, 1.0, 0.35)
	r.custom_minimum_size = Vector2(2, 0)
	r.size_flags_vertical = Control.SIZE_FILL
	return r

func _fmt(t: float) -> String:
	if t < 0.0 or t == INF:
		return "0:00.00"
	var m := int(t) / 60
	var s := t - m * 60
	return "%d:%05.2f" % [m, s]
