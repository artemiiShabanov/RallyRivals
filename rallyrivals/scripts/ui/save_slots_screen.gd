extends MenuScreen
## Save-slot select (code-ui-save-slots). Three slots as rows: an empty slot reads "NEW CAREER" and
## starts a fresh save on select; an occupied slot shows a one-line summary and loads on select. Both
## paths then enter the career hub. Occupied slots carry a DEL button with a two-press confirm
## (DEL -> SURE?). Reached from the title's NEW GAME (and its Continue express-lane bypasses this).

var _slots_box: VBoxContainer
var _arm_delete := -1        # slot index armed for a confirming second DEL press

func _build(col: VBoxContainer) -> void:
	col.add_child(heading("SELECT SLOT"))
	col.add_child(spacer(10))
	_slots_box = VBoxContainer.new()
	_slots_box.add_theme_constant_override("separation", 10)
	col.add_child(_slots_box)
	col.add_child(spacer(10))
	var back := menu_button("BACK", "ui_click")
	back.pressed.connect(func() -> void: Flow.goto(Routes.TITLE))
	col.add_child(back)
	_rebuild()

func _on_cancel() -> void:
	Flow.goto(Routes.TITLE)

func _rebuild() -> void:
	for c in _slots_box.get_children():
		c.queue_free()
	var first: Button = null
	for s in Save.summaries():
		var slot := int(s["slot"])
		var exists: bool = s.get("exists", false)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.size_flags_horizontal = SIZE_SHRINK_BEGIN

		var pick := menu_button(_row_text(s))
		pick.custom_minimum_size.x = 440
		pick.pressed.connect(_on_pick.bind(slot, exists))
		row.add_child(pick)

		if exists:
			var del := Button.new()
			del.text = "SURE?" if _arm_delete == slot else "DEL"
			del.alignment = HORIZONTAL_ALIGNMENT_LEFT
			del.custom_minimum_size.x = 96
			wire_button(del, "ui_click")
			del.pressed.connect(_on_delete.bind(slot))
			row.add_child(del)

		_slots_box.add_child(row)
		if first == null:
			first = pick
	if first != null:
		first.grab_focus()

func _row_text(s: Dictionary) -> String:
	var n := int(s["slot"]) + 1
	if not s.get("exists", false):
		return "SLOT %d    ▸  NEW CAREER" % n
	if s.get("corrupt", false):
		return "SLOT %d    ▸  (corrupt save)" % n
	var cars := int(s.get("cars", 0))
	return "SLOT %d    ▸  $%d · CP %d · %d CAR%s" % [n, int(s.get("money", 0)), int(s.get("cp", 0)), cars, "" if cars == 1 else "S"]

func _on_pick(slot: int, exists: bool) -> void:
	if exists:
		if Save.load_slot(slot):
			Flow.goto(Routes.CAREER_HUB)
	else:
		Save.new_game(slot)
		Flow.goto(Routes.CAREER_HUB)

func _on_delete(slot: int) -> void:
	if _arm_delete != slot:      # first press arms the confirm
		_arm_delete = slot
		_rebuild()
		return
	_arm_delete = -1             # second press deletes
	Save.delete_slot(slot)
	_rebuild()
