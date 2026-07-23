extends MenuScreen
## Settings + input remap (code-ui-settings). Two pages in one screen so neither list overflows:
##   MAIN     — audio bus sliders, VHS filter intensity (0 = off), fullscreen, reset, back
##   CONTROLS — one row per remappable action; activating a row captures the next key (Esc cancels)
## All values write straight through to the Settings autoload, which applies them live and persists
## on the way out. `return_to` lets a caller (e.g. the pause menu) route BACK somewhere else.

static var return_to := ""

enum Page {MAIN, CONTROLS}

const ACTION_LABELS := {
	"accelerate": "ACCELERATE",
	"brake_reverse": "BRAKE / REVERSE",
	"steer_left": "STEER LEFT",
	"steer_right": "STEER RIGHT",
	"handbrake": "HANDBRAKE",
	"reset_car": "RESET CAR",
	"pause": "PAUSE",
}

var _col: VBoxContainer
var _page := Page.MAIN
var _capturing := ""      ## action currently awaiting a key press

func _build(col: VBoxContainer) -> void:
	col.add_theme_constant_override("separation", 8)
	_col = col
	_render()

func _scrolls() -> bool:
	return true

func _unhandled_input(event: InputEvent) -> void:
	if _capturing != "":
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE:
				_capturing = ""
				play_cue("ui_click")
			else:
				Settings.rebind(_capturing, event)
				_capturing = ""
				play_cue("ui_confirm")
			_render()
			get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)

func _on_cancel() -> void:
	if _page == Page.CONTROLS:
		_page = Page.MAIN
		_render()
	else:
		_leave()

func _leave() -> void:
	Settings.save_all()
	Flow.goto(return_to if return_to != "" else Routes.TITLE)

func _render() -> void:
	for c in _col.get_children():
		c.queue_free()
	if _page == Page.MAIN:
		_render_main()
	else:
		_render_controls()

func _render_main() -> void:
	_col.add_child(heading("SETTINGS"))
	_col.add_child(spacer(6))

	_col.add_child(heading("AUDIO", "OsdDim"))
	for bus in Settings.BUSES:
		_col.add_child(_slider_row(bus.to_upper(), Settings.get_bus(bus) * 100.0,
			func(v: float) -> void: Settings.set_bus(bus, v / 100.0)))

	_col.add_child(spacer(6))
	_col.add_child(heading("VIDEO", "OsdDim"))
	_col.add_child(_slider_row("VHS FILTER", Settings.get_vhs() * 100.0,
		func(v: float) -> void: Settings.set_vhs(v / 100.0)))

	# A text toggle rather than a CheckBox: the theme is borderless-flat and CheckBox would fall back
	# to Godot's default styling, breaking the OSD list look.
	var fs := menu_button("FULLSCREEN        %s" % ("ON" if Settings.get_fullscreen() else "OFF"), "ui_click")
	fs.custom_minimum_size.x = 460
	fs.pressed.connect(func() -> void:
		Settings.set_fullscreen(not Settings.get_fullscreen())
		_render())
	_col.add_child(fs)

	_col.add_child(spacer(6))
	var controls := menu_button("CONTROLS  ▸")
	controls.pressed.connect(func() -> void:
		_page = Page.CONTROLS
		_render())
	_col.add_child(controls)

	var reset := menu_button("RESET DEFAULTS", "ui_click")
	reset.pressed.connect(func() -> void:
		Settings.reset_defaults()
		_render())
	_col.add_child(reset)

	var back := menu_button("BACK", "ui_click")
	back.pressed.connect(_leave)
	_col.add_child(back)

func _render_controls() -> void:
	_col.add_child(heading("CONTROLS"))
	_col.add_child(heading("select a row, then press a key  ·  esc cancels", "OsdDim"))
	_col.add_child(spacer(6))

	for action in Settings.REMAPPABLE:
		var label: String = ACTION_LABELS.get(action, action.to_upper())
		var bound := "PRESS A KEY…" if _capturing == action else Settings.binding_label(action)
		var b := menu_button("%-18s %s" % [label, bound])
		b.custom_minimum_size.x = 460
		b.pressed.connect(func() -> void:
			_capturing = action
			_render())
		_col.add_child(b)

	_col.add_child(spacer(6))
	var back := menu_button("BACK", "ui_click")
	back.pressed.connect(func() -> void:
		_page = Page.MAIN
		_render())
	_col.add_child(back)

## label + slider, left-aligned. Feedback cue fires on release so dragging doesn't machine-gun it.
func _slider_row(text: String, value: float, on_change: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.size_flags_horizontal = SIZE_SHRINK_BEGIN

	var l := Label.new()
	l.text = text
	l.custom_minimum_size.x = 200
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(l)

	var s := HSlider.new()
	s.min_value = 0
	s.max_value = 100
	s.step = 5
	s.value = value
	s.custom_minimum_size = Vector2(300, 24)
	s.value_changed.connect(func(v: float) -> void:
		on_change.call(v)
		_val(row).text = "%d%%" % roundi(v))
	s.drag_ended.connect(func(_changed: bool) -> void: play_cue("ui_move"))
	s.focus_entered.connect(func() -> void: play_cue("ui_move"))
	row.add_child(s)

	var v := Label.new()
	v.name = "Val"
	v.text = "%d%%" % roundi(value)
	v.custom_minimum_size.x = 70
	row.add_child(v)
	return row

func _val(row: HBoxContainer) -> Label:
	return row.get_node("Val") as Label
