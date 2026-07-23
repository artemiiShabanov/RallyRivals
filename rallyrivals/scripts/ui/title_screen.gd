extends MenuScreen
## Title / main menu (code-ui-title) — the game's front door, routed entirely through Flow.
##   NEW GAME  -> slot select (start a fresh career)
##   CONTINUE  -> load the most-recently-played slot, straight into the career hub (disabled if none)
##   SETTINGS  -> settings + input remap
##   QUIT      -> exit

func _build(col: VBoxContainer) -> void:
	col.add_child(heading("RALLY RIVALS"))
	col.add_child(heading("arcade rally", "OsdDim"))
	col.add_child(spacer(22))

	var new_btn := menu_button("NEW GAME")
	new_btn.pressed.connect(func() -> void: Flow.goto(Routes.SAVE_SLOTS))
	col.add_child(new_btn)

	var cont := menu_button("CONTINUE")
	cont.disabled = not Save.has_any()
	cont.pressed.connect(_on_continue)
	col.add_child(cont)

	var settings := menu_button("SETTINGS")
	settings.pressed.connect(func() -> void: Flow.goto(Routes.SETTINGS))
	col.add_child(settings)

	var quit := menu_button("QUIT", "ui_click")
	quit.pressed.connect(func() -> void: Flow.quit())
	col.add_child(quit)

	# Land focus on the most useful action for keyboard/gamepad.
	(new_btn if cont.disabled else cont).grab_focus()

func _on_continue() -> void:
	var slot := _most_recent_slot()
	if slot >= 0 and Save.load_slot(slot):
		Flow.goto(Routes.CAREER_HUB)

func _most_recent_slot() -> int:
	var best := -1
	var best_t := -1
	for s in Save.summaries():
		if s.get("exists", false) and int(s.get("played_unix", 0)) > best_t:
			best_t = int(s.get("played_unix", 0))
			best = int(s["slot"])
	return best
