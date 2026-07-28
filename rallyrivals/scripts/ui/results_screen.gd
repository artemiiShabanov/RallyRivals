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

	var rd := load("res://assets/races/%s.tres" % res.race_id) as RaceDef
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
	Flow.goto(Routes.CAREER_HUB)

func _continue_button(col: VBoxContainer) -> void:
	var cont := menu_button("CONTINUE  ▸")
	cont.pressed.connect(func() -> void: Flow.goto(Routes.CAREER_HUB))
	col.add_child(cont)
	cont.grab_focus()

func _ordinal(n: int) -> String:
	match n:
		1: return "1ST"
		2: return "2ND"
		3: return "3RD"
		_: return "%dTH" % n

func _fmt(t: float) -> String:
	var m := int(t) / 60
	return "%d:%05.2f" % [m, t - m * 60]
