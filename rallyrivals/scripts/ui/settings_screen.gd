extends MenuScreen
## Settings + input remap (code-ui-settings). Two pages in one screen so neither list overflows:
##   MAIN     — audio bus sliders, VHS filter intensity (0 = off), fullscreen, reset, back
##   CONTROLS — one row per remappable action; activating a row captures the next key (Esc cancels)
## All values write straight through to the Settings autoload, which applies them live and persists
## on the way out. `return_to` lets a caller (e.g. the pause menu) route BACK somewhere else.

static var return_to := ""

enum Page {MAIN, CONTROLS}

# Every row on this screen — slider rows, toggles, buttons — is exactly ROW_W wide so the right
# edge lines up down the whole list. The slider takes whatever the label and value columns leave.
const ROW_W := 600
const LABEL_W := 200
const VALUE_W := 70
const SEP := 14
const SLIDER_W := ROW_W - LABEL_W - VALUE_W - SEP * 2

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

## Key capture runs in _input — ahead of the GUI. The row being rebound holds focus, so Space/Enter
## would otherwise be eaten by that focused button as ui_accept and never reach us, making those two
## keys impossible to bind.
func _input(event: InputEvent) -> void:
	if _capturing == "":
		return
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

func _unhandled_input(event: InputEvent) -> void:
	if _capturing != "":
		return                     # swallow everything else while awaiting a key
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

## Rebuilds the page. Every re-render (toggle, rebind, page switch) destroys the focused control, so
## the row's stable focus_key is remembered and re-focused afterwards — otherwise keyboard users get
## thrown back to the top of the list every time they flip a setting.
func _render() -> void:
	var key := ""
	var owner := get_viewport().gui_get_focus_owner()
	if owner != null and owner.has_meta("focus_key"):
		key = str(owner.get_meta("focus_key"))

	for c in _col.get_children():
		_col.remove_child(c)      # remove now (not just queue_free) so layout + focus settle cleanly
		c.queue_free()

	if _page == Page.MAIN:
		_render_main()
	else:
		_render_controls()

	_restore_focus(key)

func _restore_focus(key: String) -> void:
	if key != "":
		var target := _find_by_key(_col, key)
		if target != null:
			target.grab_focus()
			return
	focus_first(_col)             # page switched (key is gone) — fall back to the first row

func _find_by_key(root: Node, key: String) -> Control:
	for c in root.get_children():
		if c is Control and c.has_meta("focus_key") and str(c.get_meta("focus_key")) == key:
			return c as Control
		var found := _find_by_key(c, key)
		if found != null:
			return found
	return null

func _render_main() -> void:
	_col.add_child(heading("SETTINGS"))
	
	_col.add_child(spacer(10))

	var controls := _row_button("CONTROLS  ▸")
	controls.pressed.connect(func() -> void:
		_page = Page.CONTROLS
		_render())
	_col.add_child(controls)
	
	_col.add_child(spacer(10))

	_col.add_child(heading("AUDIO", "OsdDim"))
	for bus in Settings.BUSES:
		_col.add_child(_slider_row(bus.to_upper(), Settings.get_bus(bus) * 100.0,
			func(v: float) -> void: Settings.set_bus(bus, v / 100.0)))

	_col.add_child(spacer(10))
	
	_col.add_child(heading("VIDEO", "OsdDim"))
	_col.add_child(_toggle_row("FULLSCREEN", Settings.get_fullscreen(),
		func(on: bool) -> void: Settings.set_fullscreen(on)))
	_col.add_child(_slider_row("VHS FILTER", Settings.get_vhs() * 100.0,
		func(v: float) -> void: Settings.set_vhs(v / 100.0)))
	
	_col.add_child(spacer(10))

	var reset := _row_button("RESET DEFAULTS", "ui_click")
	reset.pressed.connect(func() -> void:
		Settings.reset_defaults()
		_render())
	_col.add_child(reset)

	var back := _row_button("BACK", "ui_click")
	back.pressed.connect(_leave)
	_col.add_child(back)


func _render_controls() -> void:
	_col.add_child(heading("CONTROLS"))
	_col.add_child(heading("select a row, then press a key  ·  esc cancels", "OsdDim"))
	_col.add_child(spacer(6))

	for action in Settings.REMAPPABLE:
		var label: String = ACTION_LABELS.get(action, action.to_upper())
		var bound := "PRESS A KEY…" if _capturing == action else Settings.binding_label(action)
		var b := _row_button("%-18s %s" % [label, bound], "ui_confirm", "act:" + action)
		b.pressed.connect(func() -> void:
			_capturing = action
			_render())
		_col.add_child(b)

	_col.add_child(spacer(6))
	var back := _row_button("BACK", "ui_click", "back_controls")
	back.pressed.connect(func() -> void:
		_page = Page.MAIN
		_render())
	_col.add_child(back)

## label + slider, left-aligned. Feedback cue fires on release so dragging doesn't machine-gun it.
func _slider_row(text: String, value: float, on_change: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", SEP)
	row.size_flags_horizontal = SIZE_SHRINK_BEGIN
	row.custom_minimum_size.x = ROW_W

	var l := Label.new()
	l.text = text
	l.custom_minimum_size.x = LABEL_W
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(l)

	var s := HSlider.new()
	s.min_value = 0
	s.max_value = 100
	s.step = 5
	s.value = value
	s.custom_minimum_size = Vector2(SLIDER_W, 54)
	s.set_meta("focus_key", text)
	s.value_changed.connect(func(v: float) -> void:
		on_change.call(v)
		_val(row).text = "%d%%" % roundi(v))
	s.drag_ended.connect(func(_changed: bool) -> void: play_cue("ui_move"))
	s.focus_entered.connect(func() -> void: play_cue("ui_move"))
	row.add_child(s)

	var v := Label.new()
	v.name = "Val"
	v.text = "%d%%" % roundi(value)
	v.custom_minimum_size.x = VALUE_W
	row.add_child(v)
	return row

## label + a segmented OFF|ON switch, occupying the same column as the sliders so the row grid holds.
## The active half inverts to the white OSD cursor — the same "selected" language as the menu items.
func _toggle_row(text: String, value: bool, on_change: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", SEP)
	row.size_flags_horizontal = SIZE_SHRINK_BEGIN
	row.custom_minimum_size.x = ROW_W

	var l := Label.new()
	l.text = text
	l.custom_minimum_size.x = LABEL_W
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(l)

	# A toggle-mode Button carries the focus/click/keyboard behaviour; its own box is stripped so the
	# two segments below are what you actually see.
	var sw := Button.new()
	sw.toggle_mode = true
	sw.button_pressed = value
	sw.custom_minimum_size = Vector2(SLIDER_W, 30)
	sw.size_flags_horizontal = SIZE_SHRINK_BEGIN
	sw.set_meta("focus_key", text)
	for s in ["normal", "hover", "pressed", "disabled"]:
		sw.add_theme_stylebox_override(s, _box(Color(0, 0, 0, 0), 0))
	sw.add_theme_stylebox_override("focus", _box(Color(0, 0, 0, 0), 2))
	wire_button(sw, "ui_click")
	sw.toggled.connect(func(on: bool) -> void:
		on_change.call(on)
		_render())
	row.add_child(sw)

	var seg := HBoxContainer.new()
	seg.add_theme_constant_override("separation", 4)
	seg.set_anchors_preset(Control.PRESET_FULL_RECT)
	seg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seg.add_child(_segment("OFF", not value))
	seg.add_child(_segment("ON", value))
	sw.add_child(seg)

	var pad := Control.new()
	pad.custom_minimum_size.x = VALUE_W     # keeps the right edge level with the slider rows
	row.add_child(pad)
	return row

func _segment(text: String, active: bool) -> PanelContainer:
	var p := PanelContainer.new()
	p.size_flags_horizontal = SIZE_EXPAND_FILL
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", _box(WHITE if active else BLUE_DK, 0))
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", SEL_FG if active else WHITE)
	l.add_theme_constant_override("outline_size", 0)
	p.add_child(l)
	return p

func _box(bg: Color, border: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(0)
	sb.set_border_width_all(border)
	sb.border_color = WHITE
	sb.content_margin_left = 0
	sb.content_margin_right = 0
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	return sb

## A full-width row button — same ROW_W as the slider rows, so the list has one right edge.
## `key` must stay stable across re-renders (a row's visible text can change, e.g. a binding label).
func _row_button(text: String, cue := "ui_confirm", key := "") -> Button:
	var b := menu_button(text, cue)
	b.custom_minimum_size.x = ROW_W
	b.set_meta("focus_key", key if key != "" else text)
	return b

func _val(row: HBoxContainer) -> Label:
	return row.get_node("Val") as Label
