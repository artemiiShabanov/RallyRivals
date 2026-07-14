extends Control
## RallyRivals map editor — shell (code-tools-map-editor-shell). F6 scenes/tools/map_editor.tscn.
## Scope here: open/create a track folder, zoom/pan canvas (wheel + middle-drag), blueprint
## underlay with opacity, per-layer visibility/opacity, save (button or Ctrl+S). The editing
## tools (surface brush, race dots, prop stamps, auto-heightmap, export+bake) are the follow-up
## map-editor tasks and plug into this shell. Dev tool — not part of release builds.

const TRACKS_ROOT := "res://assets/tracks"
const LAYER_ORDER := ["blueprint", "surface", "markers", "race"]
const LAYER_TITLES := {"blueprint": "Blueprint", "surface": "Surface", "markers": "Props", "race": "Race"}

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

func _ready() -> void:
	var split := HBoxContainer.new()
	split.set_anchors_preset(Control.PRESET_FULL_RECT)
	split.add_theme_constant_override("separation", 0)
	add_child(split)
	_load_palette()
	split.add_child(_build_panel())
	canvas = MapCanvas.new()
	canvas.pixel_hovered.connect(_on_pixel_hovered)
	canvas.stroke.connect(_on_stroke)
	canvas.clicked.connect(_on_clicked)
	split.add_child(canvas)

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
	panel.custom_minimum_size = Vector2(280, 0)
	var vb := VBoxContainer.new()
	panel.add_child(vb)

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
	if doc == null or _race_mode == "":
		return
	if px.x < 0 or px.y < 0 or px.x >= doc.size or px.y >= doc.size:
		return
	if button == MOUSE_BUTTON_RIGHT:
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
		_place_start(pts[0], pts[1], pts[2])
	elif _race_mode == "gate" and _race_pending.size() == 2:
		var pts := _race_pending.duplicate()
		_race_pending.clear()
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

func _after_race_edit() -> void:
	doc.refresh_texture("race")
	_push_canvas()
	_set_dirty(true)
	_validate_race()

## Rebuild race overlays + summary via TrackBaker's own reading of the layers.
func _validate_race() -> void:
	canvas.overlay_rings = []
	canvas.overlay_lines = []
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
			canvas.overlay_rings.append({"p": p, "col": Color(1.0, 0.4, 1.0)})
		for p in dirs:
			canvas.overlay_rings.append({"p": p, "col": Color(1.0, 1.0, 0.3)})
		var problems: Array[String] = []
		if starts.is_empty() and dirs.is_empty() and gates.is_empty():
			_race_summary = "race: empty — place a start line"
			_update_race_hint()
			canvas.queue_redraw()
			return
		if starts.size() != 2:
			problems.append("start dots %d (need 2)" % starts.size())
		else:
			canvas.overlay_lines.append({"a": starts[0], "b": starts[1], "col": Color(1.0, 0.4, 1.0)})
			if not b._is_road((starts[0] + starts[1]) * 0.5):
				problems.append("start midpoint off-road")
		if dirs.size() != 1:
			problems.append("direction dots %d (need 1)" % dirs.size())
		var pairs: Variant = b._pair_dots(gates)
		if pairs == null:
			problems.append("gates don't pair (odd dot or midpoint off-road)")
			for p in gates:
				canvas.overlay_rings.append({"p": p, "col": Color(1.0, 0.25, 0.2)})
		else:
			for pr in pairs:
				canvas.overlay_lines.append({"a": pr[0], "b": pr[1], "col": Color(0.3, 1.0, 0.4)})
			for p in gates:
				canvas.overlay_rings.append({"p": p, "col": Color(0.3, 1.0, 0.4)})
		if problems.is_empty():
			_race_summary = "race OK: start + %d gates" % (pairs as Array).size()
		else:
			_race_summary = "race INVALID: " + "; ".join(problems)
	_update_race_hint()
	canvas.queue_redraw()

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
	if event is InputEventKey and event.is_pressed() and (event as InputEventKey).keycode == KEY_S \
			and (event as InputEventKey).is_command_or_control_pressed():
		_on_save()
		get_viewport().set_input_as_handled()

# ---------- sync ----------
func _after_doc_change(status: String) -> void:
	_set_dirty(false)
	for layer in LAYER_ORDER:
		(_layer_rows[layer]["check"] as CheckBox).set_pressed_no_signal(doc.layer_visible[layer])
		(_layer_rows[layer]["slider"] as HSlider).set_value_no_signal(doc.layer_opacity[layer])
	_push_canvas()
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
			var tex: Texture2D = doc.blueprint_texture if layer == "blueprint" else doc.textures.get(layer)
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
