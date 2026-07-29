class_name PreRaceScreen
extends MenuScreen
## Pre-race preview (code-ui-prerace): the race's name, format and conditions, plus the car you're
## bringing and its five stat bars. START launches the race; BACK returns where the caller came from.
##
## `race` is set by the caller (career map) before entering, defaulting to the skeleton's slice race so
## the screen stands alone. `return_to` is the route BACK goes to ("" = career hub) — the map sets it so
## BACK loops back to the map. START hands the RaceDef to the RaceDirector and enters the race scene.

static var race: RaceDef = null
static var return_to := ""       ## route BACK returns to; "" = career hub

const SLICE_RACE := "res://assets/races/test_timetrial.tres"

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
	var admitted := r.admits(car)
	var right := _column()
	var car_line := car.display_name.to_upper() if car != null else "NO CAR"
	if car != null and car.car_class != "":
		car_line += "  (CLASS %s)" % car.car_class
	right.add_child(heading("YOUR CAR  —  " + car_line, "OsdDim"))
	var view := CarView.new()          # the 3D preview, in place of the stat bars
	view.custom_minimum_size = Vector2(360, 240)
	view.set_car(car)
	right.add_child(view)
	# Class gate (code-meta-classes): only a grand prix gates entry. Show the requirement, and flag
	# in red when the current car under-classes it — START is disabled below to match.
	var gate := r.gate_class()
	if gate != "":
		var note := heading("GRAND PRIX · CLASS %s+ REQUIRED" % gate, "OsdDim")
		if not admitted:
			note.add_theme_color_override("font_color", Color(1.0, 0.42, 0.32))
		right.add_child(note)
	body.add_child(right)

	col.add_child(spacer(20))

	# START + BACK on one row so both stay on frame at 720p.
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	col.add_child(actions)

	# Under-classing a grand prix blocks START (the one gated event) — bring a bigger car. Every other
	# race type always admits, so START stays live even if you brought a weaker car (that's your call).
	var start := menu_button("CAR TOO LOW" if not admitted else "START  ▸")
	start.disabled = not admitted
	start.pressed.connect(func() -> void:
		# A grand prix runs through its own menu (qualify → grid → race); every other type races now.
		if r.race_type == "grand_prix":
			GrandPrix.begin(r, Chapters.current())
			Flow.goto(Routes.GP_HUB)
		else:
			GrandPrix.clear()         # drop any abandoned meeting so this race is clean
			RaceDirector.pending = r  # hand the previewed RaceDef to the race
			Flow.goto(Routes.RACE))
	actions.add_child(start)

	# Reuse the garage as the owned-car picker; BACK there returns here, showing the new car.
	var change := menu_button("CHANGE CAR")
	change.pressed.connect(func() -> void:
		GarageScreen.return_to = Routes.PRE_RACE
		Flow.goto(Routes.GARAGE))
	actions.add_child(change)

	var back := menu_button("BACK", "ui_click")
	back.pressed.connect(func() -> void: Flow.goto(_back_route()))
	actions.add_child(back)

	# Focus the go-button when it's live; otherwise steer the player to the fix.
	(start if admitted else change).grab_focus()

func _column() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.size_flags_vertical = SIZE_SHRINK_BEGIN
	return v

func _on_cancel() -> void:
	Flow.goto(_back_route())

## Where BACK / cancel returns — the caller's route, else the career hub.
func _back_route() -> String:
	return return_to if return_to != "" else Routes.CAREER_HUB

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
