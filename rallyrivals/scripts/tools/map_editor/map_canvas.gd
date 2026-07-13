class_name MapCanvas
extends Control
## Zoom/pan image canvas for the map editor. Draws the layer stack (entries set by MapEditor,
## bottom-up) with nearest-neighbour filtering so pixels stay crisp at any zoom. Input: mouse
## wheel zooms around the cursor, middle-drag (or hold space + left-drag) pans. Editing tools
## (paint/stamps, later tasks) will hook _gui_input through the same pixel_at() mapping.

signal pixel_hovered(px: Vector2i)

var entries: Array = []   # [{"texture": Texture2D, "opacity": float}] bottom-up
var image_size := 0       # authored image size in px (0 = no document open)
var zoom := 1.0
var pan := Vector2.ZERO   # canvas position of the image's (0,0)

var _dragging := false
var _space := false

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
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _dragging:
			pan += mm.relative
			queue_redraw()
		pixel_hovered.emit(pixel_at(mm.position))
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
