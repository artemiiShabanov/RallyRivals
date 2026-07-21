class_name RaceHud
extends CanvasLayer
## The in-race HUD (code-ui-hud): speed, running time + best, lap counter, a position placeholder,
## and a checkpoint split popup. Styling lives in the shared theme (art-ui-theme) — labels use its
## type variations (HudValue/HudTimer/…) and panels its HudPanel styleboxes, so the look is set in
## one place (assets/ui/theme.tres) and matches the rest of the UI. Built in code like the debug menu.
##
## Data only flows IN: get_forward_speed() for speed, RaceTiming for the clock/laps, gate_crossed
## for splits. The one thing it measures is the per-gate best (to colour a split green/red).

const ICONS := "res://assets/ui/icons/"
const SAGE := Color(0.55, 0.80, 0.55)   # faster split
const CARMINE := Color("a10b2b")        # slower split
const CREAM := Color(0.95, 0.92, 0.85)

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
var _gate_best := {}

func bind(car: VehicleController, timing: RaceTiming, cps: TrackCheckpoints, laps_total: int) -> void:
	_car = car
	_timing = timing
	_is_loop = cps.loop
	_laps_total = laps_total
	if timing != null:
		timing.gate_crossed.connect(_on_gate)
		timing.lap_completed.connect(_on_lap)
	_lap.get_parent().visible = _is_loop   # lap counter is meaningless on a point-to-point sprint

func _ready() -> void:
	layer = 50
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Speed — bottom-right, the big one, with its icon.
	_speed = _label("0", "HudValue")
	var speed_box := _panel("HudPanel", "speed", _speed, "KM/H")
	speed_box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	speed_box.position = Vector2(-250, -150)
	root.add_child(speed_box)

	# Timer — top-centre: current time + best, carmine border.
	var tcol := VBoxContainer.new()
	tcol.alignment = BoxContainer.ALIGNMENT_CENTER
	_time = _label("0:00.00", "HudTimer")
	_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tcol.add_child(_time)
	_best = _label("BEST --:--", "HudBest")
	_best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tcol.add_child(_best)
	var time_box := _icon_panel("HudPanelHot", "timer", tcol)
	time_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	time_box.position = Vector2(-120, 16)
	root.add_child(time_box)

	# Lap counter — top-left.
	_lap = _label("LAP 1/3", "HudTag")
	var lap_box := _icon_panel("HudPanel", "lap", _lap)
	lap_box.set_anchors_preset(Control.PRESET_TOP_LEFT)
	lap_box.position = Vector2(16, 16)
	root.add_child(lap_box)

	# Position — top-right (placeholder until code-ai-rival).
	var pos := _label("POS 1/1", "HudTag")
	var pos_box := _icon_panel("HudPanel", "trophy", pos)
	pos_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pos_box.position = Vector2(-170, 16)
	root.add_child(pos_box)

	# Split popup — under the timer.
	_split = _label("", "HudSplit")
	_split.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_split.position = Vector2(-130, 118)
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
		_split.modulate.a = clampf(_split_ttl / 0.8, 0.0, 1.0)

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
	return l

# Icon + a single value label, side by side, in a panel.
func _panel(panel_var: String, icon: String, value: Label, unit: String) -> PanelContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(_tex(icon, 40))
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(value)
	var u := _label(unit, "HudUnit")
	u.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(u)
	row.add_child(col)
	return _wrap(panel_var, row)

# Icon + arbitrary content.
func _icon_panel(panel_var: String, icon: String, content: Control) -> PanelContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(_tex(icon, 32))
	row.add_child(content)
	return _wrap(panel_var, row)

func _wrap(panel_var: String, content: Control) -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = panel_var
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(content)
	return p

func _tex(icon: String, px: int) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load(ICONS + icon + ".png")
	t.custom_minimum_size = Vector2(px, px)
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # crisp pixels, not blurred
	return t

func _fmt(t: float) -> String:
	if t < 0.0 or t == INF:
		return "0:00.00"
	var m := int(t) / 60
	var s := t - m * 60
	return "%d:%05.2f" % [m, s]
