extends MenuScreen
## Career map (code-ui-career-map): a winding road of race dots (CareerMapView) on the left, a detail
## card for the focused race on the right. Dots read empty / half (completed) / full (won); the boss is
## the final node; caps mark the region above + the next region below. Content is the placeholder
## Campaign (same race ×10 per chapter) until content-tracks-campaign authors the real region sets.
## Advance regions by winning the boss; the map only ever shows the CURRENT chapter.

# Preloaded by PATH (not a global class_name) so the map compiles the instant the file exists — no
# waiting on the editor's class registry / a restart. Usable as a type and via .new().
const CareerMapView = preload("res://scripts/ui/career_map_view.gd")
# Also preloaded by path (its class_name was added this session and only this screen references it, so
# a stale editor registry would parse-error until a restart). Static vars are set through it below.
const PreRace = preload("res://scripts/ui/pre_race_screen.gd")

const CARD_W := 460
const HOT := Color(1.0, 0.85, 0.3)

var _view: CareerMapView
var _card: VBoxContainer
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
	if Chapters.is_complete():
		_col.add_child(heading("CAMPAIGN COMPLETE"))
		_col.add_child(heading("Every region cleared.", "OsdDim"))
		var back := menu_button("BACK", "ui_click")
		back.pressed.connect(func() -> void: Flow.goto(Routes.CAREER_HUB))
		_col.add_child(back)
		back.grab_focus()
		return

	var ch := Chapters.current()
	_nodes = _make_nodes(ch)

	# Full-bleed two-panel layout on the screen root (the centred menu column stays unused here).
	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 40
	root.offset_top = 30
	root.offset_right = -40
	root.offset_bottom = -30
	root.add_theme_constant_override("separation", 28)
	add_child(root)

	_view = CareerMapView.new()
	_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.focus_changed.connect(_show_card)
	_view.activated.connect(_launch)
	root.add_child(_view)

	var right := PanelContainer.new()
	right.theme_type_variation = "HudPanel"
	right.custom_minimum_size.x = CARD_W
	right.size_flags_horizontal = Control.SIZE_SHRINK_END
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	root.add_child(right)
	_card = VBoxContainer.new()
	_card.add_theme_constant_override("separation", 10)
	right.add_child(_card)

	var gen_seed := Save.active.created_unix * 131 + ch
	_view.configure(_nodes, gen_seed, "REGION %d" % (ch + 1), _bottom_cap(ch))
	_show_card(_view.selected)
	_view.grab_focus()

func _bottom_cap(ch: int) -> String:
	return "REGION %d ▽" % (ch + 2) if ch + 1 < Chapters.COUNT else "CHAMPION"

# --- nodes ---
func _make_nodes(ch: int) -> Array:
	var out: Array = []
	var races := Campaign.chapter_races(ch)
	for i in races.size():
		out.append(_node_for(races[i], str(i + 1), false))
	out.append(_node_for(Campaign.boss_race(ch), "BOSS · %s" % Chapters.boss().hud, true))
	return out

func _node_for(r: RaceDef, label: String, boss: bool) -> Dictionary:
	var best := int(Save.active.bests.get(r.id, 0))
	var state := 2 if best == 1 else (1 if best > 0 else 0)   # won / completed / not raced
	return {
		"label": label, "state": state, "boss": boss, "race": r,
		"locked": boss and not Chapters.boss_unlocked(),
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
		var b := Chapters.boss()
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
		# hover_focus=false: these are mouse-only (no grab_focus on hover — that WARNs on FOCUS_NONE).
		var start := menu_button("START  ▸", "ui_confirm", false)
		start.focus_mode = Control.FOCUS_NONE     # keyboard nav lives on the map
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
	return "%s–%s" % [r.class_high, r.class_low]   # strongest-first reads e.g. C–D

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
