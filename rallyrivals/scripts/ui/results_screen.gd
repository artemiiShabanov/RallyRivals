extends MenuScreen
## Post-race results (code-ui-results): finishing place, time and best lap from the RaceDirector's
## last_result, plus the payout. The banked-best economy (code-meta-economy) already ran at finish —
## RaceEconomy.apply() credited the wallet and re-banked the best place — so this screen just DISPLAYS
## the breakdown carried on the result. CONTINUE returns to the career hub.

func _build(col: VBoxContainer) -> void:
	var res := RaceDirector.last_result
	if res == null:                       # e.g. opened directly without racing
		col.add_child(heading("NO RESULT"))
		_continue_button(col)
		return

	# Campaign races are built in code (Campaign.by_id); fall back to an authored .tres for test races.
	var rd := Campaign.by_id(res.race_id)
	if rd == null and ResourceLoader.exists("res://assets/races/%s.tres" % res.race_id):
		rd = load("res://assets/races/%s.tres" % res.race_id) as RaceDef
	col.add_child(heading(rd.display_name if rd != null else "RESULTS"))
	col.add_child(spacer(8))

	var place := Label.new()              # the headline: big white place on blue
	place.theme_type_variation = "HudValue"
	place.text = _ordinal(res.place)
	col.add_child(place)
	col.add_child(heading("PLACE %d / %d" % [res.place, res.field_size], "OsdDim"))
	col.add_child(spacer(14))

	col.add_child(heading("TIME       %s" % _fmt(res.total_time)))
	if res.penalty > 0.0:               # Officials contact penalty already folded into TIME
		col.add_child(heading("  incl. contact penalty  +%.0fs" % res.penalty, "OsdDim"))
	col.add_child(heading("BEST LAP   %s" % (_fmt(res.best_lap) if res.best_lap < INF else "—")))
	col.add_child(spacer(14))

	col.add_child(heading("EARNED     +$%d  ·  +%d CP" % [res.money_earned, res.cp_earned]))
	col.add_child(heading(_bank_line(res), "OsdDim"))
	if res.pink_slip_car_id != "":       # you took the boss's car (code-meta-pinkslip) — it's in your garage
		col.add_child(spacer(8))
		var won := Cars.by_id(res.pink_slip_car_id)
		var slip := heading("PINK SLIP — WON %s" % (won.display_name if won != null else res.pink_slip_car_id))
		slip.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		col.add_child(slip)
	col.add_child(spacer(18))

	_continue_button(col)

## How the payout was banked: a fresh best (with the place it beat), or a replay trickle off the bank.
func _bank_line(res: RaceResult) -> String:
	if res.improved:
		if res.prev_best <= 0:
			return "NEW BEST  %s" % _ordinal(res.banked_place)
		return "NEW BEST  %s  (was %s)" % [_ordinal(res.banked_place), _ordinal(res.prev_best)]
	return "BEST %s  ·  replay top-up (10%%)" % _ordinal(res.banked_place)

func _on_cancel() -> void:
	Flow.goto(_continue_route())

func _continue_button(col: VBoxContainer) -> void:
	var cont := menu_button("CONTINUE  ▸")
	cont.pressed.connect(func() -> void: Flow.goto(_continue_route()))
	col.add_child(cont)
	cont.grab_focus()

## A campaign race returns to the map (loop back in); anything else (test races) to the hub.
func _continue_route() -> String:
	var res := RaceDirector.last_result
	if res != null and Campaign.by_id(res.race_id) != null:
		return Routes.CAREER_MAP
	return Routes.CAREER_HUB

func _ordinal(n: int) -> String:
	match n:
		1: return "1ST"
		2: return "2ND"
		3: return "3RD"
		_: return "%dTH" % n

func _fmt(t: float) -> String:
	var m := int(t) / 60
	return "%d:%05.2f" % [m, t - m * 60]
