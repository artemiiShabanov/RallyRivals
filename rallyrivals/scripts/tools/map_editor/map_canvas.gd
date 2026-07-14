class_name MapCanvas
extends Control
## Zoom/pan image canvas for the map editor. Draws the layer stack (entries set by MapEditor,
## bottom-up) with nearest-neighbour filtering so pixels stay crisp at any zoom. Input: mouse
## wheel zooms around the cursor, middle-drag (or hold space + left-drag) pans. Editing tools
## (paint/stamps, later tasks) will hook _gui_input through the same pixel_at() mapping.

signal pixel_hovered(px: Vector2i)
signal stroke_begun
signal stroke(from_px: Vector2i, to_px: Vector2i, erase: bool)
signal clicked(px: Vector2i, button: int)

var entries: Array = []   # [{"texture": Texture2D, "opacity": float}] bottom-up
var image_size := 0       # authored image size in px (0 = no document open)
var zoom := 1.0
var pan := Vector2.ZERO   # canvas position of the image's (0,0)
var brush_radius := 0.0   # image-space px; >0 = a paint tool is active (left paints, right erases)
var overlay_rings: Array = []   # [{"p": Vector2 image px, "col": Color}] gizmos over the layers
var overlay_lines: Array = []   # [{"a": Vector2, "b": Vector2, "col": Color}]
var overlay_labels: Array = []  # [{"p": Vector2 image px, "text": String, "col": Color}]
var overlay_polyline := PackedVector2Array()   # image px; e.g. the extracted centreline
var overlay_polyline_col := Color(0.5, 0.8, 1.0, 0.45)

var _dragging := false
var _space := false
var _paint_btn := 0       # mouse button currently stroking (0 = none)
var _last_px := Vector2i.ZERO
var _hover := Vector2.ZERO
var _has_hover := false

func _ready() -> void:
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	focus_mode = Control.FOCUS_ALL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.12, 0.12, 0.15))
	if image_size == 0:
		return
	var r := Rect2(pan, Vector2.ONE * image_size * zoom)
	draw_rect(r.grow(1.0), Color(0.45, 0.45, 0.55), false, 1.0)
	for e in entries:
		draw_texture_rect(e["texture"], r, false, Color(1, 1, 1, e["opacity"]))
	if overlay_polyline.size() >= 2:
		var spts := PackedVector2Array()
		spts.resize(overlay_polyline.size())
		for i in overlay_polyline.size():
			spts[i] = pan + (overlay_polyline[i] + Vector2(0.5, 0.5)) * zoom
		draw_polyline(spts, overlay_polyline_col, 1.0)
	for l in overlay_lines:
		draw_line(pan + ((l["a"] as Vector2) + Vector2(0.5, 0.5)) * zoom, pan + ((l["b"] as Vector2) + Vector2(0.5, 0.5)) * zoom, l["col"], 1.5)
	for m in overlay_rings:
		draw_arc(pan + ((m["p"] as Vector2) + Vector2(0.5, 0.5)) * zoom, 7.0, 0.0, TAU, 24, m["col"], 1.5)
	var font := get_theme_default_font()
	for lb in overlay_labels:
		var sp: Vector2 = pan + ((lb["p"] as Vector2) + Vector2(0.5, 0.5)) * zoom + Vector2(9, -9)
		draw_string(font, sp, lb["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, lb["col"])
	if brush_radius > 0.0 and _has_hover:
		draw_arc(_hover, brush_radius * zoom, 0.0, TAU, 48, Color(0, 0, 0, 0.7), 3.0)
		draw_arc(_hover, brush_radius * zoom, 0.0, TAU, 48, Color(1, 1, 1, 0.9), 1.0)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			zoom_at(1.25, mb.position)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			zoom_at(1.0 / 1.25, mb.position)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE or (mb.button_index == MOUSE_BUTTON_LEFT and _space):
			_dragging = mb.pressed
			grab_focus()
		elif mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			if mb.pressed:
				clicked.emit(pixel_at(mb.position), mb.button_index)
				grab_focus()
			if brush_radius > 0.0:
				# left = paint, right = off-road erase; both stamp immediately on press
				_paint_btn = mb.button_index if mb.pressed else 0
				if mb.pressed:
					stroke_begun.emit()   # one undo step per drag
					_last_px = pixel_at(mb.position)
					stroke.emit(_last_px, _last_px, mb.button_index == MOUSE_BUTTON_RIGHT)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _dragging:
			pan += mm.relative
			queue_redraw()
		var px := pixel_at(mm.position)
		if _paint_btn != 0 and px != _last_px:
			stroke.emit(_last_px, px, _paint_btn == MOUSE_BUTTON_RIGHT)
			_last_px = px
		_hover = mm.position
		_has_hover = true
		if brush_radius > 0.0:
			queue_redraw()
		pixel_hovered.emit(px)
	elif event is InputEventMagnifyGesture:
		# macOS trackpad pinch (trackpads don't send wheel events)
		var mg := event as InputEventMagnifyGesture
		zoom_at(mg.factor, mg.position)
	elif event is InputEventPanGesture:
		# two-finger scroll: pan; with Cmd/Ctrl held: zoom
		var pg := event as InputEventPanGesture
		if pg.ctrl_pressed or pg.meta_pressed:
			zoom_at(1.0 - pg.delta.y * 0.05, pg.position)
		else:
			pan -= pg.delta * 8.0
			queue_redraw()
	elif event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_SPACE:
		_space = (event as InputEventKey).pressed

## Zoom by factor keeping the image point under screen_pos fixed.
func zoom_at(factor: float, screen_pos: Vector2) -> void:
	var nz := clampf(zoom * factor, 0.05, 64.0)
	factor = nz / zoom
	pan = screen_pos - (screen_pos - pan) * factor
	zoom = nz
	queue_redraw()

## Image pixel under a canvas-local position (may be out of the image's bounds).
func pixel_at(screen_pos: Vector2) -> Vector2i:
	var p := (screen_pos - pan) / zoom
	return Vector2i(int(floor(p.x)), int(floor(p.y)))

## Fit and centre the image in the canvas.
func fit() -> void:
	if image_size == 0 or size.x < 2.0 or size.y < 2.0:
		return
	zoom = minf(size.x, size.y) * 0.9 / image_size
	pan = (size - Vector2.ONE * image_size * zoom) * 0.5
	queue_redraw()
