extends MenuScreen
## Career map (code-ui-career-map): the current chapter's races + the boss gate (GDD §5, CAMPAIGN.md).
## Each race tile opens pre-race (and shows your banked best there); the boss tile is locked until the
## CP threshold is met (code-meta-chapters), then opens the 1v1 duel. You advance regions by winning the
## boss, so the map only ever shows the CURRENT chapter.
##
## Content is the placeholder campaign (Campaign — the same race ×10 per chapter) until
## content-tracks-campaign authors the real region sets; this screen is the shape of the loop, unchanged
## when that lands.

const TILE_W := 460

func _scrolls() -> bool:
	return true

func _build(col: VBoxContainer) -> void:
	if Save.active == null:                       # opened without a profile (defensive)
		col.add_child(heading("NO PROFILE"))
		_add_back(col)
		return
	if Chapters.is_complete():
		col.add_child(heading("CAMPAIGN COMPLETE"))
		col.add_child(heading("Every region cleared.", "OsdDim"))
		_add_back(col)
		return

	var ch := Chapters.current()
	col.add_child(heading("REGION %d" % (ch + 1)))
	col.add_child(heading("CHAPTER %d / %d" % [ch + 1, Chapters.COUNT], "OsdDim"))
	col.add_child(heading(_cp_line(), "OsdDim"))
	col.add_child(spacer(16))

	var first: Button = null
	var races := Campaign.chapter_races(ch)
	for i in races.size():
		var r: RaceDef = races[i]
		var best := int(Save.active.bests.get(r.id, 0))
		var tag := "   ·   best %s" % _ordinal(best) if best > 0 else ""
		var tile := _tile("RACE %d%s  ▸" % [i + 1, tag])
		tile.pressed.connect(_open.bind(r))
		col.add_child(tile)
		if first == null:
			first = tile
	col.add_child(spacer(12))

	# Boss gate: unlocked opens the duel; locked shows the CP still to bank.
	if Chapters.boss_unlocked():
		var boss := _tile("BOSS — %s  ▸" % Chapters.boss().hud)
		boss.pressed.connect(_open.bind(Campaign.boss_race(ch)))
		col.add_child(boss)
		if first == null:
			first = boss
	else:
		var locked := _tile("BOSS — LOCKED  (%d CP TO GO)" % (Chapters.boss_threshold() - Chapters.cp_progress()))
		locked.disabled = true
		col.add_child(locked)

	col.add_child(spacer(16))
	_add_back(col)
	if first != null:
		first.grab_focus()

# Open a race through pre-race, with BACK looping back here.
func _open(r: RaceDef) -> void:
	PreRaceScreen.race = r
	PreRaceScreen.return_to = Routes.CAREER_MAP
	Flow.goto(Routes.PRE_RACE)

func _cp_line() -> String:
	if Chapters.boss_unlocked():
		return "BOSS UNLOCKED — %s waits" % Chapters.boss().hud
	return "CP TO BOSS   %d / %d" % [Chapters.cp_progress(), Chapters.boss_threshold()]

func _tile(text: String) -> Button:
	var b := menu_button(text)
	b.custom_minimum_size.x = TILE_W
	return b

func _add_back(col: VBoxContainer) -> void:
	var back := menu_button("BACK", "ui_click")
	back.pressed.connect(func() -> void: Flow.goto(Routes.CAREER_HUB))
	col.add_child(back)
	if get_viewport().gui_get_focus_owner() == null:
		back.grab_focus()

func _on_cancel() -> void:
	Flow.goto(Routes.CAREER_HUB)

func _ordinal(n: int) -> String:
	match n:
		1: return "1ST"
		2: return "2ND"
		3: return "3RD"
		_: return "%dTH" % n
