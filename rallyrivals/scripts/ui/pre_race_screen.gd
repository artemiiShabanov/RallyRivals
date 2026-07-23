extends MenuScreen
## Pre-race preview (code-ui-prerace): the race's name, format and conditions, plus the car you're
## bringing and its five stat bars. START launches the race; BACK returns to the hub.
##
## `race` is set by the caller (career hub / map) before entering, defaulting to the skeleton's slice
## race so the screen stands alone. START hands that RaceDef to the RaceDirector and enters the race
## scene (countdown → run → finish lifecycle).

static var race: RaceDef = null

const SLICE_RACE := "res://assets/races/test_circuit.tres"

# Two columns (race info | car + bars) keep the screen short enough to centre with START always on
# frame — a single column ran the stat bars past the bottom edge.
func _build(col: VBoxContainer) -> void:
	var r := race if race != null else load(SLICE_RACE) as RaceDef

	col.add_child(heading(r.display_name))
	col.add_child(spacer(16))

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 80)
	col.add_child(body)

	var left := _column()
	left.add_child(heading("FORMAT", "OsdDim"))
	left.add_child(heading("%s · %s" % [r.race_type.to_upper(), r.culture.to_upper()]))
	left.add_child(heading("%d LAPS" % r.laps))
	left.add_child(spacer(12))
	left.add_child(heading("CONDITIONS", "OsdDim"))
	left.add_child(heading(_conditions(r)))
	body.add_child(left)

	var car := _car()
	var right := _column()
	right.add_child(heading("YOUR CAR  —  " + (car.display_name.to_upper() if car != null else "NO CAR"), "OsdDim"))
	var bars := StatBars.new()
	bars.set_car(car)
	right.add_child(bars)
	body.add_child(right)

	col.add_child(spacer(20))

	# START + BACK on one row so both stay on frame at 720p.
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	col.add_child(actions)

	var start := menu_button("START  ▸")
	start.pressed.connect(func() -> void:
		RaceDirector.pending = r      # hand the previewed RaceDef to the race
		Flow.goto(Routes.RACE))
	actions.add_child(start)

	var back := menu_button("BACK", "ui_click")
	back.pressed.connect(func() -> void: Flow.goto(Routes.CAREER_HUB))
	actions.add_child(back)

	start.grab_focus()

func _column() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.size_flags_vertical = SIZE_SHRINK_BEGIN
	return v

func _on_cancel() -> void:
	Flow.goto(Routes.CAREER_HUB)

## The profile's current car, falling back to the starter so the screen never shows blank.
func _car() -> CarDef:
	var id := Save.active.current_car if Save.active != null else Save.STARTER_CAR
	if id == "":
		id = Save.STARTER_CAR
	return load("res://assets/cars/%s.tres" % id) as CarDef

## "GOLDEN · CLEAR · SUMMER" from the RaceDef's preset resources (their file names read fine as-is).
func _conditions(r: RaceDef) -> String:
	var parts: Array = []
	var light := _res_name(r.lighting)
	var weather := _res_name(r.weather)
	if light != "":
		parts.append(light)
	if weather != "":
		parts.append(weather)
	parts.append(r.season.to_upper())
	return "  ·  ".join(parts)

func _res_name(res: Resource) -> String:
	if res == null or res.resource_path == "":
		return ""
	return res.resource_path.get_file().get_basename().to_upper()
