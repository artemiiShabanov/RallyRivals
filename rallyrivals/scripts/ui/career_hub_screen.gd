extends MenuScreen
## Career hub (code-ui-career-hub) — the shell you return to between races, and the only screen that
## reads the loaded profile. Shows the wallet line (money / CP / current car) and the destination
## tiles.
##
## Only RACE is live in the skeleton. The map, shop and garage are deliberately present but disabled
## so the shape of the career loop is legible before the content exists; each lights up when its own
## task lands (code-ui-career-map, code-ui-shop, code-ui-garage).

const TILE_W := 420

## The tile list already exceeds the frame and only grows as shop/garage/map come online.
func _scrolls() -> bool:
	return true

func _build(col: VBoxContainer) -> void:
	col.add_child(heading("CAREER"))
	col.add_child(heading(_profile_line(), "OsdDim"))
	col.add_child(spacer(18))

	var race := _tile("RACE  ▸")
	race.pressed.connect(func() -> void: Flow.goto(Routes.PRE_RACE))
	col.add_child(race)

	col.add_child(_stub("CAREER MAP"))
	col.add_child(_stub("CAR SHOP"))
	col.add_child(_stub("GARAGE"))

	col.add_child(spacer(18))

	var settings := _tile("SETTINGS")
	settings.pressed.connect(func() -> void:
		SettingsScreen.return_to = Routes.CAREER_HUB   # BACK returns here, not to the title
		Flow.goto(Routes.SETTINGS))
	col.add_child(settings)

	var leave := _tile("SAVE & EXIT", "ui_click")
	leave.pressed.connect(_leave)
	col.add_child(leave)

	race.grab_focus()

func _on_cancel() -> void:
	_leave()

func _leave() -> void:
	if Save.active != null:
		Save.write()
	Flow.goto(Routes.TITLE)

func _tile(text: String, cue := "ui_confirm") -> Button:
	var b := menu_button(text, cue)
	b.custom_minimum_size.x = TILE_W
	return b

## A destination that exists in the design but not yet in the build.
func _stub(text: String) -> Button:
	var b := _tile("%-16s SOON" % text)
	b.disabled = true
	return b

func _profile_line() -> String:
	if Save.active == null:
		return "no profile loaded"
	return "$%d   ·   CP %d   ·   %s" % [Save.active.money, Save.active.cp, _car_name()]

## Prefer the CarDef's display name over the raw id; fall back to the id if the resource is missing.
func _car_name() -> String:
	var id := Save.active.current_car
	if id == "":
		return "NO CAR"
	var def := load("res://assets/cars/%s.tres" % id) as CarDef
	return (def.display_name if def != null and def.display_name != "" else id).to_upper()
