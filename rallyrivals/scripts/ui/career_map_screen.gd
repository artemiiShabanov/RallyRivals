extends MenuScreen
## Career map (code-ui-career-map): a scattered road of race dots (the map view, left) + a detail card
## for the focused race (right), under a header that pages between the regions you've reached. Dots read
## empty / half (completed) / full (won); the boss is the larger final dot. Content is the placeholder
## Campaign (same race ×10 per chapter) until content-tracks-campaign authors the real region sets.
##
## You can browse chapters 0..current (past regions are cleared; the current one still gates its boss).
## Winning the current boss advances the region.

# Preloaded BY PATH (not global class_names) so the map compiles the instant the files exist — no waiting
# on the editor's class registry / a restart. Usable as types and via .new()/static access.
const CareerMapView = preload("res://scripts/ui/career_map_view.gd")
const PreRace = preload("res://scripts/ui/pre_race_screen.gd")

const CARD_W := 460
const HOT := Color(1.0, 0.85, 0.3)

var _view
var _card: VBoxContainer
var _region_label: Label
var _status_label: Label
var _prev_btn: Button
var _next_btn: Button
var _vch := 0                    # the chapter currently being VIEWED (0..Chapters.current())
var _nodes: Array = []

func _scrolls() -> bool:
	return false

func _build(_col: VBoxContainer) -> void:
	if Save.active == null:
		_col.add_child(heading("NO PROFILE"))
		var b := menu_button("BACK", "ui_click")
		b.pressed.connect(func() -> void: Flow.goto(Routes.CAREER_HUB))
		_col.add_child(b)
		b.grab_focus()
		return

	# Full-bleed page: a header row over a two-panel body (map | card).
	var page := VBoxContainer.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.offset_left = 40
	page.offset_top = 26
	page.offset_right = -40
	page.offset_bottom = -26
	page.add_theme_constant_override("separation", 14)
	add_child(page)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	page.add_child(header)
	_prev_btn = _nav_btn("◀", func() -> void: _load_chapter(_vch - 1))
	header.add_child(_prev_btn)
	_region_label = heading("REGION")
	header.add_child(_region_label)
	_next_btn = _nav_btn("▶", func() -> void: _load_chapter(_vch + 1))
	header.add_child(_next_btn)
	var push := Control.new()
	push.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(push)
	_status_label = heading("", "OsdDim")
	header.add_child(_status_label)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 28)
	page.add_child(body)

	_view = CareerMapView.new()
	_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.focus_changed.connect(_show_card)
	_view.activated.connect(_launch)
	_view.paged.connect(func(d: int) -> void: _load_chapter(_vch + d))
	body.add_child(_view)

	var right := PanelContainer.new()
	right.theme_type_variation = "HudPanel"
	right.custom_minimum_size.x = CARD_W
	right.size_flags_horizontal = Control.SIZE_SHRINK_END
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	body.add_child(right)
	_card = VBoxContainer.new()
	_card.add_theme_constant_override("separation", 10)
	right.add_child(_card)

	_load_chapter(Chapters.current())

# Build + show a chapter's map (clamped to what you've reached). Reconfigures the view + header + card.
func _load_chapter(vch: int) -> void:
	_vch = clampi(vch, 0, Chapters.current())
	_nodes = _make_nodes(_vch)
	_view.selected = 0
	_view.configure(_nodes, Save.active.created_unix * 131 + _vch)
	_region_label.text = "REGION %d / %d" % [_vch + 1, Chapters.COUNT]
	_prev_btn.disabled = _vch <= 0
	_next_btn.disabled = _vch >= Chapters.current()
	_status_label.text = _status(_vch)
	_show_card(0)
	_view.grab_focus()

func _nav_btn(text: String, cb: Callable) -> Button:
	var b := menu_button(text, "ui_click", false)   # hover_focus=false: mouse-only, keeps focus on the map
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(56, 0)
	b.pressed.connect(cb)
	return b

func _status(vch: int) -> String:
	if Chapters.is_complete():
		return "CAMPAIGN COMPLETE"
	if _is_gating(vch):
		if Chapters.boss_unlocked():
			return "BOSS UNLOCKED"
		return "BOSS IN %d CP" % (Chapters.boss_threshold() - Chapters.cp_progress())
	return "CLEARED"

# The chapter whose boss still gates progress — the current one, unless the campaign is already done.
func _is_gating(vch: int) -> bool:
	return vch == Chapters.current() and not Chapters.is_complete()

# --- nodes ---
func _make_nodes(vch: int) -> Array:
	var out: Array = []
	var races := Campaign.chapter_races(vch)
	for r in races:
		out.append(_node_for(r, false, vch))
	out.append(_node_for(Campaign.boss_race(vch), true, vch))
	return out

func _node_for(r: RaceDef, boss: bool, vch: int) -> Dictionary:
	var best := int(Save.active.bests.get(r.id, 0))
	var state := 2 if best == 1 else (1 if best > 0 else 0)      # won / completed / not raced
	return {
		"state": state, "boss": boss, "race": r,
		"locked": boss and _is_gating(vch) and not Chapters.boss_unlocked(),
	}

# --- right card ---
func _show_card(i: int) -> void:
	for c in _card.get_children():
		c.queue_free()
	if i < 0 or i >= _nodes.size():
		return
	var nd: Dictionary = _nodes[i]
	var r: RaceDef = nd["race"]
	_card.add_child(heading(r.display_name))
	if bool(nd["boss"]):
		var b := BossDef.for_chapter(_vch)
		_card.add_child(heading("BOSS DUEL — %s" % b.name, "OsdDim"))
		_card.add_child(heading("1v1 SPRINT · %s · %s CLASS" % [r.culture.to_upper(), b.car_class], "OsdDim"))
	else:
		_card.add_child(heading("%s · %s · %d LAPS" % [r.race_type.to_upper(), r.culture.to_upper(), r.laps], "OsdDim"))
		_card.add_child(heading("FIELD  %s" % _band(r), "OsdDim"))
	_card.add_child(heading("CONDITIONS  %s" % _conditions(r), "OsdDim"))
	_card.add_child(spacer(6))
	_card.add_child(heading(_best_line(r), "OsdDim"))
	_card.add_child(heading("REWARD  +$%d · +%d CP" % [r.money_pool, r.cp_pool], "OsdDim"))
	_card.add_child(spacer(12))

	if bool(nd["locked"]):
		var need := Chapters.boss_threshold() - Chapters.cp_progress()
		var lk := heading("LOCKED — %d CP TO GO" % need, "OsdDim")
		lk.add_theme_color_override("font_color", HOT)
		_card.add_child(lk)
	else:
		var start := menu_button("START  ▸", "ui_confirm", false)   # mouse-only; keyboard nav lives on the map
		start.focus_mode = Control.FOCUS_NONE
		start.pressed.connect(_launch.bind(i))
		_card.add_child(start)
	var back := menu_button("BACK", "ui_click", false)
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(func() -> void: Flow.goto(Routes.CAREER_HUB))
	_card.add_child(back)

# --- launch ---
func _launch(i: int) -> void:
	if i < 0 or i >= _nodes.size():
		return
	var nd: Dictionary = _nodes[i]
	if bool(nd["locked"]):
		play_cue("ui_error")
		return
	PreRace.race = nd["race"]
	PreRace.return_to = Routes.CAREER_MAP
	Flow.goto(Routes.PRE_RACE)

func _on_cancel() -> void:
	Flow.goto(Routes.CAREER_HUB)

# --- card helpers ---
func _band(r: RaceDef) -> String:
	if r.class_low == "" and r.class_high == "":
		return "OPEN"
	return "%s–%s" % [r.class_high, r.class_low]

func _best_line(r: RaceDef) -> String:
	var b := int(Save.active.bests.get(r.id, 0))
	return "YOUR BEST  %s" % _ordinal(b) if b > 0 else "YOUR BEST  — not raced —"

func _conditions(r: RaceDef) -> String:
	var parts: Array = []
	if r.lighting != null and r.lighting.resource_path != "":
		parts.append(r.lighting.resource_path.get_file().get_basename().to_upper())
	if r.weather != null and r.weather.resource_path != "":
		parts.append(r.weather.resource_path.get_file().get_basename().to_upper())
	return "  ·  ".join(parts) if not parts.is_empty() else "—"

func _ordinal(n: int) -> String:
	match n:
		1: return "1ST"
		2: return "2ND"
		3: return "3RD"
		_: return "%dTH" % n
