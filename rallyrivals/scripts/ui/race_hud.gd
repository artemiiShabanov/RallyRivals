class_name RaceHud
extends CanvasLayer
## The in-race HUD (code-ui-hud / art-ui-hud-gfx / code-ui-scorebug), laid out as broadcast
## furniture over a live picture. Four zones, each answering one question:
##
##   top-left      RACE state — lap, total time, and the running order
##   top-right     the channel bug (stub art)
##   bottom-right  DRIVER state — avatar, speed, best lap. No panel: it floats clear of the road
##   bottom        a full-width strip that is EMPTY until something needs saying (splits, for now)
##
## Greys, not the menus' electric blue: the road has to stay the loudest thing on screen. Hard
## corners and the pixel font keep it in the same family as the rest of the UI.
##
## The order panel is built for ELEVEN drivers even though only the player exists until code-ai-rival
## lands: fixed width so it never reflows as names and gaps change, height following the row count,
## and the player's row highlighted so you find yourself instantly in a full field. Feed it with
## set_standings(); with no rivals it shows the player alone.
##
## Data only flows IN: get_forward_speed() for speed, RaceTiming for the clock/laps, gate_crossed
## for splits. The one thing it measures is the per-gate best (to colour a split green/red).

const ICONS := "res://assets/ui/"
const SAGE := Color(0.62, 0.88, 0.62)      # faster split
const CARMINE := Color(0.92, 0.42, 0.48)   # slower split
const CREAM := Color(0.95, 0.97, 1.0)
const MAX_ROWS := 11                       # the biggest field: a boss race is 9 regulars +
										   # the boss + you (docs/specs/field-matching.md)
const ORDER_W := 252                       # fixed width — rows must not reflow as gaps change
const EDGE := 22                           # screen margin
const SPEED_W := 84                        # room for THREE digits, so the meter never shifts as
										   # speed crosses 99 -> 100
const RULE_RED := Color(0.85, 0.18, 0.24)  # divides race state from the running order
const FALLBACK_TOP := 55.0                 # m/s assumed top speed when the car has no CarDef
const STRIP_HOLD := 2.0                    # s the bottom strip stays up after a message
const STRIP_H := 40                        # EXACT strip height; the driver block clears it
										   # ALWAYS, so nothing jumps when the strip comes and goes

var _car: VehicleController
var _timing: RaceTiming
var _is_loop := true
var _laps_total := 3

var _speed: Label
var _time: Label
var _best: Label
var _lap: Label
var _strip: Panel
var _strip_label: Label
var _strip_ttl := 0.0
var _order: VBoxContainer
var _gate_best := {}
var _bar: SpeedBar
var _type_icon: TextureRect

func bind(car: VehicleController, timing: RaceTiming, cps: TrackCheckpoints, laps_total: int,
		race_type := "circuit") -> void:
	_car = car
	_timing = timing
	_is_loop = cps.loop
	_laps_total = laps_total
	if timing != null:
		timing.gate_crossed.connect(_on_gate)
		timing.lap_completed.connect(_on_lap)
	_lap.visible = _is_loop     # a lap counter is meaningless on a point-to-point sprint
	var icon := "res://assets/ui/race_%s.png" % race_type
	if ResourceLoader.exists(icon):
		_type_icon.texture = load(icon)
	set_standings([{"name": "YOU", "time": "", "player": true}])

## Replace the running order. Each row: {name: String, time: String, player: bool}. Positions are
## implied by array order. Rows beyond MAX_ROWS are dropped rather than silently overflowing the
## panel — the field is capped by design, not by accident.
func set_standings(rows: Array) -> void:
	for c in _order.get_children():
		c.queue_free()
	for i in mini(rows.size(), MAX_ROWS):
		var r: Dictionary = rows[i]
		var row := PanelContainer.new()
		row.theme_type_variation = "HudRowHot" if r.get("player", false) else "HudRowPlain"
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		row.add_child(line)
		var pos := _label(str(i + 1), "HudRow")
		pos.custom_minimum_size.x = 18
		line.add_child(pos)
		var who := _label(str(r.get("name", "—")), "HudRow")
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL   # pushes the time to the right edge
		line.add_child(who)
		line.add_child(_label(str(r.get("time", "")), "HudRow"))
		_order.add_child(row)

func _ready() -> void:
	layer = 50
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# ---- top-left: race state ----
	var race := PanelContainer.new()
	race.theme_type_variation = "HudPanel"
	race.mouse_filter = Control.MOUSE_FILTER_IGNORE
	race.set_anchors_preset(Control.PRESET_TOP_LEFT)
	race.offset_left = EDGE
	race.offset_top = EDGE
	race.custom_minimum_size.x = ORDER_W
	root.add_child(race)

	var rcol := VBoxContainer.new()
	rcol.add_theme_constant_override("separation", 6)
	race.add_child(rcol)

	# One line: format badge, lap, then the clock pushed to the far edge. Lap and clock share a face
	# (HudTag/HudTimer are the same size) so the row reads as one statement.
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	rcol.add_child(line)
	_type_icon = TextureRect.new()
	_type_icon.custom_minimum_size = Vector2(22, 22)
	_type_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_type_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_type_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_type_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(_type_icon)
	_lap = _label("LAP 1/3", "HudTag")
	line.add_child(_lap)
	var push := Control.new()
	push.size_flags_horizontal = Control.SIZE_EXPAND_FILL   # justifies the clock to the right edge
	push.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(push)
	_time = _label("0:00.00", "HudTimer")
	line.add_child(_time)

	var rule := ColorRect.new()
	rule.color = RULE_RED
	rule.custom_minimum_size.y = 2
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rcol.add_child(rule)

	_order = VBoxContainer.new()
	_order.add_theme_constant_override("separation", 1)
	rcol.add_child(_order)

	# ---- top-right: channel bug ----
	var logo := TextureRect.new()
	logo.texture = load(ICONS + "channel_logo.png")
	logo.custom_minimum_size = Vector2(96, 36)
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	logo.modulate.a = 0.45        # a bug sits quietly in the corner; it is branding, not data
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	logo.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	logo.offset_right = -EDGE
	logo.offset_top = EDGE
	root.add_child(logo)

	# ---- bottom-right: driver state, no panel behind it ----
	var driver := VBoxContainer.new()
	driver.add_theme_constant_override("separation", 4)
	driver.alignment = BoxContainer.ALIGNMENT_END
	driver.mouse_filter = Control.MOUSE_FILTER_IGNORE
	driver.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	driver.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	driver.grow_vertical = Control.GROW_DIRECTION_BEGIN
	driver.offset_right = -EDGE
	driver.offset_bottom = -(EDGE + STRIP_H)   # clear of the strip's reserved band
	root.add_child(driver)

	# Avatar, numerals and unit all sit on ONE baseline — SHRINK_END on each, so the row bottom-
	# aligns regardless of their wildly different heights.
	var drow := HBoxContainer.new()
	drow.alignment = BoxContainer.ALIGNMENT_END
	drow.add_theme_constant_override("separation", 10)
	driver.add_child(drow)
	var avatar := TextureRect.new()
	avatar.texture = load(ICONS + "avatar_default.png")
	avatar.custom_minimum_size = Vector2(38, 38)
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	avatar.size_flags_vertical = Control.SIZE_SHRINK_END
	drow.add_child(avatar)
	_speed = _label("0", "HudValue")
	_speed.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_speed.custom_minimum_size.x = SPEED_W     # fixed 3-digit width: nothing shifts at 99 -> 100
	_speed.size_flags_vertical = Control.SIZE_SHRINK_END
	drow.add_child(_speed)
	var unit := _label("KM/H", "HudUnit")
	unit.size_flags_vertical = Control.SIZE_SHRINK_END
	drow.add_child(unit)

	# Meter column: the bar sets the width, and BEST centres itself across that same width.
	var meter := VBoxContainer.new()
	meter.add_theme_constant_override("separation", 2)
	meter.size_flags_horizontal = Control.SIZE_SHRINK_END
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	driver.add_child(meter)
	_bar = SpeedBar.new()
	meter.add_child(_bar)
	_best = _label("BEST --:--", "HudBest")
	_best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_best.size_flags_horizontal = Control.SIZE_FILL
	meter.add_child(_best)

	# ---- bottom: full-width strip, hidden until it has something to say ----
	# A Panel, not a PanelContainer: the container sized itself to the font's line metrics and came
	# out 84 px tall, which is not a thin strip. This pins the height and centres the text inside it.
	_strip = Panel.new()
	_strip.theme_type_variation = "HudStrip"
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strip.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_strip.offset_top = -STRIP_H
	_strip.offset_bottom = 0
	_strip.visible = false
	root.add_child(_strip)
	_strip_label = _label("", "HudSplit")
	_strip_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_strip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_strip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_strip_label.clip_text = true
	_strip.add_child(_strip_label)

func _process(dt: float) -> void:
	if _car != null:
		_speed.text = str(roundi(absf(_car.get_forward_speed()) * 3.6))
		var top: float = _car.max_speed if _car.max_speed < INF else FALLBACK_TOP
		_bar.value = absf(_car.get_forward_speed()) / top
	if _timing != null and _car != null:
		_time.text = _fmt(_timing.current_time(_car))
		var b := _timing.best_lap(_car)
		_best.text = "BEST " + (_fmt(b) if b < INF else "--:--")
		if _is_loop:
			var done: int = (_timing.laps_of(_car) as Array).size()
			_lap.text = "LAP %d/%d" % [mini(done + 1, _laps_total), _laps_total]
	if _strip_ttl > 0.0:
		_strip_ttl -= dt
		_strip.modulate.a = clampf(_strip_ttl / 0.6, 0.0, 1.0)
		if _strip_ttl <= 0.0:
			_strip.visible = false

## Put a message on the bottom strip. It shows itself, holds, then fades out — the strip is only
## ever on screen while it is carrying something.
func show_strip(text: String, col: Color) -> void:
	_strip_label.text = text
	_strip_label.add_theme_color_override("font_color", col)
	_strip.modulate.a = 1.0
	_strip.visible = true
	_strip_ttl = STRIP_HOLD

func _on_gate(body: Node3D, index: int, split: float) -> void:
	if body != _car:
		return
	var line := "CP %d      %s" % [index + 1, _fmt(split)]
	var col := CREAM
	if _gate_best.has(index):
		var delta: float = split - _gate_best[index]
		line += "      %s%.2f" % ["+" if delta >= 0.0 else "-", absf(delta)]
		col = CARMINE if delta >= 0.0 else SAGE
		_gate_best[index] = minf(_gate_best[index], split)
	else:
		_gate_best[index] = split
	show_strip(line, col)

func _on_lap(body: Node3D, _t: float, _n: int, _best: bool) -> void:
	if body == _car:
		_gate_best.clear()

# ---------- widgets (styling comes from the theme) ----------
func _label(text: String, variation: String) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _gap(px: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = px
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

func _fmt(t: float) -> String:
	if t < 0.0 or t == INF:
		return "0:00.00"
	var m := int(t) / 60
	var s := t - m * 60
	return "%d:%05.2f" % [m, s]
