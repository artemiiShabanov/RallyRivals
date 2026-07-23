extends MenuScreen
## Post-race results (code-ui-results): finishing place, time and best lap from the RaceDirector's
## last_result, plus a reward line. Rewards are a STUB until code-meta-economy (banked-best payouts) —
## the race's pools are shown but nothing is banked yet, and the save is not touched. CONTINUE returns
## to the career hub.

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
	col.add_child(heading("BEST LAP   %s" % (_fmt(res.best_lap) if res.best_lap < INF else "—")))
	col.add_child(spacer(14))

	var money: int = rd.money_pool if rd != null else 0
	var cp: int = rd.cp_pool if rd != null else 0
	col.add_child(heading("REWARD     +$%d  ·  +%d CP" % [money, cp], "OsdDim"))
	col.add_child(heading("banked-best economy pending", "OsdDim"))
	col.add_child(spacer(18))

	_continue_button(col)

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
