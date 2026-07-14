extends Control
## RallyRivals map editor. F6 scenes/tools/map_editor.tscn. Dev tool — not in release builds.
## Open/create a track folder, then: surface brush (palette from the .tres set), race tools
## (start line, gates, live baker-backed validation), prop stamps, height control points
## (heightmap is DERIVED from the painted road — never painted), terrain preview, blueprint
## underlay, layer visibility/opacity, zoom/pan (wheel, gestures, middle-drag), save (Ctrl+S),
## snapshot undo/redo (Cmd/Ctrl+Z, Shift+Cmd+Z / Ctrl+Y). Export + bake is the remaining task.

const TRACKS_ROOT := "res://assets/tracks"
const LAYER_ORDER := ["blueprint", "terrain", "surface", "markers", "race"]
const LAYER_TITLES := {"blueprint": "Blueprint", "terrain": "Terrain", "surface": "Surface", "markers": "Props", "race": "Race"}
const UNDO_CAP := 30

const SURFACES_DIR := "res://assets/surfaces"

var doc: TrackDocument
var canvas: MapCanvas

var _name_edit: LineEdit
var _size_spin: SpinBox
var _folder_label: Label
var _status: Label
var _layer_rows := {}   # layer -> {"check": CheckBox, "slider": HSlider}
var _open_dialog: FileDialog
var _bp_dialog: FileDialog

var _surfaces: Array[SurfaceType] = []
var _off_road: SurfaceType          # the "eraser" surface (sand): right-drag paints this
var _brush_surface: SurfaceType     # null = no paint tool active
var _brush_group := ButtonGroup.new()   # shared by swatches AND race tools — one active tool total
var _brush_slider: HSlider
var _dirty := false

var _race_mode := ""                # "" | "start" | "gate"
var _race_pending: Array[Vector2i] = []
var _race_summary := ""             # last validation result, shown when not mid-placement
var _race_hint: Label
var _race_rings: Array = []         # overlay pieces, composed in _refresh_overlays
var _race_lines: Array = []
var _prop_mode := ""                # "" | "tree" | "rock"
var _prop_rings: Array = []
var _prop_count: Label

var _undo: Array = []               # snapshots: {"kind": layer name or "hpoints", "data": ...}
var _redo: Array = []

var _height_mode := false
var _hp_selected := -1
var _height_rings: Array = []
var _height_labels: Array = []
var _analysis: Variant = null       # cached HeightmapBuilder.analyze(); null = stale
var _builder: HeightmapBuilder
var _height_slider: HSlider
var _height_hint: Label
var _profile: ProfileStrip
var _terrain_tex: ImageTexture

func _ready() -> void:
	var split := HBoxContainer.new()
	split.set_anchors_preset(Control.PRESET_FULL_RECT)
	split.add_theme_constant_override("separation", 0)
	add_child(split)
	_load_palette()
	split.add_child(_build_panel())
	canvas = MapCanvas.new()
	canvas.pixel_hovered.connect(_on_pixel_hovered)
	canvas.stroke_begun.connect(func() -> void: _push_undo("surface"))
	canvas.stroke.connect(_on_stroke)
	canvas.clicked.connect(_on_clicked)
	split.add_child(canvas)

	_builder = HeightmapBuilder.new()
	for s in _surfaces:
		if s != _off_road:
			_builder.surfaces.append(s)
	_builder.off_road_surface = _off_road

	_open_dialog = FileDialog.new()
	_open_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	_open_dialog.access = FileDialog.ACCESS_RESOURCES
	_open_dialog.current_dir = TRACKS_ROOT
	_open_dialog.dir_selected.connect(_open_track)
	add_child(_open_dialog)

	_bp_dialog = FileDialog.new()
	_bp_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_bp_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_bp_dialog.filters = ["*.png,*.jpg,*.jpeg,*.webp ; Images"]
	_bp_dialog.file_selected.connect(_load_blueprint)
	add_child(_bp_dialog)

	_set_status("New or Open a track folder to begin.")

func _build_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(292, 0)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vb)

	var title := Label.new()
	title.text = "Map Editor"
	vb.add_child(title)

	var name_row := HBoxContainer.new()
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "track name"
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(_name_edit)
	_size_spin = SpinBox.new()
	_size_spin.min_value = 128; _size_spin.max_value = 2048; _size_spin.step = 64
	_size_spin.value = 512
	name_row.add_child(_size_spin)
	vb.add_child(name_row)

	var file_row := HBoxContainer.new()
	for b in [["New", _on_new], ["Open", func() -> void: _open_dialog.popup_centered_ratio(0.7)], ["Save", _on_save], ["Fit", func() -> void: canvas.fit()]]:
		var btn := Button.new()
		btn.text = b[0]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(b[1])
		file_row.add_child(btn)
	vb.add_child(file_row)

	_folder_label = Label.new()
	_folder_label.text = "(no track open)"
	_folder_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_folder_label.modulate = Color(1, 1, 1, 0.6)
	vb.add_child(_folder_label)

	vb.add_child(HSeparator.new())
	var bp_btn := Button.new()
	bp_btn.text = "Load blueprint underlay..."
	bp_btn.pressed.connect(func() -> void: _bp_dialog.popup_centered_ratio(0.7))
	vb.add_child(bp_btn)

	vb.add_child(HSeparator.new())
	var brush_title := Label.new()
	brush_title.text = "Surface brush  (right-drag = erase)"
	vb.add_child(brush_title)
	var grid := GridContainer.new()
	grid.columns = 3
	for s in _surfaces:
		grid.add_child(_swatch(s))
	vb.add_child(grid)
	var size_row := HBoxContainer.new()
	var size_label := Label.new()
	size_label.text = "size 8"
	size_label.custom_minimum_size = Vector2(58, 0)
	_brush_slider = HSlider.new()
	_brush_slider.min_value = 1; _brush_slider.max_value = 64; _brush_slider.value = 8
	_brush_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_brush_slider.value_changed.connect(func(v: float) -> void:
		size_label.text = "size %d" % int(v)
		_update_brush())
	size_row.add_child(size_label)
	size_row.add_child(_brush_slider)
	vb.add_child(size_row)

	vb.add_child(HSeparator.new())
	var race_title := Label.new()
	race_title.text = "Race tools  (right-click = delete dot)"
	vb.add_child(race_title)
	var race_row := HBoxContainer.new()
	for m in [["start", "Start line"], ["gate", "Add gate"]]:
		var btn := Button.new()
		btn.text = m[1]
		btn.toggle_mode = true
		btn.button_group = _brush_group
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.toggled.connect(func(on: bool) -> void:
			if on:
				_set_race_mode(m[0])
			elif _race_mode == m[0]:
				_set_race_mode(""))
		race_row.add_child(btn)
	vb.add_child(race_row)
	_race_hint = Label.new()
	_race_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_race_hint.modulate = Color(1, 1, 1, 0.7)
	vb.add_child(_race_hint)

	vb.add_child(HSeparator.new())
	var props_title := Label.new()
	props_title.text = "Props  (1 px = 1 prop; right-click = delete)"
	vb.add_child(props_title)
	var props_row := HBoxContainer.new()
	for m in [["tree", "Tree"], ["rock", "Rock"]]:
		var btn := Button.new()
		btn.text = m[1]
		btn.toggle_mode = true
		btn.button_group = _brush_group
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.toggled.connect(func(on: bool) -> void:
			if on:
				_prop_mode = m[0]
			elif _prop_mode == m[0]:
				_prop_mode = "")
		props_row.add_child(btn)
	vb.add_child(props_row)
	_prop_count = Label.new()
	_prop_count.modulate = Color(1, 1, 1, 0.7)
	vb.add_child(_prop_count)

	vb.add_child(HSeparator.new())
	var height_title := Label.new()
	height_title.text = "Height  (click road: add/select · right-click: delete)"
	vb.add_child(height_title)
	var height_row := HBoxContainer.new()
	var hbtn := Button.new()
	hbtn.text = "Height points"
	hbtn.toggle_mode = true
	hbtn.button_group = _brush_group
	hbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbtn.toggled.connect(func(on: bool) -> void:
		_height_mode = on
		_hp_selected = -1
		if on:
			_ensure_analysis()
		_height_refresh())
	height_row.add_child(hbtn)
	var pbtn := Button.new()
	pbtn.text = "Preview terrain"
	pbtn.pressed.connect(_preview_terrain)
	height_row.add_child(pbtn)
	vb.add_child(height_row)
	var hs_row := HBoxContainer.new()
	var hs_label := Label.new()
	hs_label.text = "8 m"
	hs_label.custom_minimum_size = Vector2(44, 0)
	_height_slider = HSlider.new()
	_height_slider.min_value = 0.0; _height_slider.max_value = 28.0; _height_slider.step = 0.5
	_height_slider.value = 8.0
	_height_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_height_slider.drag_started.connect(func() -> void:
		if _hp_selected >= 0:
			_push_undo("hpoints"))
	_height_slider.value_changed.connect(func(v: float) -> void:
		hs_label.text = "%.1f m" % v
		if _hp_selected >= 0 and doc != null and _hp_selected < doc.height_points.size():
			doc.height_points[_hp_selected]["h"] = v
			_set_dirty(true)
			_height_refresh())
	hs_row.add_child(hs_label)
	hs_row.add_child(_height_slider)
	vb.add_child(hs_row)
	_profile = ProfileStrip.new()
	vb.add_child(_profile)
	_height_hint = Label.new()
	_height_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_height_hint.modulate = Color(1, 1, 1, 0.7)
	vb.add_child(_height_hint)

	vb.add_child(HSeparator.new())
	var layers_title := Label.new()
	layers_title.text = "Layers (top-down)"
	vb.add_child(layers_title)
	var order := LAYER_ORDER.duplicate()
	order.reverse()   # UI lists top-most first, draw order stays bottom-up
	for layer in order:
		vb.add_child(_layer_row(layer))

	vb.add_child(HSeparator.new())
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_status)
	return panel

func _layer_row(layer: String) -> Control:
	var row := HBoxContainer.new()
	var check := CheckBox.new()
	check.text = LAYER_TITLES[layer]
	check.button_pressed = true
	check.custom_minimum_size = Vector2(110, 0)
	check.toggled.connect(func(v: bool) -> void:
		if doc != null:
			doc.layer_visible[layer] = v
		_push_canvas())
	row.add_child(check)
	var slider := HSlider.new()
	slider.min_value = 0.0; slider.max_value = 1.0; slider.step = 0.05
	slider.value = 0.5 if layer == "blueprint" else 1.0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(v: float) -> void:
		if doc != null:
			doc.layer_opacity[layer] = v
		_push_canvas())
	row.add_child(slider)
	_layer_rows[layer] = {"check": check, "slider": slider}
	return row

# ---------- surface brush ----------
# Palette straight from the .tres set — painted colours are exactly what the baker classifies.
func _load_palette() -> void:
	var da := DirAccess.open(SURFACES_DIR)
	if da == null:
		return
	for f in da.get_files():
		if f.get_extension() == "tres":
			var s := load(SURFACES_DIR.path_join(f)) as SurfaceType
			if s != null:
				_surfaces.append(s)
				if s.id == "sand":
					_off_road = s
	if _off_road == null and not _surfaces.is_empty():
		_off_road = _surfaces[0]

func _swatch(s: SurfaceType) -> Button:
	var b := Button.new()
	b.text = s.id + ("\n(eraser)" if s == _off_road else "")
	b.toggle_mode = true
	b.button_group = _brush_group
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.tooltip_text = "%s  grip %.1f" % [s.id, s.grip]
	for state in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = s.color.lightened(0.15) if state == "hover" else s.color
		sb.content_margin_top = 8.0; sb.content_margin_bottom = 8.0
		if state == "pressed":
			sb.border_color = Color.WHITE
			sb.set_border_width_all(2)
		b.add_theme_stylebox_override(state, sb)
	var lum := s.color.get_luminance()
	b.add_theme_color_override("font_color", Color.BLACK if lum > 0.5 else Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.BLACK if lum > 0.5 else Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.BLACK if lum > 0.5 else Color.WHITE)
	b.toggled.connect(func(on: bool) -> void:
		# guard against toggle-signal order when switching buttons within the group
		if on:
			_brush_surface = s
		elif _brush_surface == s:
			_brush_surface = null
		_update_brush())
	return b

func _update_brush() -> void:
	canvas.brush_radius = _brush_slider.value if _brush_surface != null else 0.0
	canvas.queue_redraw()

func _on_stroke(from_px: Vector2i, to_px: Vector2i, erase: bool) -> void:
	if doc == null or _brush_surface == null:
		return
	_analysis = null   # road may change shape under the brush
	var col := _off_road.color if erase else _brush_surface.color
	var img: Image = doc.images["surface"]
	var r := int(_brush_slider.value)
	var dist := Vector2(from_px).distance_to(Vector2(to_px))
	var steps := maxi(1, int(dist / maxf(1.0, r * 0.5)) + 1)
	for i in steps:
		var p := Vector2(from_px).lerp(Vector2(to_px), float(i) / maxf(1.0, steps - 1.0))
		_stamp(img, Vector2i(p.round()), r, col)
	doc.update_texture("surface")
	canvas.queue_redraw()
	_set_dirty(true)

func _stamp(img: Image, c: Vector2i, r: int, col: Color) -> void:
	var r2 := r * r
	for dy in range(-r, r + 1):
		var y := c.y + dy
		if y < 0 or y >= doc.size:
			continue
		for dx in range(-r, r + 1):
			var x := c.x + dx
			if x < 0 or x >= doc.size or dx * dx + dy * dy > r2:
				continue
			img.set_pixel(x, y, col)

func _set_dirty(v: bool) -> void:
	_dirty = v
	if doc != null:
		_folder_label.text = doc.dir + (" *" if _dirty else "")

# ---------- race tools ----------
# Semantic placement onto the race layer (pipeline dot conventions: 2x2 dots, black = empty).
# Start line = 3 clicks (shoulder, shoulder, direction), replacing any previous start/dir.
# Gate = 2 clicks. Right-click deletes dots near the cursor. Validation after every edit runs
# the BAKER'S own blob/pair/midpoint-on-road code, so the editor can't disagree with a bake.
func _set_race_mode(mode: String) -> void:
	_race_mode = mode
	_race_pending.clear()
	_update_race_hint()

func _update_race_hint() -> void:
	var prompts := {
		"start": ["start: click one shoulder of the line", "start: click the other shoulder", "start: click ahead — where the track goes"],
		"gate": ["gate: click one shoulder", "gate: click the other shoulder"],
	}
	_race_hint.text = prompts[_race_mode][_race_pending.size()] if _race_mode != "" else _race_summary

func _on_clicked(px: Vector2i, button: int) -> void:
	if doc == null:
		return
	if px.x < 0 or px.y < 0 or px.x >= doc.size or px.y >= doc.size:
		return
	if _height_mode:
		_height_click(px, button)
		return
	if _prop_mode != "" and _race_mode == "":
		_prop_click(px, button)
		return
	if _race_mode == "":
		return
	if button == MOUSE_BUTTON_RIGHT:
		_push_undo("race")
		_erase_race_near(px)
		_race_pending.clear()
		_after_race_edit()
		return
	if button != MOUSE_BUTTON_LEFT:
		return
	_race_pending.append(px)
	# clear pending BEFORE placing — placement re-renders the hint, which reads pending's size
	if _race_mode == "start" and _race_pending.size() == 3:
		var pts := _race_pending.duplicate()
		_race_pending.clear()
		_push_undo("race")
		_place_start(pts[0], pts[1], pts[2])
	elif _race_mode == "gate" and _race_pending.size() == 2:
		var pts := _race_pending.duplicate()
		_race_pending.clear()
		_push_undo("race")
		_place_gate(pts[0], pts[1])
	_update_race_hint()

func _place_start(a: Vector2i, b: Vector2i, toward: Vector2i) -> void:
	var img: Image = doc.images["race"]
	_clear_color(img, TrackBaker.R_START)
	_clear_color(img, TrackBaker.R_DIR)
	_race_dot(img, a, TrackBaker.R_START)
	_race_dot(img, b, TrackBaker.R_START)
	var mid := (Vector2(a) + Vector2(b)) * 0.5
	var dir := Vector2(toward) - mid
	dir = dir.normalized() if dir.length() > 0.5 else Vector2.RIGHT
	_race_dot(img, Vector2i((mid + dir * 6.0).round()), TrackBaker.R_DIR)
	_after_race_edit()

func _place_gate(a: Vector2i, b: Vector2i) -> void:
	var img: Image = doc.images["race"]
	_race_dot(img, a, TrackBaker.R_GATE)
	_race_dot(img, b, TrackBaker.R_GATE)
	_after_race_edit()

func _race_dot(img: Image, px: Vector2i, col: Color) -> void:
	for dy in 2:
		for dx in 2:
			img.set_pixel(clampi(px.x + dx, 0, doc.size - 1), clampi(px.y + dy, 0, doc.size - 1), col)

func _erase_race_near(px: Vector2i, r: int = 6) -> void:
	var img: Image = doc.images["race"]
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var x := px.x + dx; var y := px.y + dy
			if x < 0 or y < 0 or x >= doc.size or y >= doc.size or dx * dx + dy * dy > r * r:
				continue
			img.set_pixel(x, y, Color.BLACK)

func _clear_color(img: Image, col: Color) -> void:
	for y in doc.size:
		for x in doc.size:
			var c := img.get_pixel(x, y)
			if Vector3(c.r - col.r, c.g - col.g, c.b - col.b).length() < 0.2:
				img.set_pixel(x, y, Color.BLACK)

# ---------- undo / redo ----------
# Snapshot-based: each operation snapshots the ONE thing it touches before mutating (a whole
# brush drag = one step via stroke_begun). Restore swaps current state with the snapshot.
func _push_undo(kind: String) -> void:
	if doc == null:
		return
	_undo.append(_capture(kind))
	if _undo.size() > UNDO_CAP:
		_undo.pop_front()
	_redo.clear()

func _capture(kind: String) -> Dictionary:
	if kind == "hpoints":
		return {"kind": kind, "data": doc.height_points.duplicate(true)}
	return {"kind": kind, "data": (doc.images[kind] as Image).duplicate()}

func _restore(snap: Dictionary) -> Dictionary:
	var current := _capture(snap["kind"])
	if snap["kind"] == "hpoints":
		doc.height_points = snap["data"]
	else:
		doc.images[snap["kind"]] = snap["data"]
		doc.refresh_texture(snap["kind"])
	_after_restore(snap["kind"])
	return current

func _undo_op() -> void:
	if doc == null or _undo.is_empty():
		return
	_redo.append(_restore(_undo.pop_back()))
	_set_status("undo (%d left)" % _undo.size())

func _redo_op() -> void:
	if doc == null or _redo.is_empty():
		return
	_undo.append(_restore(_redo.pop_back()))
	_set_status("redo")

func _after_restore(kind: String) -> void:
	if kind == "surface" or kind == "race":
		_analysis = null   # centreline may have changed
	_hp_selected = -1
	_race_pending.clear()
	_push_canvas()
	_scan_props()
	_validate_race()   # also refreshes composed overlays
	_height_refresh()
	_set_dirty(true)

# ---------- prop stamps ----------
# Markers layer convention (TrackBaker._add_markers): ONE pixel = ONE prop, scanned per-pixel —
# no blob merging like race dots. So stamps write single pixels.
func _prop_click(px: Vector2i, button: int) -> void:
	var img: Image = doc.images["markers"]
	if button in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		_push_undo("markers")
	if button == MOUSE_BUTTON_LEFT:
		img.set_pixel(px.x, px.y, TrackBaker.M_TREE if _prop_mode == "tree" else TrackBaker.M_ROCK)
	elif button == MOUSE_BUTTON_RIGHT:
		var r := 3
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var x := px.x + dx; var y := px.y + dy
				if x >= 0 and y >= 0 and x < doc.size and y < doc.size and dx * dx + dy * dy <= r * r:
					img.set_pixel(x, y, Color.BLACK)
	else:
		return
	doc.refresh_texture("markers")
	_push_canvas()
	_set_dirty(true)
	_scan_props()
	_refresh_overlays()

func _scan_props() -> void:
	_prop_rings = []
	var trees := 0
	var rocks := 0
	if doc != null:
		var img: Image = doc.images["markers"]
		for y in doc.size:
			for x in doc.size:
				var c := img.get_pixel(x, y)
				if Vector3(c.r - 1.0, c.g, c.b).length() < 0.2:
					trees += 1
					_prop_rings.append({"p": Vector2(x, y), "col": Color(0.25, 0.8, 0.3)})
				elif Vector3(c.r, c.g, c.b - 1.0).length() < 0.2:
					rocks += 1
					_prop_rings.append({"p": Vector2(x, y), "col": Color(0.7, 0.7, 0.78)})
	_prop_count.text = "%d trees, %d rocks" % [trees, rocks]

func _refresh_overlays() -> void:
	canvas.overlay_rings = _race_rings + _prop_rings + _height_rings
	canvas.overlay_lines = _race_lines
	canvas.overlay_labels = _height_labels
	canvas.queue_redraw()

# ---------- height tool ----------
# Height is never painted: control points pin the road's elevation at lap positions and
# HeightmapBuilder derives everything else (flat corridor, shoulders, cut-and-fill terrain).
func _ensure_analysis() -> bool:
	if doc == null:
		return false
	if _analysis == null:
		var a := _builder.analyze(doc.images["surface"], doc.images["race"], doc.size)
		if not a["ok"]:
			_height_hint.text = a["msg"]
			return false
		_analysis = a
	_height_hint.text = "lap %.0f m, %d height points" % [_analysis["total"], doc.height_points.size()]
	return true

func _height_click(px: Vector2i, button: int) -> void:
	if not _ensure_analysis():
		return
	var idx := _hp_near(px)
	if button == MOUSE_BUTTON_RIGHT:
		if idx >= 0:
			_push_undo("hpoints")
			doc.height_points.remove_at(idx)
			_hp_selected = -1
			_set_dirty(true)
			_height_refresh()
		return
	if button != MOUSE_BUTTON_LEFT:
		return
	if idx >= 0:
		_hp_selected = idx
		_height_slider.set_value_no_signal(float(doc.height_points[idx]["h"]))
		_height_refresh()
		return
	# new point, snapped onto the centreline (must be near the road)
	var pts: PackedVector2Array = _analysis["pts"]
	var snapped: Vector2 = pts[_builder.nearest_index(_analysis, Vector2(px))]
	if snapped.distance_to(Vector2(px)) > 30.0:
		_height_hint.text = "click on (or near) the road to add a height point"
		return
	_push_undo("hpoints")
	doc.height_points.append({"x": snapped.x, "y": snapped.y, "h": _height_slider.value})
	_hp_selected = doc.height_points.size() - 1
	_set_dirty(true)
	_height_refresh()

func _hp_near(px: Vector2i) -> int:
	if doc == null:
		return -1
	for i in doc.height_points.size():
		var hp: Dictionary = doc.height_points[i]
		if Vector2(px).distance_to(Vector2(float(hp["x"]), float(hp["y"]))) < 9.0:
			return i
	return -1

## Rebuild the height overlays (centreline, points, labels) + the profile strip.
func _height_refresh() -> void:
	_height_rings = []
	_height_labels = []
	canvas.overlay_polyline = PackedVector2Array()
	_profile.anchors = []
	_profile.selected_frac = -1.0
	if doc != null and _analysis != null and _height_mode:
		canvas.overlay_polyline = _analysis["pts"]
		for i in doc.height_points.size():
			var hp: Dictionary = doc.height_points[i]
			var p := Vector2(float(hp["x"]), float(hp["y"]))
			var col := Color(0.25, 0.55, 1.0).lerp(Color(1.0, 0.45, 0.15), clampf(float(hp["h"]) / _builder.max_height, 0.0, 1.0))
			_height_rings.append({"p": p, "col": col if i != _hp_selected else Color.WHITE})
			_height_labels.append({"p": p, "text": "%.1f m" % float(hp["h"]), "col": col.lightened(0.3)})
		_profile.anchors = _builder.anchors_from(_analysis, doc.height_points)
		if _hp_selected >= 0 and _hp_selected < doc.height_points.size():
			var sel: Dictionary = doc.height_points[_hp_selected]
			_profile.selected_frac = _builder.frac_of(_analysis, Vector2(float(sel["x"]), float(sel["y"])))
		_ensure_analysis()   # refresh the hint line (lap length + point count)
	_profile.queue_redraw()
	_refresh_overlays()

func _preview_terrain() -> void:
	if not _ensure_analysis():
		_set_status("terrain preview needs a closed road + valid race layer")
		return
	var anchors := _builder.anchors_from(_analysis, doc.height_points)
	var img := _builder.build(doc.size, _analysis, anchors, maxi(64, doc.size / 4))
	# grayscale for display (FORMAT_RF would render red)
	var disp := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_L8)
	for y in img.get_height():
		for x in img.get_width():
			var v := img.get_pixel(x, y).r
			disp.set_pixel(x, y, Color(v, v, v))
	_terrain_tex = ImageTexture.create_from_image(disp)
	_push_canvas()
	_set_status("terrain preview built (quarter res) — full res happens at export")

func _after_race_edit() -> void:
	_analysis = null   # start line / direction may have moved
	doc.refresh_texture("race")
	_push_canvas()
	_set_dirty(true)
	_validate_race()

## Rebuild race overlays + summary via TrackBaker's own reading of the layers.
func _validate_race() -> void:
	_race_rings = []
	_race_lines = []
	_race_summary = ""
	if doc != null:
		var b := TrackBaker.new()
		b._rc = doc.images["race"]
		b._sf = doc.images["surface"]
		b._size = doc.size
		var road: Array = []
		for s in _surfaces:
			if s != _off_road:
				road.append(s)
		b.surfaces = road
		b.off_road_surface = _off_road
		var starts := b._blobs(b._rc, TrackBaker.R_START)
		var dirs := b._blobs(b._rc, TrackBaker.R_DIR)
		var gates := b._blobs(b._rc, TrackBaker.R_GATE)
		for p in starts:
			_race_rings.append({"p": p, "col": Color(1.0, 0.4, 1.0)})
		for p in dirs:
			_race_rings.append({"p": p, "col": Color(1.0, 1.0, 0.3)})
		var problems: Array[String] = []
		if starts.is_empty() and dirs.is_empty() and gates.is_empty():
			_race_summary = "race: empty — place a start line"
			_update_race_hint()
			_refresh_overlays()
			return
		if starts.size() != 2:
			problems.append("start dots %d (need 2)" % starts.size())
		else:
			_race_lines.append({"a": starts[0], "b": starts[1], "col": Color(1.0, 0.4, 1.0)})
			if not b._is_road((starts[0] + starts[1]) * 0.5):
				problems.append("start midpoint off-road")
		if dirs.size() != 1:
			problems.append("direction dots %d (need 1)" % dirs.size())
		var pairs: Variant = b._pair_dots(gates)
		if pairs == null:
			problems.append("gates don't pair (odd dot or midpoint off-road)")
			for p in gates:
				_race_rings.append({"p": p, "col": Color(1.0, 0.25, 0.2)})
		else:
			for pr in pairs:
				_race_lines.append({"a": pr[0], "b": pr[1], "col": Color(0.3, 1.0, 0.4)})
			for p in gates:
				_race_rings.append({"p": p, "col": Color(0.3, 1.0, 0.4)})
		if problems.is_empty():
			_race_summary = "race OK: start + %d gates" % (pairs as Array).size()
		else:
			_race_summary = "race INVALID: " + "; ".join(problems)
	_update_race_hint()
	_refresh_overlays()

# ---------- actions ----------
func _on_new() -> void:
	var track_name := _name_edit.text.strip_edges()
	if track_name.is_empty() or not track_name.is_valid_filename():
		_set_status("Give the track a valid folder name first.")
		return
	var target := TRACKS_ROOT.path_join(track_name)
	if TrackDocument.open(target) != null:
		_set_status("'%s' already exists — use Open." % track_name)
		return
	doc = TrackDocument.create(target, int(_size_spin.value))
	var err := doc.save()
	_after_doc_change("created %s (%d px)" % [target, doc.size] if err == OK else "save failed: %s" % error_string(err))
	canvas.fit()

func _open_track(dir: String) -> void:
	var opened := TrackDocument.open(dir)
	if opened == null:
		_set_status("No track layers found in %s." % dir)
		return
	doc = opened
	_after_doc_change("opened %s (%d px)" % [dir, doc.size])
	canvas.fit()

func _on_save() -> void:
	if doc == null:
		_set_status("Nothing to save — open a track first.")
		return
	var err := doc.save()
	if err == OK:
		_set_dirty(false)
	_set_status("saved %s" % doc.dir if err == OK else "save failed: %s" % error_string(err))

func _load_blueprint(path: String) -> void:
	if doc == null:
		_set_status("Open a track before loading a blueprint.")
		return
	if doc.load_blueprint(path):
		_set_status("blueprint: " + path.get_file())
	else:
		_set_status("Couldn't load image: " + path)
	_push_canvas()

func _shortcut_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.is_pressed():
		return
	var k := event as InputEventKey
	if k.is_command_or_control_pressed() and k.keycode == KEY_S:
		_on_save()
	elif k.is_command_or_control_pressed() and k.keycode == KEY_Z:
		# Cmd+Z / Shift+Cmd+Z on mac (Ctrl on the others)
		if k.shift_pressed:
			_redo_op()
		else:
			_undo_op()
	elif k.is_command_or_control_pressed() and k.keycode == KEY_Y:
		_redo_op()   # windows-style redo
	else:
		return
	get_viewport().set_input_as_handled()

# ---------- sync ----------
func _after_doc_change(status: String) -> void:
	_set_dirty(false)
	_undo.clear()
	_redo.clear()
	_analysis = null
	_terrain_tex = null
	_hp_selected = -1
	_height_refresh()
	for layer in LAYER_ORDER:
		(_layer_rows[layer]["check"] as CheckBox).set_pressed_no_signal(doc.layer_visible[layer])
		(_layer_rows[layer]["slider"] as HSlider).set_value_no_signal(doc.layer_opacity[layer])
	_push_canvas()
	_scan_props()
	_validate_race()
	_set_status(status)

## Rebuild the canvas draw list from the document. Call after any layer/visibility change.
func _push_canvas() -> void:
	canvas.image_size = doc.size if doc != null else 0
	var entries: Array = []
	if doc != null:
		for layer in LAYER_ORDER:
			if not doc.layer_visible[layer]:
				continue
			var tex: Texture2D
			match layer:
				"blueprint": tex = doc.blueprint_texture
				"terrain": tex = _terrain_tex
				_: tex = doc.textures.get(layer)
			if tex != null:
				entries.append({"texture": tex, "opacity": doc.layer_opacity[layer]})
	canvas.entries = entries
	canvas.queue_redraw()

func _on_pixel_hovered(px: Vector2i) -> void:
	if doc == null:
		return
	var inside := px.x >= 0 and px.y >= 0 and px.x < doc.size and px.y < doc.size
	_status.text = "px (%d, %d)  zoom %d%%" % [px.x, px.y, int(canvas.zoom * 100.0)] if inside else "zoom %d%%" % int(canvas.zoom * 100.0)

func _set_status(text: String) -> void:
	_status.text = text

## Small road-elevation graph (height vs lap distance) with the authored anchors marked.
class ProfileStrip:
	extends Control
	var anchors: Array = []        # [{frac, h 0..1}] sorted, from HeightmapBuilder.anchors_from
	var selected_frac := -1.0

	func _init() -> void:
		custom_minimum_size = Vector2(0, 56)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.1, 0.13))
		if anchors.is_empty():
			return
		var pts := PackedVector2Array()
		var steps := 96
		for i in steps + 1:
			var f := float(i) / steps
			var h := HeightmapBuilder.profile_h(anchors, f)
			pts.append(Vector2(f * size.x, size.y - 4.0 - h * (size.y - 8.0)))
		draw_polyline(pts, Color(0.55, 0.8, 1.0), 1.5)
		for a in anchors:
			var p := Vector2(float(a["frac"]) * size.x, size.y - 4.0 - float(a["h"]) * (size.y - 8.0))
			var sel: bool = selected_frac >= 0.0 and absf(float(a["frac"]) - selected_frac) < 0.005
			draw_circle(p, 4.0 if sel else 3.0, Color.WHITE if sel else Color(1.0, 0.6, 0.2))
