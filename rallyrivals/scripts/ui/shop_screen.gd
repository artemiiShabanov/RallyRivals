extends MenuScreen
## Car shop (code-ui-shop): every car you can buy (pink-slip trophies excluded), price-gated. Move
## through the list and the detail panel (3D turntable + stat bars + price) follows your focus; BUY
## spends the price and moves the car to your garage, so it drops off the list. The wallet line and
## BUY affordability update live (also when the debug top-up adds money). BACK returns to the hub.

var _view: CarView
var _bars: StatBars
var _name: Label
var _sub: Label
var _price: Label
var _wallet: Label
var _buy: Button
var _list: VBoxContainer
var _shown: CarDef

func _build(col: VBoxContainer) -> void:
	col.add_child(heading("CAR SHOP"))
	_wallet = heading(_wallet_line(), "OsdDim")
	col.add_child(_wallet)
	col.add_child(spacer(12))
	Save.wallet_changed.connect(_on_wallet)   # auto-disconnects when this screen frees

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 40)
	col.add_child(body)

	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(270, 300)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.follow_focus = true
	body.add_child(sc)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_list.size_flags_horizontal = SIZE_EXPAND_FILL
	sc.add_child(_list)

	var detail := VBoxContainer.new()
	detail.add_theme_constant_override("separation", 6)
	body.add_child(detail)
	_name = heading("")
	detail.add_child(_name)
	_sub = heading("", "OsdDim")
	detail.add_child(_sub)
	_price = heading("")
	detail.add_child(_price)
	detail.add_child(spacer(4))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	detail.add_child(row)
	_view = CarView.new()
	_view.custom_minimum_size = Vector2(320, 230)
	row.add_child(_view)
	_bars = StatBars.new()
	_bars.size_flags_vertical = SIZE_SHRINK_CENTER
	row.add_child(_bars)

	col.add_child(spacer(12))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	col.add_child(actions)
	_buy = menu_button("BUY")
	_buy.pressed.connect(_on_buy)
	actions.add_child(_buy)
	var back := menu_button("BACK", "ui_click")
	back.pressed.connect(func() -> void: Flow.goto(Routes.CAREER_HUB))
	actions.add_child(back)

	_rebuild_list()

func _on_cancel() -> void:
	Flow.goto(Routes.CAREER_HUB)

func _rebuild_list() -> void:
	for c in _list.get_children():
		c.queue_free()
	var stock := Cars.buyable()
	var first: Button = null
	for d in stock:
		var b := menu_button("%s  %s   %s" % [d.display_name.to_upper(), d.car_class, _money(Cars.price_of(d))])
		b.custom_minimum_size.x = 254
		b.focus_entered.connect(_show.bind(d))
		b.pressed.connect(_show.bind(d))
		_list.add_child(b)
		if first == null:
			first = b
	if first != null:
		first.grab_focus()   # previews the first car in stock
	else:
		_show(null)          # owns everything buyable

func _show(def: CarDef) -> void:
	_shown = def
	_view.set_car(def)
	_bars.set_car(def)
	_name.text = def.display_name.to_upper() if def != null else "— SOLD OUT —"
	_sub.text = "CLASS %s  ·  %s" % [def.car_class, def.brand.to_upper()] if def != null else ""
	_price.text = _money(Cars.price_of(def)) if def != null else ""
	_refresh_buy()

func _refresh_buy() -> void:
	var afford := _shown != null and Save.can_afford(Cars.price_of(_shown))
	_buy.disabled = not afford
	if _shown == null:
		_buy.text = "BUY"
	elif afford:
		_buy.text = "BUY  %s" % _money(Cars.price_of(_shown))
	else:
		_buy.text = "CAN'T AFFORD"

func _on_buy() -> void:
	if not Shop.buy(_shown):
		return
	# bought — it moves to the garage and drops off the list; wallet_changed refreshes the wallet.
	_rebuild_list()

func _on_wallet() -> void:
	_wallet.text = _wallet_line()
	_refresh_buy()

func _wallet_line() -> String:
	return "$%s  ·  CP %d" % [_commas(Save.active.money), Save.active.cp] if Save.active != null else ""

func _money(n: int) -> String:
	return "$" + _commas(n)

## 160000 -> "160,000"
func _commas(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if n < 0 else "") + out
