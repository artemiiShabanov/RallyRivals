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
	col.add_child(heading(_chapter_line(), "OsdDim"))
	col.add_child(spacer(18))

	# The career map is the way to race — it lists the chapter's races + the boss gate (code-ui-career-map).
	var race := _tile("RACE  ▸")
	race.pressed.connect(func() -> void: Flow.goto(Routes.CAREER_MAP))
	col.add_child(race)

	var shop := _tile("CAR SHOP")
	shop.pressed.connect(func() -> void: Flow.goto(Routes.SHOP))
	col.add_child(shop)

	var garage := _tile("GARAGE")
	garage.pressed.connect(func() -> void: Flow.goto(Routes.GARAGE))
	col.add_child(garage)

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

func _profile_line() -> String:
	if Save.active == null:
		return "no profile loaded"
	return "$%d   ·   CP %d   ·   %s" % [Save.active.money, Save.active.cp, _car_name()]

## Chapter + the two-step gate (code-meta-chapters): CP left to unlock the boss, or that it's open.
func _chapter_line() -> String:
	if Save.active == null:
		return ""
	if Chapters.is_complete():
		return "CAMPAIGN COMPLETE"
	var ch := "CHAPTER %d / %d" % [Chapters.current() + 1, Chapters.COUNT]
	if Chapters.boss_unlocked():
		return "%s   ·   BOSS UNLOCKED — %s" % [ch, Chapters.boss().hud]
	return "%s   ·   BOSS IN %d CP" % [ch, Chapters.boss_threshold() - Chapters.cp_progress()]

## Prefer the CarDef's display name over the raw id; fall back to the id if the resource is missing.
func _car_name() -> String:
	var id := Save.active.current_car
	if id == "":
		return "NO CAR"
	var def := load("res://assets/cars/%s.tres" % id) as CarDef
	return (def.display_name if def != null and def.display_name != "" else id).to_upper()
