extends MenuScreen
## Title / main menu (code-ui-title) — the game's front door, routed entirely through Flow.
##   NEW GAME  -> slot select in NEW mode (start a fresh career; occupied slots ask to overwrite)
##   CONTINUE  -> with one save, loads it straight into the hub; with several, opens the picker
##               (CONTINUE mode). Disabled when no save exists.
##   SETTINGS  -> settings + input remap
##   QUIT      -> exit

func _build(col: VBoxContainer) -> void:
	col.add_child(heading("RALLY RIVALS"))
	col.add_child(heading("arcade rally", "OsdDim"))
	col.add_child(spacer(22))

	var new_btn := menu_button("NEW GAME")
	new_btn.pressed.connect(_go.bind(SaveSlotsScreen.Mode.NEW))
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

func _go(mode: SaveSlotsScreen.Mode) -> void:
	SaveSlotsScreen.mode = mode
	Flow.goto(Routes.SAVE_SLOTS)

## One save is no choice — load it and go. Several (or a load failure) fall through to the picker.
func _on_continue() -> void:
	var occ := Save.occupied_slots()
	if occ.size() == 1 and Save.load_slot(occ[0]):
		Flow.goto(Routes.CAREER_HUB)
	else:
		_go(SaveSlotsScreen.Mode.CONTINUE)
