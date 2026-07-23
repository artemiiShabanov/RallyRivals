extends MenuScreen
## Car shop (code-ui-shop): every car you can buy (pink-slip trophies excluded), price-gated. The car
## strip runs along the bottom (cheapest class first); hover/focus a car and the detail panel above
## previews it (3D turntable + stat bars + price). CLICKING a car buys it — after a confirm — spending
## the price and moving it to your garage, so it drops off the strip. Wallet + affordability update
## live (also on the debug top-up). BACK returns to the hub.

var _view: CarView
var _bars: StatBars
var _name: Label
var _sub: Label
var _wallet: Label
var _list: HBoxContainer
var _shown: CarDef

func _build(col: VBoxContainer) -> void:
	# Header: title + wallet left, BACK right — keeping BACK up here leaves the car strip as the
	# bottom-most row so it always stays on frame.
	var hb := header_bar("CAR SHOP", _wallet_line(), func() -> void: Flow.goto(Routes.CAREER_HUB))
	col.add_child(hb[0])
	_wallet = hb[1]
	Save.wallet_changed.connect(_on_wallet)   # auto-disconnects when this screen frees

	col.add_child(spacer(14))
	_name = heading("")
	col.add_child(_name)
	_sub = heading("", "OsdDim")
	col.add_child(_sub)
	col.add_child(spacer(8))

	var detail := HBoxContainer.new()
	detail.add_theme_constant_override("separation", 30)
	col.add_child(detail)
	_view = CarView.new()
	_view.custom_minimum_size = Vector2(300, 210)
	detail.add_child(_view)
	_bars = StatBars.new()
	_bars.size_flags_vertical = SIZE_SHRINK_CENTER
	detail.add_child(_bars)

	col.add_child(spacer(12))

	# the car strip — horizontal, cheapest class first — stays the bottom-most row
	var strip := ScrollContainer.new()
	strip.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	strip.custom_minimum_size = Vector2(0, 48)
	strip.size_flags_vertical = SIZE_SHRINK_CENTER
	strip.follow_focus = true
	col.add_child(strip)
	_list = HBoxContainer.new()
	_list.add_theme_constant_override("separation", 10)
	strip.add_child(_list)

	_rebuild_list()

func _on_cancel() -> void:
	Flow.goto(Routes.CAREER_HUB)

func _rebuild_list() -> void:
	for c in _list.get_children():
		c.queue_free()
	var stock := Cars.buyable()
	stock.reverse()   # catalog is S->D; the shop shows cheapest (D) first
	var first: Button = null
	for d in stock:
		var b := row_button("%s  %s" % [d.display_name.to_upper(), d.car_class], _show.bind(d), _pick.bind(d))
		_list.add_child(b)
		if first == null:
			first = b
	if first != null:
		first.grab_focus()
	else:
		_show(null)   # owns everything buyable

func _show(def: CarDef) -> void:
	_shown = def
	_view.set_car(def)
	_bars.set_car(def)
	if def != null:
		var p := Cars.price_of(def)
		_name.text = def.display_name.to_upper()
		_sub.text = "CLASS %s  ·  %s  ·  %s%s" % [def.car_class, def.brand.to_upper(), _money(p),
			"" if Save.can_afford(p) else "   (CAN'T AFFORD)"]
	else:
		_name.text = "— SOLD OUT —"
		_sub.text = ""

## Click on a car = buy it, after a confirm. Unaffordable cars just buzz.
func _pick(def: CarDef) -> void:
	if def == null:
		return
	if not Shop.can_buy(def):
		play_cue("ui_error")
		return
	confirm("BUY %s\n%s ?" % [def.display_name.to_upper(), _money(Cars.price_of(def))], _do_buy.bind(def))

func _do_buy(def: CarDef) -> void:
	if Shop.buy(def):
		_rebuild_list()   # bought — moves to the garage, drops off the strip

func _on_wallet() -> void:
	_wallet.text = _wallet_line()
	_show(_shown)         # re-evaluate affordability

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
