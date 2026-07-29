extends MenuScreen
## Grand-Prix hub (code-race-grandprix): the intermediate menu you sit in BEFORE and AFTER qualifying,
## reading the active GrandPrix.session.
##   Before qual  the field you're up against + START QUALIFYING (the qual race hands you back here).
##   After qual   your grid slot, the full qualifying order + START RACE (or RE-QUALIFY to run it again).
## Both START buttons hand the meeting's RaceDef to the RaceDirector, which reads GrandPrix.session.phase
## to know whether it's running a qualifying session or the race. BACK/QUIT clears the meeting.

const HOT := Color(1.0, 0.85, 0.3)     # your row, picked out of the grid

# The entry list / grid can run past the frame (six rows + result + actions), so scroll like the hub.
func _scrolls() -> bool:
	return true

func _build(col: VBoxContainer) -> void:
	var gp := GrandPrix.session
	if gp == null:                     # opened without a live meeting (e.g. direct nav) — bail cleanly
		col.add_child(heading("NO GRAND PRIX"))
		var back := menu_button("BACK", "ui_click")
		back.pressed.connect(func() -> void: Flow.goto(Routes.CAREER_HUB))
		col.add_child(back)
		back.grab_focus()
		return

	col.add_child(heading(gp.race.display_name))
	col.add_child(heading("GRAND PRIX  ·  CLASS %s+" % gp.race.gate_class(), "OsdDim"))
	col.add_child(spacer(14))
	if gp.phase == GrandPrix.PHASE_QUAL:
		_build_qual(col, gp)
	else:
		_build_race(col, gp)

# --- before qualifying ---
func _build_qual(col: VBoxContainer, gp: GrandPrix) -> void:
	col.add_child(heading("QUALIFYING", "OsdDim"))
	col.add_child(heading("%d FLYING LAPS  ·  YOUR BEST SETS THE GRID" % GrandPrix.QUAL_LAPS, "OsdDim"))
	col.add_child(spacer(10))
	col.add_child(heading("ENTRY LIST", "OsdDim"))
	for e in gp.grid_rivals():         # the field, without times (nobody's run yet)
		var d: DriverDef = e["driver"]
		var car: CarDef = e["car"]
		col.add_child(heading("#%-3d %-8s  ·  CLASS %s  ·  %s" % [
			d.number, d.hud.to_upper(), e["car_class"], car.display_name.to_upper()], "OsdDim"))
	col.add_child(spacer(16))

	var go := menu_button("START QUALIFYING  ▸")
	go.pressed.connect(func() -> void:
		RaceDirector.pending = gp.race
		Flow.goto(Routes.RACE))
	col.add_child(go)
	var back := menu_button("BACK", "ui_click")
	back.pressed.connect(_abandon)
	col.add_child(back)
	go.grab_focus()

# --- after qualifying ---
func _build_race(col: VBoxContainer, gp: GrandPrix) -> void:
	col.add_child(heading("QUALIFYING RESULT", "OsdDim"))
	col.add_child(heading("YOU QUALIFIED  %s / %d  ·  %s" % [
		_ordinal(gp.player_grid), GrandPrix.GRID_SIZE, _fmt(gp.player_qual)]))
	col.add_child(spacer(10))
	col.add_child(heading("STARTING GRID", "OsdDim"))
	for row in gp.grid():
		var line := heading("P%-2d  %-9s  %s" % [int(row["place"]), String(row["name"]).to_upper(), row["time"]],
			"OsdTitle" if row.get("player", false) else "OsdDim")
		if row.get("player", false):
			line.add_theme_color_override("font_color", HOT)
		col.add_child(line)
	col.add_child(spacer(16))

	var race := menu_button("START RACE  ▸")
	race.pressed.connect(func() -> void:
		RaceDirector.pending = gp.race
		Flow.goto(Routes.RACE))
	col.add_child(race)
	var requal := menu_button("RE-QUALIFY", "ui_click")
	requal.pressed.connect(func() -> void:
		gp.phase = GrandPrix.PHASE_QUAL
		gp.player_qual = INF
		gp.player_grid = 0
		RaceDirector.pending = gp.race
		Flow.goto(Routes.RACE))
	col.add_child(requal)
	var quit := menu_button("QUIT TO HUB", "ui_click")
	quit.pressed.connect(_abandon)
	col.add_child(quit)
	race.grab_focus()

func _on_cancel() -> void:
	_abandon()

func _abandon() -> void:
	GrandPrix.clear()
	Flow.goto(Routes.CAREER_HUB)

func _ordinal(n: int) -> String:
	match n:
		1: return "P1"
		_: return "P%d" % n

func _fmt(t: float) -> String:
	if t >= INF or t <= 0.0:
		return "NO TIME"
	var m := int(t) / 60
	return "%d:%05.2f" % [m, t - m * 60]
