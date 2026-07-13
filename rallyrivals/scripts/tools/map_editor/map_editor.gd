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
var _brush_group := ButtonGroup.new()
var _brush_slider: HSlider
var _dirty := false

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
	for b in [["New", _on_new], ["Open", func() -> void: _open_dialog.popup_centered_ratio(0.7)], ["Save", _on_save]]:
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
		_brush_surface = s if on else null
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
