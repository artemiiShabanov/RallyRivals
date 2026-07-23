class_name SaveSlotsScreen
extends MenuScreen
## Save-slot select (code-ui-save-slots). Three slots as rows; the title sets `mode` before entering:
##   NEW      — empty slot starts a fresh career; an occupied slot asks to OVERWRITE (two presses).
##   CONTINUE — occupied slot loads; empty slots are shown but disabled. Focus lands on the
##              most-recently-played save, so the common case is one keypress.
## Occupied slots always carry a DEL button (two-press confirm). Both paths end in the career hub.

enum Mode { NEW, CONTINUE }

static var mode := Mode.NEW      # set by the caller (title) before Flow.goto

var _slots_box: VBoxContainer
var _arm_slot := -1              # slot with a pending confirm…
var _arm_kind := ""             # …of kind "del" or "over"
var _picks: Dictionary = {}     # slot -> its pick Button (for focus)

func _build(col: VBoxContainer) -> void:
	col.add_child(heading("CONTINUE" if mode == Mode.CONTINUE else "NEW GAME"))
	col.add_child(heading("choose a save to load" if mode == Mode.CONTINUE else "select a slot", "OsdDim"))
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
	_picks = {}
	var summaries := Save.summaries()
	for s in summaries:
		var slot := int(s["slot"])
		var exists: bool = s.get("exists", false)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.size_flags_horizontal = SIZE_SHRINK_BEGIN

		var pick := menu_button(_row_text(slot, exists, s))
		pick.custom_minimum_size.x = 460
		if mode == Mode.CONTINUE and not exists:
			pick.disabled = true            # nothing to continue from an empty slot
		else:
			pick.pressed.connect(_on_pick.bind(slot, exists))
		row.add_child(pick)
		_picks[slot] = pick

		if exists:
			var del := Button.new()
			del.text = "SURE?" if (_arm_slot == slot and _arm_kind == "del") else "DEL"
			del.alignment = HORIZONTAL_ALIGNMENT_LEFT
			del.custom_minimum_size.x = 96
			wire_button(del, "ui_click")
			del.pressed.connect(_on_delete.bind(slot))
			row.add_child(del)

		_slots_box.add_child(row)

	_focus_best(summaries)

## Focus the row you're mid-confirm on; else the most-recent save (continue) or the first usable row.
func _focus_best(summaries: Array) -> void:
	if _arm_slot >= 0 and _picks.has(_arm_slot) and not _picks[_arm_slot].disabled:
		_picks[_arm_slot].grab_focus()
		return
	if mode == Mode.CONTINUE:
		var recent := _most_recent(summaries)
		if recent >= 0 and _picks.has(recent):
			_picks[recent].grab_focus()
			return
	for slot in _picks:
		if not _picks[slot].disabled:
			_picks[slot].grab_focus()
			return

func _most_recent(summaries: Array) -> int:
	var best := -1
	var best_t := -1
	for s in summaries:
		if s.get("exists", false) and int(s.get("played_unix", 0)) > best_t:
			best_t = int(s.get("played_unix", 0))
			best = int(s["slot"])
	return best

func _row_text(slot: int, exists: bool, s: Dictionary) -> String:
	var n := slot + 1
	if not exists:
		return "SLOT %d    ▸  %s" % [n, "NEW CAREER" if mode == Mode.NEW else "EMPTY"]
	if s.get("corrupt", false):
		return "SLOT %d    ▸  (corrupt save)" % n
	if _arm_slot == slot and _arm_kind == "over":
		return "SLOT %d    ▸  OVERWRITE?  (press again)" % n
	var cars := int(s.get("cars", 0))
	return "SLOT %d    ▸  $%d · CP %d · %d CAR%s" % [n, int(s.get("money", 0)), int(s.get("cp", 0)), cars, "" if cars == 1 else "S"]

func _on_pick(slot: int, exists: bool) -> void:
	if mode == Mode.CONTINUE:
		if Save.load_slot(slot):        # only occupied slots are pickable here
			Flow.goto(Routes.CAREER_HUB)
		return
	# NEW mode
	if not exists:
		Save.new_game(slot)
		Flow.goto(Routes.CAREER_HUB)
	elif _arm_slot == slot and _arm_kind == "over":
		_arm_slot = -1                  # confirmed — wipe and start fresh
		Save.new_game(slot)
		Flow.goto(Routes.CAREER_HUB)
	else:
		_arm(slot, "over")              # first press on an occupied slot arms the overwrite

func _on_delete(slot: int) -> void:
	if _arm_slot == slot and _arm_kind == "del":
		_arm_slot = -1
		Save.delete_slot(slot)
		_rebuild()
	else:
		_arm(slot, "del")

func _arm(slot: int, kind: String) -> void:
	_arm_slot = slot
	_arm_kind = kind
	_rebuild()
