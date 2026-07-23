class_name GarageScreen
extends MenuScreen
## Garage (code-ui-garage): the cars you own. Move through the list on the left and the detail panel
## (3D turntable + stat bars) follows your focus; SELECT makes the shown car your current one (the
## one you take to the grid). The current car carries a ● marker. Reached from the hub GARAGE tile
## (BACK returns there), or from pre-race as the car picker (return_to routes BACK to pre-race).

static var return_to := ""

var _view: CarView
var _bars: StatBars
var _name: Label
var _sub: Label
var _select: Button
var _list: VBoxContainer
var _buttons: Dictionary = {}    # car id -> its list Button (for focus)
var _shown: CarDef               # the car in the detail panel

func _build(col: VBoxContainer) -> void:
	col.add_child(heading("GARAGE"))
	col.add_child(heading(_wallet_line(), "OsdDim"))
	col.add_child(spacer(12))

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 40)
	col.add_child(body)

	# left — owned car list (scrolls once the garage fills out)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(230, 300)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.follow_focus = true
	body.add_child(sc)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_list.size_flags_horizontal = SIZE_EXPAND_FILL
	sc.add_child(_list)

	# right — name/class, then preview beside the stat bars (keeps the panel short)
	var detail := VBoxContainer.new()
	detail.add_theme_constant_override("separation", 6)
	body.add_child(detail)
	_name = heading("")
	detail.add_child(_name)
	_sub = heading("", "OsdDim")
	detail.add_child(_sub)
	detail.add_child(spacer(6))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	detail.add_child(row)
	_view = CarView.new()
	_view.custom_minimum_size = Vector2(320, 240)
	row.add_child(_view)
	_bars = StatBars.new()
	_bars.size_flags_vertical = SIZE_SHRINK_CENTER
	row.add_child(_bars)

	col.add_child(spacer(14))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	col.add_child(actions)
	_select = menu_button("SELECT")
	_select.pressed.connect(_on_select)
	actions.add_child(_select)
	var back := menu_button("BACK", "ui_click")
	back.pressed.connect(_leave)
	actions.add_child(back)

	_rebuild_list()
	var start := Cars.by_id(Save.active.current_car)
	if start == null and not Cars.owned().is_empty():
		start = Cars.owned()[0]
	_show(start)
	_focus_car(start)   # land focus on the shown car so highlight and preview agree

func _on_cancel() -> void:
	_leave()

## Return to whoever opened the garage — pre-race when it's the car picker, else the hub.
func _leave() -> void:
	var dest := return_to if return_to != "" else Routes.CAREER_HUB
	return_to = ""
	Flow.goto(dest)

func _rebuild_list() -> void:
	for c in _list.get_children():
		c.queue_free()
	_buttons = {}
	var current := Save.active.current_car if Save.active != null else ""
	for d in Cars.owned():
		var mark := "●  " if d.id == current else "    "
		var b := menu_button("%s%s   %s" % [mark, d.display_name.to_upper(), d.car_class])
		b.custom_minimum_size.x = 214
		b.focus_entered.connect(_show.bind(d))   # preview follows focus (keyboard + hover)
		b.pressed.connect(_show.bind(d))
		_list.add_child(b)
		_buttons[d.id] = b

func _focus_car(def: CarDef) -> void:
	if def != null and _buttons.has(def.id):
		_buttons[def.id].grab_focus()

## Fill the detail panel from a CarDef and update the SELECT button's state.
func _show(def: CarDef) -> void:
	_shown = def
	_view.set_car(def)
	_bars.set_car(def)
	_name.text = def.display_name.to_upper() if def != null else "—"
	_sub.text = "CLASS %s  ·  %s" % [def.car_class, def.brand.to_upper()] if def != null else ""
	var is_current := def != null and Save.active != null and def.id == Save.active.current_car
	_select.disabled = is_current
	_select.text = "SELECTED" if is_current else "SELECT"

func _on_select() -> void:
	if _shown == null:
		return
	Save.select_car(_shown.id)
	_rebuild_list()
	_show(_shown)
	_focus_car(_shown)

func _wallet_line() -> String:
	return "$%d  ·  CP %d" % [Save.active.money, Save.active.cp] if Save.active != null else ""
